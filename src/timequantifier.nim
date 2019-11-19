import parsing/parserutils
import times
import options

import exceptions
import parsing/parserutils


type TimeUnit = enum
  tuMinute = (0, "minute")
  tuHour = "hour"
  tuWeekday = "weekday"
  tuMonthday = "monthday"

proc quantifyTime*(commands: seq[TimeCommand], src: Datetime): int =
  var timeType: Option[TimeCommandType]
  var date = src
  var delta: TimeInterval
  for command in commands:
    if timeType.isNone:
      timeType = some(command.kind)
    else:
      if timeType.get != command.kind:
        raise newException(AutaError, "Cannot mix ways of quantifying time")
  if timeType.isNone:
    raise newException(AutaError, "No commands provided")
  
  var precision = Inf

  case timeType.get:
  of tctRemainderSet:
    for command in commands:
      case command.unit:
      of "minute":
        date.minute = command.num.MinuteRange
        precision = min(precision, 60)
      of "hour":
        date.hour = command.num.HourRange
        precision = min(precision, 60 * 60)
      of "weekday":
        delta.days = 1 + (command.num - src.weekday.ord - 1) mod 7
        precision = min(precision, 24 * 60 * 60)
      of "monthday":
        date.monthday = command.num.MonthdayRange
        precision = min(precision, 24 * 60 * 60)
      of "month":
        date.month = command.num.Month
        precision = min(precision, 30 * 24 * 60 * 60)
      of "year":
        date.year = command.num
        precision = min(precision, 365 * 24 * 60 * 60)
      else:
        raise newException(AutaError, "No such command unit: " & command.unit)
  of tctRelativeUnitSet:
    if commands.len != 1:
      raise newException(AutaError, "More than one relative units specified")
    let command = commands[0]
    case command.unit:
      of "minute":
        date.minute = command.num.MinuteRange
        precision = min(precision, 60)
      of "hour":
        date.hour = command.num.HourRange
        precision = min(precision, 60 * 60)
      of "weekday":
        delta.days = 1 + (command.num - src.weekday.ord - 1) mod 7
        precision = min(precision, 24 * 60 * 60)
      of "monthday":
        date.monthday = command.num.MonthdayRange
        precision = min(precision, 24 * 60 * 60)
      of "month":
        date.month = command.num.Month
        precision = min(precision, 30 * 24 * 60 * 60)
      of "year":
        date.year = command.num
        precision = min(precision, 365 * 24 * 60 * 60)
      else:
        raise newException(AutaError, "No such command unit: " & command.unit)
  else:
    discard
