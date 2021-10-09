module Courtroom exposing (..)

import Json.Decode as Decode exposing (Decoder, int, string)
import Json.Decode.Pipeline exposing (required)


type alias Courtroom =
    { id : Int, name : String }


decoder : Decoder Courtroom
decoder =
    Decode.succeed Courtroom
        |> required "id" int
        |> required "name" string
