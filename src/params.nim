import collections/tables
import strutils
import sequtils
import options
import json
import sugar

import task

type Params* = object of RootObj
  tokens*: seq[string]
  tags*: seq[string]
  context*: Option[string]
  attributes*: Table[string, string]

type Filter* = object of Params
  ids*: seq[int]
  showNotBegun*: bool

proc ingest*(self: var Params, token: string) =
  let token = token
  if token.startsWith('+'):
    self.tags.add(token[1 .. ^1])
  elif token.startsWith('@'):
    self.context = some(token[1 .. ^1])
  elif ':' in token:
    let parts = token.split(':', 1);
    self.attributes[parts[0]] = parts[1]
  else:
    self.tokens.add(token)

proc toFilter*(self: Params): Filter =
  result = Filter(
    tokens : @[],
    tags : self.tags,
    context : self.context,
    attributes : self.attributes
  )
  let ind = result.tags.find("begins")
  if ind != -1:
    result.tags.del(ind)
    result.showNotBegun = true
  
  for i, token in self.tokens:
    if token.all(isDigit):
      result.ids.add(token.parseInt)
    else:
      result.tokens.add(token)

proc matches*(self: Filter, task: Task, ignoreContext: bool = false): bool =
  if self.ids.len != 0 and task.id in self.ids:
    return true
  let showAllContext = ignoreContext or self.context == some("")
  return (
    (not ("begins" in task.data) or self.showNotBegun or task.getSecondsTillBegins() <= 0) and
    (self.tags.all((x) => task.tags.contains(x))) and
    (self.tokens.len == 0 or self.tokens.join(" ") in task.label) and
    (showAllContext or (if self.context.isNone: task.context == "" else: self.context.get == task.context)) and
    (self.attributes.len == 0 or self.attributes == task.attributes) and
    (self.ids.len == 0 or self.tokens.len > 0 or self.context.isSome or self.attributes.len > 0 or self.tags.len > 0)
  )
