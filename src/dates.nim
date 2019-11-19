import times
import options

type ExactTime* = object
  minute: Option[MinuteRange]
  hour: Option[HourRange]
  weekday: Option[WeekDay]
  monthday: Option[MonthdayRange]
  month: Option[Month]
  year: Option[int]


