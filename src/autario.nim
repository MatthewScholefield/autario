import os
import json
import oids
import sets
import options
import strutils
import times
import sugar
import system
import marshal
import sysrandom
import httpclient
import base64

import autils
import autaauth
import exceptions
import params
import task
import encryption

import appdirs

type Autario* = object
  tasks*: seq[Task]
  auth*: Option[AutaAuth]
  lastSync*: int
  dirty*: bool

let configFile = joinPath(user_config("autario"), "data.json")

proc findFreeId(self: var Autario): int =
  var usedIds = initHashSet[int]()
  for task in self.tasks:
    usedIds.incl(task.id)
  result = 1
  while true:
    if not usedIds.contains(result):
      return
    result += 1

proc deserializeAutario*(node: JsonNode): Autario =
    Autario(
        tasks : (
            var v: seq[Task] = @[]
            for elem in node["tasks"].elems:
                v.add(deserializeTask(elem))
            v
        ),
        auth : (
          if node["auth"].kind == JNull:
            none(AutaAuth)
          else:
            some(to(node["auth"], AutaAuth))
        ),
        lastSync : to(node["lastSync"], int),
        dirty : to(node["dirty"], bool)
    )
  
proc serialize*(self: Autario): JsonNode =
    %* {
      "tasks": %(
          var v: seq[JsonNode] = @[]
          for task in self.tasks:
              v.add(task.serialize())
          v
      ),
      "auth" : (
          if self.auth.isNone:
              newJNull()
          else:
              parseJson($$self.auth.get)
      ),
      "lastSync" : self.lastSync,
      "dirty" : self.dirty
    }

proc load*(self: var Autario) =
  if fileExists(configFile):
    var node = parseFile(configFile)
    self = deserializeAutario(node)

proc save*(self: Autario) =
  ensureParent(configFile)
  writeFile(configFile, $self.serialize())

proc syncRead*(self: var Autario, force: bool = false) =
  if self.auth.isSome:
    if not self.auth.get.checkIfUpToDate() or force:
      echo "Pulling changes..."
      let updatedData = self.auth.get.readData()
      if updatedData.isNone:
        echo "Error: Failed to read changes. If this persists, unlink with 'auta unlink'."
        return
      let node = parseJson(updatedData.get)
      self = deserializeAutario(node)
      self.auth.get.updateSyncTime()


proc syncWrite*(self: var Autario, force: bool = false) =
  if self.dirty or force:
    self.dirty = false
    if self.auth.isSome:
      echo "Uploading changes..."
      self.auth.get.updateSyncTime()
      self.auth.get.uploadData($self.serialize())

proc createBlobUrl(): string =
  var client = newHttpClient()
  let jsonStr = client.postContent("https://blobse.us.to/new", "")
  let resourceUrl = parseJson(jsonStr)["resource"].str
  return resourceUrl

proc enableSync*(self: var Autario) =
  self.auth = some(AutaAuth(
    key : base64.encode(getRandomBytes(keySize).toString),
    changeId : "",
    changeIdUrl : createBlobUrl(),
    dataUrl : createBlobUrl(),
    lastSync : 0
  ))
  self.dirty = true

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
  self.dirty = true

proc create*(self: var Autario, task: Task): Task {.discardable.} =
  var task = task
  task.uuid = $genOid()
  task.id = self.findFreeId()
  task.data = newJObject()
  task.data["createdAt"] = %* getTime().toUnix()
  task.registerAttributes(task.attributes)
  self.tasks.add(task)
  self.dirty = true
  return task


proc markDone*(self: var Autario, taskUuid: string) =
  var index = -1
  for i, task in self.tasks:
    if task.uuid == taskUuid:
      index = i
  if index == -1:
    raise newException(AutaError, "Invalid task uuid")
  self.tasks.delete(index)
  self.dirty = true

proc spawnRecurring*(self: var Autario): seq[tuple[newTask: Task,
    baseID: int]] =
  for i in 0 ..< self.tasks.len:
    var newTasks = self.tasks[i].spawnTasks()
    for j in 0 ..< newTasks.len:
      newTasks[j].uuid = $genOid()
      newTasks[j].id = self.findFreeId()
      self.tasks.add(newTasks[j])
      result.add((newTasks[j], self.tasks[i].id))
      self.dirty = true
