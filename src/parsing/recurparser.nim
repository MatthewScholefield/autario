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

proc parseRecur*(parser: Parser, input: string): Option[seq[TimeCommand]] =
  let commandsOption = parseTime(parser, input)
  if commandsOption.isSome:
    return commandsOption
  let mapResult = input.regexMap(recurPatterns)
  if mapResult.isSome:
    return parser.parseRemaining(mapResult.get.remaining, @[TimeCommand(
        kind: tctRecurUnit,
        num: 1,
        unit: mapResult.get.value
    )])
