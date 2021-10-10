module Time.Utils exposing (posixDecoder, toIsoString)

import Date
import Date.Extra
import Json.Decode as Decode exposing (Decoder)
import Time exposing (Posix)


toIsoString : Posix -> String
toIsoString =
    Date.toIsoString << Date.Extra.fromPosix


posixDecoder : Decoder Posix
posixDecoder =
    Decode.map Time.millisToPosix Decode.int
