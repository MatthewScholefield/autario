import options
import nre
import strutils
import collections/tables
import times

import ../exceptions

import parserutils

const weekdayPatterns = @[
  ("mon(?:day)?", dMon),
  ("tue(?:s(?:day)?)?", dTue),
  ("wed(?:nesday)?", dWed),
  ("thu(?:rs(?:day)?)?", dThu),
  ("fri(?:day)?", dFri),
  ("(?:sat(?:urday)?|weekend)", dSat),
  ("sun(?:day)?", dSun)
]
const monthPatterns = @[
  ("jan(?:uary)?", mJan),
  ("feb(?:ruary)?", mFeb),
  ("mar(?:ch)?", mMar),
  ("apr(?:il)?", mApr),
  ("may", mMay),
  ("june?", mJun),
  ("july?", mJul),
  ("aug(?:ust)?", mAug),
  ("sep(?:tember)?", mSep),
  ("oct(?:ober)?", mOct),
  ("nov(?:ember)?", mNov),
  ("dec(?:ember)?", mDec)
]
const timePattern = r"(?P<hour>[0-9]{1,2})(?:" & [
  r":(?P<minute_1>[0-9]{2})(?:" & subexprSep & r"(?P<ampm_1>am|pm))?",
  subexprSep & r"(?P<ampm_0>am|pm)",
].join("|") & ")"
const exactPatterns = @[
  r"(?<monthday_0>[0123]?[0-9])(?:th|rd|st|nd)",
  r"(?<year_1>[0-9]{4})\-(?<month_1>[01]?[0-9])\-(?<monthday_1>[0123]?[0-9])",
  r"(?<year_2>[0-9]{4})\/(?<month_2>[01]?[0-9])\/(?<monthday_2>[0123]?[0-9])"
]
const deltaPatterns = @[
  r"(?<seconds>[0-9]{1,9})" & subexprSep & r"s(?:ec(?:ond)?s?)?",
  r"(?<minutes>[0-9]{1,7})" & subexprSep & r"m(?:in(?:ute)?)?s?",
  r"(?<hours>[0-9]{1,5})" & subexprSep & r"h(?:ou)?(?:rs?)?",
  r"(?<days>[0-9]{1,4})" & subexprSep & r"d(?:ay)?s?",
  r"(?<weeks>[0-9]{1,3})" & subexprSep & r"w(?:ee)?ks?",
  r"(?<months>[0-9]{1,3})" & subexprSep & r"months?",
  r"(?<years>[0-9]{1,2})" & subexprSep & r"y(?:(?:ea)?rs?)?",
]
const nextPatterns = @[
  r"(?<seconds>sec(?:ond)?)",
  r"(?<minutes>min(?:ute)?)",
  r"(?<hours>h(?:ou)?r)",
  r"(?<days>day)",
  r"(?<weeks>week)",
  r"(?<months>month)",
  r"(?<year>year)",
]
const relativePattern = "(?<offsets>(?:" & ["day", "(?:before|after)", ""].join(
    allSep) & ")*)(?<day>today|tomorrow|yesterday)"
const nextPatternBase = "(?<nexts>(?:(?:next|this|last)" & allSep & ")+)"

proc joinRegex[T](patterns: seq[tuple[pattern: string, value: T]]): string =
  "(" & (var s: seq[string]; for i in patterns: s.add(i[0]); s.join("|")) & ")"

proc joinRegex(patterns: seq[string]): string =
  "(" & patterns.join("|") & ")"

proc extractGroups(match: RegexMatch): Table[string, string] =
  for key, value in match.captures.toTable.pairs:
    result[key.split("_")[0]] = value

proc enumMatchToCommands[T](unit: parserutils.RTimeUnit, patterns: seq[tuple[pattern: string,
    value: T]], match: RegexMatch): seq[RTimeCommand] =
  let value = match.match.regexMap(patterns).get.value
  result.add(RTimeCommand(
    kind: tctRemainderSet,
    num: value.ord(),
    unit: unit
  ))

