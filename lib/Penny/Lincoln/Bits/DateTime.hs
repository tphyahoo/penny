-- | Perhaps this could be called @moment@, as it aims to identify a
-- moment in time. A DateTime is a combination of a LocalTime from
-- Data.Time and a TimeZoneOffset. Previously a DateTime was simply a
-- ZonedTime from Data.Time but ZonedTime has data that Penny does not
-- need.
module Penny.Lincoln.Bits.DateTime (
  DateTime
  , dateTime
  , localTime
  , timeZone
  , TimeZoneOffset
  , offsetToMins
  , minsToOffset
  , noOffset
  ) where

import qualified Data.Time as T

-- | The number of minutes that this timezone is offset from UTC. Can
-- be positive, negative, or zero.
newtype TimeZoneOffset = TimeZoneOffset { offsetToMins :: Int }
                         deriving (Eq, Ord, Show)

-- | Convert minutes to a time zone offset. I'm having a hard time
-- deciding whether to be liberal or strict in what to accept
-- here. Currently it is somewhat strict in that it will fail if
-- absolute value is greater than 840 minutes; currently the article
-- at http://en.wikipedia.org/wiki/List_of_time_zones_by_UTC_offset
-- says there is no offset greater than 14 hours, or 840 minutes.
minsToOffset :: Int -> Maybe TimeZoneOffset
minsToOffset m = if abs m > 840
                 then Nothing
                 else Just $ TimeZoneOffset m

noOffset :: TimeZoneOffset
noOffset = TimeZoneOffset 0

-- | A DateTime is a UTC time that also remembers the local time from
-- which it was set. The Eq and Ord instances will compare two
-- DateTimes based on their equivalent UTC times.
data DateTime = DateTime { localTime :: T.LocalTime
                         , timeZone :: TimeZoneOffset }
                   deriving Show

-- | Construct a DateTime.
dateTime :: T.LocalTime -> TimeZoneOffset -> DateTime
dateTime = DateTime

toUTC :: DateTime -> T.UTCTime
toUTC (DateTime lt (TimeZoneOffset tzo)) = T.localTimeToUTC tz lt where
  tz = T.minutesToTimeZone tzo

instance Eq DateTime where
  l == r = toUTC l == toUTC r

instance Ord DateTime where
  compare l r = compare (toUTC l) (toUTC r)
