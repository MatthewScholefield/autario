import collections/tables
import json
import options
import times
import sequtils
import strutils
import sugar

import parsing/timeparser
import parsing/recurparser
import parsing/parserutils
import exceptions
import timequantifier

type Task* = object
  uuid*: string
  id*: int
  label*: string
  tags*: seq[string]
  context*: string
  attributes*: Table[string, string]
  data*: JsonNode


proc deserializeTask*(node: JsonNode): Task =
    Task(
        uuid : to(node["uuid"], string),
        id: to(node["id"], int),
        label: to(node["label"], string),
        tags : to(node["tags"], seq[string]),
        context : to(node["context"], string),
        attributes : to(node["attributes"], Table[string, string]),
        data : node["data"]
    )

proc serialize*(self: Task): JsonNode =
  %* {
    "uuid": self.uuid,
    "id": self.id,
    "label": self.label,
    "tags": self.tags,
    "context": %self.context,
    "attributes": %self.attributes,
    "data": self.data
  }


proc extractImplicitRecurrence*(offsetParts: var seq[RTimeCommand]): RTimeCommand =
  var absolutes = offsetParts.filter((x) => x.kind == tctRemainderSet)
  if absolutes.len > 0:
    var recurUnit = low(RTimeUnit)
    assert recurUnit < tuDays
    for absolute in absolutes:
      case absolute.unit:
      of tuHour:
        if recurUnit == tuDays:
          recurUnit = tuDays
      of tuWeekday:
        if recurUnit < tuWeeks:
          recurUnit = tuWeeks
      of tuMonthday:
        if recurUnit < tuMonths:
          recurUnit = tuMonths
      of tuMonth:
        if recurUnit < tuYears:
          recurUnit = tuYears
      else:
        discard
    if recurUnit > low(RTimeUnit):
      return RTimeCommand(
        kind : tctRecurUnit,
        num : 1,
        unit : recurUnit
      )
  var offsets = offsetParts.filter((x) => x.kind == tctUnitAdd)
  if offsets.len > 1:
    raise newException(AutaError, "Recurrence interval must be simple (ie. '2weeks' or 'weekly')")
  if offsets.len == 0:
    raise newException(AutaError, "No recurrence interval specified. Must use an interval like 'weekly' or '2weeks'.")
  offsetParts = offsetParts.filter((x) => x.kind != tctUnitAdd)
  return RTimeCommand(
    kind : tctRecurUnit,
    num : offsets[0].num,
    unit : offsets[0].unit
  )

proc registerAttributes*(self: var Task, attributes: Table[string, string], currentTime: DateTime = now()) =
  var attributes = attributes
  if "due" in attributes:
    let ret = Parser(parse : timeparser.parseTime).parseTime(attributes["due"])
    if ret.isNone:
      raise newException(AutaError, "Invalid due attribute")
    let quant = ret.get.quantifyTime(currentTime)
    self.data["due"] = %*{
      "data": ret.get,
      "base": currentTime.toTime.toUnix,
      "time": quant.date.toTime.toUnix,
      "precision": quant.precision
    }
  if "begins" in attributes:
    let ret = Parser(parse : timeparser.parseTime).parseTime(attributes["begins"])
    if ret.isNone:
      raise newException(AutaError, "Invalid begins attribute")
    let quant = ret.get.quantifyTime(currentTime)
    self.data["begins"] = %*{
      "data": ret.get,
      "base": currentTime.toTime.toUnix,
      "time": quant.date.toTime.toUnix,
      "precision": quant.precision
    }
  if "recur" in attributes:
    let ret = Parser(parse : parseRecur).parseRecur(attributes["recur"])
    if ret.isNone:
      raise newException(AutaError, "Invalid recur attribute")
    var
      recurParts = ret.get.filter((x) => x.kind == tctRecurUnit)
      offsetParts = ret.get.filter((x) => x.kind != tctRecurUnit)
    if recurParts.len > 1:
      raise newException(AutaError, "Multiple recurring intervals specified")
    if recurParts.len == 0:
        recurParts.add(extractImplicitRecurrence(offsetParts))
    var recurPart = recurParts[0]
    var recur = RTimeCommand(kind: tctUnitAdd, num: recurPart.num, unit: recurPart.unit)
    var precision, lastEvent: int
    if offsetParts.len == 0:
      if "due" in self.data:
        lastEvent = self.data["due"]["time"].getInt()
        precision = self.data["due"]["precision"].getInt()
      else:
        lastEvent = currentTime.toTime.toUnix.int
        precision = 60
    else:
      let quant = offsetParts.quantifyTime(currentTime)
      lastEvent = quant.date.toTime.toUnix.int
      precision = quant.precision
    var reverseRecur = recur
    reverseRecur.num *= -1
    while lastEvent > currentTime.toTime.toUnix:
      lastEvent = @[reverseRecur].quantifyTime(lastEvent)
    self.data["recur"] = %*{"lastEvent": lastEvent, "freq": recur, "precision": precision}
    self.context = "__recur__" & (if self.context == "": "" else: ":" & self.context)
  
  attributes.del("due")
  attributes.del("begins")
  attributes.del("recur")
  if attributes.len != 0:
    for key in attributes.keys:
      if key.startsWith("-"):
        raise newException(AutaError, "Attributes don't start with a dash (ie. use due:tomorrow instead of -due:tomorrow)")
    raise newException(AutaError, "Unknown attribute: " & toSeq(keys(attributes)).join(", "))

proc spawnTasks*(self: var Task): seq[Task] =
  if "recur" notin self.data:
    return
  let recurData = self.data["recur"]
  var lastEvent = recurData["lastEvent"].getInt()
  let curTime = now()
  while curTime.toTime.toUnix >= lastEvent:
    let delta = @[recurData["freq"].to(RTimeCommand)]
    let nextEvent = delta.quantifyTime(lastEvent)
    var task: Task
    task.deepCopy(self)
    task.uuid = ""
    task.id = -1
    task.data.fields.clear()
    task.attributes.del("recur")
    task.context = task.context.split("__recur__", 1)[1].strip(trailing = false, chars = {':'})
    var attributes = task.attributes  # Needs to be `var` (possible bug in Nim)
    task.attributes.clear()
    task.registerAttributes(attributes, lastEvent.fromUnix.local)
    result.add(task)
    lastEvent = nextEvent
  self.data{"recur", "lastEvent"} = %lastEvent

proc getSecondsTillDue*(self: Task): int =
  self.data{"due", "time"}.getInt() - getTime().toUnix().int

proc getSecondsTillBegins*(self: Task): int =
  self.data{"begins", "time"}.getInt() - getTime().toUnix().int

proc getDuePrecision*(self: Task): int =
  self.data{"due", "precision"}.getInt()

proc getBeginsPrecision*(self: Task): int =
  self.data{"begins", "precision"}.getInt()
