import os
import json
import collections/tables
import yaml/serialization, yaml/presenter, streams
import oids
import sets
import options
import strutils
import times
import sugar
import system

import customserialization
import exceptions
import params
import task

type Autario* = object
  configFile*: string
  tasks*: seq[Task]

proc findFreeId(self: var Autario): int =
  var usedIds = initHashSet[int]()
  for task in self.tasks:
    usedIds.incl(task.id)
  result = 1
  while true:
    if not usedIds.contains(result):
      return
    result += 1

proc load*(self: var Autario) =
  if fileExists(self.configFile):
    var f = newFileStream(self.configFile)
    serialization.load(f, self)
    close(f)

proc save*(self: var Autario) =
  var wf = newFileStream(self.configFile, fmWrite)
  dump(self, wf, options = defineOptions(style = psJson))
  wf.close()

proc findTaskIndex(self: Autario, taskUuid: string): Option[int] =
  for i, task in self.tasks:
    if task.uuid == taskUuid:
      return some(i)

iterator matchedTasks*(self: Autario, params: Params,
    withContext = false): Task =
  for i in self.tasks:
    if params.toFilter.matches(i, withContext):
      yield i

proc getTask*(self: Autario, taskUuid: string): Option[Task] =
  self.findTaskIndex(taskUuid).map(i => self.tasks[i])

proc modify*(self: var Autario, taskUuid: string, changes: Params) =
  var index = self.findTaskIndex(taskUuid)
  if index.isNone:
    raise newException(AutaError, "Nonexistent uuid")
  let i = index.get
  self.tasks[i].registerAttributes(changes.attributes)
  if changes.tokens.len != 0:
    self.tasks[i].label = changes.tokens.join(" ")
  if changes.context.isSome:
    self.tasks[i].context = changes.context.get
  for tag in changes.tags:
    if tag notin self.tasks[i].tags:
      self.tasks[i].tags.add(tag)

proc create*(self: var Autario, task: Task): Task {.discardable.} =
  var task = task
  task.uuid = $genOid()
  task.id = self.findFreeId()
  task.data = newJObject()
  task.data["createdAt"] = %* getTime().toUnix()
  task.registerAttributes(task.attributes)
  self.tasks.add(task)
  return task


proc markDone*(self: var Autario, taskUuid: string) =
  var index = -1
  for i, task in self.tasks:
    if task.uuid == taskUuid:
      index = i
  if index == -1:
    raise newException(AutaError, "Invalid task uuid")
  self.tasks.delete(index)

proc spawnRecurring*(self: var Autario): seq[tuple[newTask: Task,
    baseID: int]] =
  for i in 0 ..< self.tasks.len:
    var newTasks = self.tasks[i].spawnTasks()
    for j in 0 ..< newTasks.len:
      newTasks[j].uuid = $genOid()
      newTasks[j].id = self.findFreeId()
      self.tasks.add(newTasks[j])
      result.add((newTasks[j], self.tasks[i].id))
