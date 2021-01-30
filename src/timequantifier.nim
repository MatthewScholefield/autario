import parsing/parserutils
import collections/tables
import times
import options

import exceptions
import parsing/parserutils
import datetimebuffer

type QuantifiedTime = tuple[date: DateTime, precision: int]

proc quantifyTime*(unsortedCommands: seq[RTimeCommand], src: Datetime): QuantifiedTime =
  var date = src.toBuffer
  var delta: TimeInterval

  var commands: Table[RRTimeCommandType, seq[RTimeCommand]]
  for command in unsortedCommands:
    discard commands.hasKeyOrPut(command.kind, @[])
    commands[command.kind].add(command)
  
  if commands.hasKey(tctUnitAdd) and commands.len > 1:
    raise newException(AutaError, "Cannot mix ways of quantifying time.")
  
  var precision = high(int)

  proc mark(prec: var int, size: int) =
    prec = min(prec, size)

  for timeType, commands in commands:
    case timeType:
    of tctRemainderSet:
      for command in commands:
        case command.unit:
        of tuMinute:
          date.minute = command.num
          precision.mark(60)
        of tuHour:
          date.hour = command.num
          precision.mark(60 * 60)
        of tuWeekday:
          delta.days = 1 + (command.num - src.weekday.ord - 1) mod 7
          precision.mark(24 * 60 * 60)
        of tuMonthday:
          date.monthday = command.num
          precision.mark(24 * 60 * 60)
        of tuMonth:
          date.month = command.num.Month
          precision.mark(30 * 24 * 60 * 60)
        of tuYear:
          date.year = command.num
          precision.mark(365 * 24 * 60 * 60)
        else:
          raise newException(AutaError, "No such command unit: " & $command.unit)
    of tctRelativeUnitSet:
      if commands.len != 1:
        raise newException(AutaError, "More than one relative units specified")
      let command = commands[0]
      case command.unit:
        of tuMinutes:
          delta.minutes = command.num
          precision.mark(60)
        of tuHours:
          delta.hours = command.num
          date.minute = 0
          precision.mark(60 * 60)
        of tuDays:
          delta.days = command.num
          date.hour = 0
          date.minute = 0
          precision.mark(24 * 60 * 60)
        of tuWeeks:
          delta.weeks = command.num
          delta.days -= (src.weekday.ord - dSun.ord) mod 7
          date.hour = 0
          date.minute = 0
          precision.mark(7 * 24 * 60 * 60)
        of tuMonths:
          delta.months = command.num
          date.monthday = 1
          date.hour = 0
          date.minute = 0
          precision.mark(30 * 24 * 60 * 60)
        of tuYears:
          delta.years = command.num
          date.month = mJan
          date.monthday = 1
          date.hour = 0
          date.minute = 0
          precision.mark(365 * 24 * 60 * 60)
        else:
          raise newException(AutaError, "No such command unit: " & $command.unit)
    of tctUnitAdd:
      for command in commands:
        case command.unit:
          of tuMinutes:
            delta.minutes += command.num
            precision.mark(60)
          of tuHours:
            delta.hours += command.num
            precision.mark(60 * 60)
          of tuDays:
            delta.days += command.num
            precision.mark(24 * 60 * 60)
          of tuWeeks:
            delta.weeks += command.num
            precision.mark(7 * 24 * 60 * 60)
          of tuMonths:
            delta.months += command.num
            precision.mark(30 * 24 * 60 * 60)
          of tuYears:
            delta.years += command.num
            precision.mark(365 * 24 * 60 * 60)
          else:
            raise newException(AutaError, "No such command unit: " & $command.unit)
    else:
      raise newException(AutaError, "Time command type cannot be quantified: " & $timeType)
  
  let base = date.toDateTime
  return (base + delta, precision)
