import collections/tables
import strutils
import sequtils
import options

import task

type Params* = object of RootObj
  tokens*: seq[string]
  tags*: seq[string]
  context*: Option[string]
  attributes*: Table[string, string]

type Filter* = object of Params
  ids*: seq[int]

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
  
  for i, token in self.tokens:
    if token.all(isDigit):
      result.ids.add(token.parseInt)
    else:
      result.tokens.add(token)


proc matches*(self: Filter, task: Task, withContext = true): bool =
  return (
    (self.ids.len == 0 or task.id in self.ids) and
    (self.tokens.len == 0 or self.tokens.join(" ") in task.label) and
    (if self.context.isNone: not withContext or task.context == "" else: self.context.get == task.context) and
    (self.attributes.len == 0 or self.attributes == task.attributes)
  )
