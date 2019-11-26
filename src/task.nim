import collections/tables
import json
import options
import times
import sequtils
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


proc registerAttributes*(self: var Task, attributes: Table[string, string]) =
  for attr, value in attributes.pairs:
    if attr == "due":
      let ret = Parser(parse : timeparser.parseTime).parseTime(value)
      if ret.isNone:
        raise newException(AutaError, "Invalid due attribute")
      let currentTime = now();
      self.data["due"] = %*{
        "string": value,
        "data": ret.get,
        "base": currentTime.toTime.toUnix,
        "time": ret.get.quantifyTime(currentTime).toTime.toUnix
      }
    elif attr == "recur":
      let ret = Parser(parse : parseRecur).parseRecur(value)
      if ret.isNone:
        raise newException(AutaError, "Invalid recur attribute")
      let offset = ret.get.filter((x) => x.kind != tctRecurUnit)
      let recur = ret.get.filter((x) => x.kind == tctRecurUnit)
      if recur.len != 1:
        raise newException(AutaError, "Recur unit doesn't specify frequency properly")
      self.data["recur"] = %*{"offset": offset, "freq": recur}
    else:
      raise newException(AutaError, "Unknown attribute: " & attr)
    self.attributes[attr] = value
