import options
import nre
import strutils
import collections/tables
import times

const exprSep* = "."
const subexprSep* = "(?:" & [r"_", r"\-", r"\s+", r""].join("|") & ")"
const allSep* = "(?:" & subexprSep & "|" & exprSep & ")"

type
  TimeCommandType* = enum
    tctRemainderSet = (0, "setRemainder")
    tctRelativeUnitSet = "setRelativeUnit"
    tctUnitAdd = "addUnit"
    tctRecurUnit = "recurUnit"
  
  TimeCommand* = object
    kind*: TimeCommandType
    num*: int
    unit*: string

type
  Parser* = object
    parse*: proc(parser: Parser, input: string): Option[seq[TimeCommand]]

proc parseRemaining*(parser: Parser, remaining: string, commands: seq[TimeCommand]): Option[seq[TimeCommand]] = 
  if remaining == "":
    return some(commands)
  let otherCommands = parser.parse(parser, remaining)
  if otherCommands.isSome:
    return some(commands & otherCommands.get)

type RegexMapResult*[T] = object
  match*: RegexMatch
  remaining*: string
  value*: T

proc regexMap*[T](s: string, mapping: seq[tuple[pattern: string, value: T]]): Option[RegexMapResult[T]] =
  for pattern, value in mapping.items:
    let m = s.match(re(pattern));
    if not m.isSome:
      continue
    var remaining = s[m.get.matchBounds.b + 1 .. s.len - 1]
    if remaining != "" and not remaining.startsWith(exprSep):
      continue
    remaining.removePrefix(exprSep)
    return some(RegexMapResult[T](
      match : m.get,
      remaining : remaining,
      value : value
    ))

