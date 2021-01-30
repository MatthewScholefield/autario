import collections/tables
import strutils
import sequtils
import strformat
import options
import sugar
import os
import json
import marshal

import params
import autario
import task
import formatting
import exceptions
import autaauth

type Program* = object
  before*: Params
  after*: Params
  auta*: Autario
  command: string
  seenCommand: bool


proc checkRecurring(self: var Program) =
  for task, baseID in self.auta.spawnRecurring().items:
    echo &"Created recurring task '{task.label}' from base task {baseID}."


proc combined(self: var Program): Params =
  result.tokens = self.before.tokens & self.after.tokens
  result.tags = self.before.tags & self.after.tags
  for key, val in self.before.attributes.pairs:
    result.attributes[key] = val
  for key, val in self.after.attributes.pairs:
    result.attributes[key] = val
  result.context = if self.before.context.isSome: self.before.context else: self.after.context



proc handleCreate(self: var Program) = 
  let task = self.auta.create(Task(
    label : self.after.tokens.join(" "),
    tags : self.after.tags,
    context : if self.after.context.isSome: self.after.context.get else: "",
    attributes : self.after.attributes
  ))
  self.checkRecurring()
  echo &"Created task {task.id}."

proc handleModify(self: var Program) =
  var numMatched = 0
  for task in self.auta.matchedTasks(self.before):
    self.auta.modify(task.uuid, self.after)
    let newTask = self.auta.getTask(task.uuid).get
    echo &"Modified task '{newTask.label}'."
    numMatched += 1
  if numMatched == 0:
    echo "No tasks matched the search query."

proc handleDone(self: var Program) =
  var tasks: seq[Task]
  for i in self.auta.matchedTasks(self.before).toSeq:
    tasks.add(i)
  if tasks.len > 1:
    stdout.write &"Are you sure you want to mark {tasks.len} tasks as done? (Y/n) "
    stdout.flushFile
    let c = stdin.readChar
    if c != '\n' and c != 'y' and c != 'Y':
      echo "\nCancelling..."
      return

  for task in tasks:
    self.auta.markDone(task.uuid)
    echo &"Marked task '{task.label}' as complete."
  if tasks.len == 0:
    echo "No tasks matched the search query."

proc handleDelete(self: var Program) =
  var tasks: seq[Task]
  for i in self.auta.matchedTasks(self.before).toSeq:
    tasks.add(i)
  if tasks.len > 1:
    stdout.write &"Are you sure you want to delete {tasks.len} tasks? (Y/n) "
    stdout.flushFile
    let c = stdin.readChar
    if c != '\n' and c != 'y' and c != 'Y':
      echo "Cancelling..."
      return
  for task in self.auta.matchedTasks(self.before).toSeq:
    self.auta.markDone(task.uuid)
    echo &"Deleted task '{task.label}'."
  if tasks.len == 0:
    echo "No tasks matched the search query."

proc handleList(self: var Program) = 
  let tasks = toSeq(self.auta.matchedTasks(self.combined, true))
  if tasks.len > 0:
    echo tasks.formatTasks()
    echo ""
  echo &"{tasks.len} tasks."


proc handleInfo(self: var Program) =
  var numMatched = 0
  for task in self.auta.matchedTasks(self.before):
    echo task.formatTaskInfo()
    numMatched += 1
  if numMatched == 0:
    echo "No tasks matched the search query."

proc handleRecur(self: var Program) =
  let tasks = self.auta.tasks.filter(task => "recur" in task.attributes)
  echo tasks.formatTasks()
  echo ""
  echo &"{tasks.len} tasks."

let commandDescriptions = {
  "add": "Create a new task",
  "list": "List tasks (default command)",
  "mod": "Modify a task",
  "done": "Mark a task as done",
  "del": "Delete a task",
  "info": "View details about a task",
  "recur": "Show recurring tasks",
  "link": "Link this device with other devices",
  "sync": "Force synchronization between devices",
  "help": "Show this information"
}

proc handleHelp(self: var Program) =
  var formatParts: seq[array[2, string]]
  for key, value in commandDescriptions.items:
    formatParts.add([key, value])
  echo formatColumns(formatParts, ["Command", "Description"])

proc handleSync(self: var Program) =
  if self.auta.auth.isNone:
    raise newException(AutaError, "You must link your device before syncing. Run 'auta link'.")
  self.auta.syncRead(force=true)
  self.auta.dirty = true

proc handleLink(self: var Program) =
  let args = self.after.tokens
  if (
    self.before.context.isSome or
    self.after.context.isSome or
    self.before.attributes.len != 0 or
    self.after.attributes.len != 0 or
    self.before.tags.len != 0 or
    self.after.tags.len != 0 or
    not (
      args.len == 0 or (
        args.len == 2 and (
          args[0] == "export" or (
            args[0] == "import" and fileExists(args[1])
          )
        )
      )
    )
  ):
    raise newException(AutaError, &"Usage: {lastPathPart(getAppFilename())} link [export|import] [FILE]")
  if args.len == 0:
    if self.auta.auth.isSome:
      echo "Synchronization already set up!"
    else:
      self.auta.enableSync()
      echo "Synchronization set up!"
  else:
    let command = args[0]
    let filename = args[1]
    if command == "export":
      if self.auta.auth.isNone:
        raise newException(AutaError, "Local system is not linked yet. Please run 'auta link'.")
      echo &"Exporting to {filename}..."
      writeFile(filename, $$self.auta.auth.get)
      echo &"Export complete! Import with 'auta link import \"{filename}\"'."
    elif command == "import":
      echo &"Loading from {filename}..."
      let auth: AutaAuth = to(parseFile(filename), AutaAuth)
      let data = auth.readData()
      if data.isNone:
        echo "Failed to read data from server. Please check if this is the correct file."
        return
      self.auta.auth = some(auth)
      self.auta.syncRead(true)
      echo "Linking successful."
    else:
      raise newException(ValueError, &"Invalid command: {command}")


let commandToHandler = {
  "create": handleCreate,
  "add": handleCreate,
  "list": handleList,
  "mod": handleModify,
  "modify": handleModify,
  "done": handleDone,
  "del": handleDelete,
  "delete": handleDelete,
  "info": handleInfo,
  "recur": handleRecur,
  "link": handleLink,
  "sync": handleSync,
  "help": handleHelp,
  "-h": handleHelp,
  "--help": handleHelp
}.toTable;

proc parse*(self: var Program, args: seq[string]) =
  for arg in args:
    if self.seenCommand:
      self.after.ingest(arg)
    else:
      if arg in commandToHandler:
        self.command = arg
        self.seenCommand = true
      else:
        self.before.ingest(arg)
  if self.command == "":
    self.command = "list"
    self.after = self.before
    self.before = Params()

proc run*(self: var Program) =
  self.auta.load()
  self.auta.syncRead()
  self.checkRecurring()
  commandToHandler[self.command](self)
  self.auta.syncWrite() 