proc makeTimeHandler(): auto =
  (proc(match: RegexMatch): seq[RTimeCommand] {.closure.} =
    let
      groups = extractGroups(match)
      minute = groups.getOrDefault("minute")
    var
      hour = groups["hour"].parseInt
      isPm = groups.getOrDefault("ampm", "am") == "pm"
    if hour == 12:
      isPm = not isPm
    if isPm:
      hour = (hour + 12) mod 24

    result.add(RTimeCommand(
      kind: tctRemainderSet,
      num: hour,
      unit: tuHour
    ))
    if minute != "":
      result.add(RTimeCommand(
        kind: tctRemainderSet,
        num: minute.parseInt,
        unit: tuMinute
      )))

proc makeNextHandler(): auto =
  (proc(match: RegexMatch): seq[RTimeCommand] {.closure.} =
    var groups = extractGroups(match)
    let nextCount = groups["nexts"].count("next") - groups["nexts"].count("last")
    groups.del("nexts")
    assert(groups.len == 1)
    for key, value in groups.pairs:
      if key == "second" or key == "seconds":
        raise newException(AutaError, "Seconds precision is not supported.")
      result.add(RTimeCommand(
        kind: tctRelativeUnitSet,
        num: nextCount,
        unit: parseEnum[parserutils.RTimeUnit](key)
      )))

proc makeEnumHandler[T](unit: parserutils.RTimeUnit, patterns: seq[tuple[pattern: string,
    value: T]]): auto =
  (proc(m: RegexMatch): seq[RTimeCommand] = (enumMatchToCommands(unit,
      patterns, m)))

proc makeMatchHandler(commandType: RRTimeCommandType): auto =
  (proc(match: RegexMatch): seq[RTimeCommand] =
    for key, value in extractGroups(match).pairs:
      if key == "second" or key == "seconds":
        raise newException(AutaError, "Seconds precision is not supported.")
      result.add(RTimeCommand(
        kind: commandType,
        num: value.parseInt,
        unit: parseEnum[parserutils.RTimeUnit](key)
      )))

proc makeRelativeMatchHandler(): auto =
  (proc(match: RegexMatch): seq[RTimeCommand] {.closure.} =
    let groups = extractGroups(match)
    result.add(RTimeCommand(
      kind: tctRelativeUnitSet,
      num: groups["offsets"].count("after") - groups["offsets"].count("before") +
          (if groups["day"] == "tomorrow": 1 else: (if groups["day"] == "today": 0 else: -1)),
      unit: tuDays
    )))
proc parseTime*(parser: Parser, input: string): Option[seq[RTimeCommand]] =
  var patterns = @[
    (timePattern, makeTimeHandler()),
    (weekdayPatterns.joinRegex(), makeEnumHandler(tuWeekday, weekdayPatterns)),
    (monthPatterns.joinRegex(), makeEnumHandler(tuMonth, monthPatterns)),
    (exactPatterns.joinRegex(), makeMatchHandler(tctRemainderSet)),
    (deltaPatterns.joinRegex(), makeMatchHandler(tctUnitAdd)),
    (nextPatternBase & nextPatterns.joinRegex(), makeNextHandler()),
    (relativePattern, makeRelativeMatchHandler())
  ]
  let mapResult = input.regexMap(patterns)
  if mapResult.isSome:
    let commands = mapResult.get.value(mapResult.get.match)
    return parser.parseRemaining(mapResult.get.remaining, commands)

when isMainModule:
    import ../timequantifier
    import ../formatting
    import times
    import strformat
    import os
    let inp = paramStr(1)
    let res = Parser(parse : parseTime).parseTime(inp)
    let output = if res.isNone: "error" else: $res.get
    echo &"Input: \"{inp}\""
    echo &"Output: {output}"
    if res.isSome:
      let quant = res.get.quantifyTime(now())
      let dateStr = quant.date.format("yyyy-MM-dd HH:mm")
      let precisionStr = formatDuration(quant.precision, 1, 60)
      # Loop over units (days, hours, minutes), and 
      echo &"Quantified: {dateStr} (precision = {precisionStr})"
