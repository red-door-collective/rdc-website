module Courtroom exposing (..)

import Json.Decode as Decode exposing (Decoder, float, int, list, nullable, string)
import Json.Decode.Pipeline exposing (hardcoded, optional, required)


type alias Courtroom =
    { id : Int, name : String }


decoder : Decoder Courtroom
decoder =
    Decode.succeed Courtroom
        |> required "id" int
        |> required "name" string
