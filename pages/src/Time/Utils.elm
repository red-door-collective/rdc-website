module Time.Utils exposing (posixDecoder, posixEncoder, toIsoString)

import Date
import Date.Extra
import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode exposing (Value)
import Time exposing (Posix)


toIsoString : Posix -> String
toIsoString =
    Date.toIsoString << Date.Extra.fromPosix


posixDecoder : Decoder Posix
posixDecoder =
    Decode.map Time.millisToPosix Decode.int


posixEncoder : Posix -> Value
posixEncoder posix =
    Encode.int (Time.toMillis Time.utc posix)
