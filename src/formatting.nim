import sequtils
import strutils
import task
import collections/tables
import algorithm
import times
import terminal
import colors
import json


proc englishDuration*(delta: int64, numItems: int, preciion: int): string =
  $(delta.toBiggestFloat / 60.0 / 60.0) & " hours"


proc formatColumns*[T](printData: seq[array[T, string]], labels: array[T, string]): string =
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
    for i in zip(row, maxLens):
      let
        word = i.a
        maxLen = i.b
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

import json

proc formatTasks*(tasks: seq[Task]): string =
  # return $%tasks
  type TaskOrder = tuple
    dueTime: int
    taskId: int
    tasksIndex: int
  var taskOrder: seq[TaskOrder]
  for i, task in tasks:
    taskOrder.add((
      dueTime : task.data{"due", "time"}.getInt(high(int)),
      taskId : task.id,
      tasksIndex : i
    ))
  taskOrder.sort()
  var formatParts: seq[array[5, string]]
  for order in taskOrder:
    let task = tasks[order.tasksIndex]
    var dueDelta: string
    if "due" in task.data:
      dueDelta = englishDuration(task.data{"due", "time"}.getInt() - getTime().toUnix(), 1, task.data{"due", "precision"}.getInt())
    formatParts.add([
      $task.id,
      $task.label,
      task.tags.join(", "),
      dueDelta,
      task.data{"recur", "frequency"}.getStr()
    ])
  return formatParts.formatColumns(["Id", "Label", "Tags", "Due", "Recur"])
