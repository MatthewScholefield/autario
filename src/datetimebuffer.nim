import times


type DateTimeBuffer* = object
  minute*: MinuteRange
  hour*: HourRange
  monthday*: MonthdayRange
  month*: Month
  year*: int
  timezone*: Timezone

proc toBuffer*(time: DateTime): DateTimeBuffer =
  DateTimeBuffer(
      minute : time.minute,
      hour : time.hour,
      monthday : time.monthday,
      month : time.month,
      year : time.year,
      timezone : time.timezone
  )

proc toDateTime*(buffer: DateTimeBuffer): DateTime =
    dateTime(
        monthday = buffer.monthday,
        month = buffer.month,
        year = buffer.year,
        hour = buffer.hour,
        minute = buffer.minute,
        second = 0,
        nanosecond = 0,
        zone = buffer.timezone
    )
