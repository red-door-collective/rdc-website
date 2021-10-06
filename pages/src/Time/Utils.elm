module Time.Utils exposing (toIsoString)

import Date
import Date.Extra
import Time exposing (Posix)


toIsoString : Posix -> String
toIsoString =
    Date.toIsoString << Date.Extra.fromPosix
