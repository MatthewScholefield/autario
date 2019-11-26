import collections/tables
import strutils
import sequtils
import strformat
import options

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

proc combined(self: var Program): Params =
  result.tokens = self.before.tokens & self.after.tokens
  result.tags = self.before.tags & self.after.tags
  for key, val in self.before.attributes.pairs:
    result.attributes[key] = val
  for key, val in self.after.attributes.pairs:
    result.attributes[key] = val
  result.context = if self.before.context.isSome: self.before.context else: self.after.context

iterator matchedTasks(self: Program, params: Params): Task =
  for i in self.auta.tasks:
    if params.toFilter.matches(i):
      yield i

proc handleCreate(self: var Program) = 
  let task = self.auta.create(Task(
    label : self.after.tokens.join(" "),
    tags : self.after.tags,
    context : if self.after.context.isSome: self.after.context.get else: "",
    attributes : self.after.attributes
  ))
  echo &"Created task {task.id}."

proc handleModify(self: var Program) =
  var numModified = 0
  for task in self.matchedTasks(self.before):
    self.auta.modify(task.uuid, self.after)
    echo &"Modified task '{task.label}'."
    numModified += 1
  if numModified == 0:
    echo "No tasks matched the search query."

proc handleDone(self: var Program) =
  var numModified = 0
  for task in self.matchedTasks(self.before).toSeq:
    self.auta.markDone(task.uuid)
    echo &"Marked task '{task.label}' as complete."
    numModified += 1
  if numModified == 0:
    echo "No tasks matched the search query."

proc handleList(self: var Program) = 
  let tasks = toSeq(self.matchedTasks(self.combined))
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
  "delete": handleDone
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
  commandToHandler[self.command](self)
  self.auta.save()
