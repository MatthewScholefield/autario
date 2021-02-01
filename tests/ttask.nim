import options
import times

import ../src/parsing/parserutils
import ../src/parsing/recurparser
import ../src/task


proc parseRecur(s: string): seq[RTimeCommand] =
    Parser(parse : parseRecur).parseRecur(s).get

var offsets: seq[RTimeCommand]

offsets = parseRecur("2nd")
assert extractImplicitRecurrence(offsets) == RTimeCommand(
    kind : tctRecurUnit,
    num : 1,
    unit : tuMonths
)
assert offsets.len == 1

offsets = parseRecur("2weeks")
assert extractImplicitRecurrence(offsets) == RTimeCommand(
    kind : tctRecurUnit,
    num : 2,
    unit : tuWeeks
)
assert offsets.len == 0

offsets = parseRecur("wed.8pm")
assert extractImplicitRecurrence(offsets) == RTimeCommand(
    kind : tctRecurUnit,
    num : 1,
    unit : tuWeeks
)
assert offsets.len == 2
assert offsets.contains(RTimeCommand(
    kind : tctRemainderSet,
    num : dWed.ord,
    unit : tuWeekday
))
assert offsets.contains(RTimeCommand(
    kind : tctRemainderSet,
    num : 20,
    unit : tuHour
))
