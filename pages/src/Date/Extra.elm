module Date.Extra exposing (fromPosix, toPosix)

import Date exposing (Date)
import Iso8601
import Time exposing (Posix)


fromPosix : Posix -> Date
fromPosix posix =
    Date.fromPosix Time.utc posix


toPosix : Date -> Maybe Posix
toPosix =
    Result.toMaybe << Iso8601.toTime << Date.toIsoString
