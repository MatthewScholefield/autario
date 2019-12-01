import options
import nre
import strutils

import timeparser
import parserutils

const recurPatterns = @[
  ("daily", tuDays),
  ("weekly", tuWeeks),
  ("monthly", tuMonths),
  ("yearly", tuYears)
]

proc parseRecur*(parser: Parser, input: string): Option[seq[RTimeCommand]] =
  let commandsOption = parseTime(parser, input)
  if commandsOption.isSome:
    return commandsOption
  let mapResult = input.regexMap(recurPatterns)
  if mapResult.isSome:
    return parser.parseRemaining(mapResult.get.remaining, @[RTimeCommand(
        kind: tctRecurUnit,
        num: 1,
        unit: mapResult.get.value
    )])
