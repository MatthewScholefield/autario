import collections/tables
import strutils
import sequtils
import strformat
import options
import sugar

import params
import autario
import task
import formatting


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
  var numMatched = 0
  for task in self.auta.matchedTasks(self.before).toSeq:
    self.auta.markDone(task.uuid)
    echo &"Marked task '{task.label}' as complete."
    numMatched += 1
  if numMatched == 0:
    echo "No tasks matched the search query."

proc handleList(self: var Program) = 
  let tasks = toSeq(self.auta.matchedTasks(self.combined, true))
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

let commandToHandler = {
  "create": handleCreate,
  "add": handleCreate,
  "list": handleList,
  "mod": handleModify,
  "modify": handleModify,
  "done": handleDone,
  "del": handleDone,
  "delete": handleDone,
  "info": handleInfo,
  "recur": handleRecur
}.toTable;

proc parse*(self: var Program, args: seq[TaintedString]) =
  for arg in args:
    if self.seenCommand:
      self.after.ingest(arg)
    else:
      if arg.string in commandToHandler:
        self.command = arg.string
        self.seenCommand = true
      else:
        self.before.ingest(arg)
  if self.command == "":
    self.command = "list"
    self.after = self.before
    self.before = Params()

proc run*(self: var Program) =
  self.auta.configFile = "tasks.json"
  self.auta.load()
  self.checkRecurring()
  commandToHandler[self.command](self)
  self.auta.save()
