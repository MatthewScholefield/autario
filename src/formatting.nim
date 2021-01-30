import sequtils
import strutils
import task
import collections/tables
import algorithm
import strformat
import times
import terminal
import colors
import json
import math

const units = [
  ("year", 365 * 24 * 60 * 60),
  ("month", 30 * 24 * 60 * 60),
  ("week", 7 * 24 * 60 * 60),
  ("day", 24 * 60 * 60),
  ("hour", 60 * 60),
  ("minute", 60),
  ("second", 1)
]

const unitValues = (var values: seq[int]; for unit, seconds in units.items: values.add(seconds); values)


proc formatPlural(amount: int, unit: string): string =
  var s = $amount & " " & unit
  if amount != 1:
    s.add("s")
  return s


proc formatAnd(items: seq[string]): string =
  if items.len < 3:
    return items.join(" and ")
  return items[0] & ", and " & items[1 .. ^ items.len].toSeq.join(", ")


proc matchPrecision(precision: int, unitValues: seq[int], middle = 0.5): int =
  var lastAmount = -Inf
  for i, amount in unitValues:
    let ratio = (precision - amount).float / (lastAmount - amount.float)
    if ratio >= middle:
      return i - 1
    lastAmount = amount.float
  return -1

proc formatDuration*(delta: int64, numItems: int, precision: int): string =
  var delta = delta
  let isNegative = delta < 0
  if isNegative:
      delta *= -1
  let cutoff = matchPrecision(precision, unitValues)
  var parts: seq[string]
  for i, (unit, unitSeconds) in units:
    let amount = delta.float / unitSeconds.float
    var amountRounded = (
      if i == cutoff:
        if isNegative:
          ceil(amount).int
        else:
          floor(amount).int
      else:
        amount.int
    )
    echo &"amount: {amountRounded}"
    if amountRounded != 0 or i == cutoff:
      delta -= unitSeconds * amountRounded
      let sign = if isNegative and amountRounded != 0: "-" else: ""
      parts.add(sign & formatPlural(amountRounded, unit))
    if i == cutoff:
      break
  return formatAnd(parts[0 .. min(parts.len - 1, numItems - 1)])


proc formatColumns*[T](printData: seq[array[T, string]], labels: array[T,
    string]): string =
  var maxLens: array[T, int]
  for row in printData:
    for i, data in row:
      maxLens[i] = max(maxLens[i], data.len)

  for i, label in labels:
    if maxLens[i] != 0:
      maxLens[i] = max(maxLens[i], label.len)

  var
    lines: seq[string]
  for rowNum, row in labels & printData:
    var parts: seq[string]
    for (word, maxLen) in zip(row, maxLens):
      if maxLen != 0:
        var padded = word.alignLeft(maxLen)
        if rowNum == 0:
          padded = ansiStyleCode(styleUnderscore) & padded & ansiResetCode
        parts.add(padded)
    var line = parts.join(" ")
    if rowNum mod 2 == 0 and rowNum != 0:
      line = ansiBackgroundColorCode(Color(0x22_22_22)) & line & ansiResetCode
    lines.add(line)
  return lines.join("\n")

proc formatTasks*(tasks: seq[Task]): string =
  type TaskOrder = tuple
    dueTime: int
    taskId: int
    tasksIndex: int
  var taskOrder: seq[TaskOrder]
  for i, task in tasks:
    taskOrder.add((
      dueTime: task.data{"due", "time"}.getInt(high(int)),
      taskId: task.id,
      tasksIndex: i
    ))
  taskOrder.sort()
  var formatParts: seq[array[5, string]]
  for order in taskOrder:
    let task = tasks[order.tasksIndex]
    var dueDelta: string
    if "due" in task.data:
      dueDelta = formatDuration(task.getSecondsTillDue, 1, task.getDuePrecision)
    formatParts.add([
      $task.id,
      $task.label,
      task.tags.join(", "),
      dueDelta,
      task.data{"recur", "frequency"}.getStr()
    ])
  return formatParts.formatColumns(["Id", "Label", "Tags", "Due", "Recur"])

proc formatTaskInfo*(task: Task): string =
  var formatParts: seq[array[2, string]] = @[
    ["Description", task.label]
  ]
  if "due" in task.data:
    formatParts.add(["Due", formatDuration(task.getSecondsTillDue, high(int), task.getDuePrecision)])
  if "recur" in task.data:
    formatParts.add(["Recur", task.attributes["recur"]])
  if task.tags.len != 0:
    formatParts.add(["Tags", task.tags.join(", ")])
  if task.context != "":
    formatParts.add(["Context", task.context])
  return formatParts.formatColumns(["", "Task " & $task.id])
