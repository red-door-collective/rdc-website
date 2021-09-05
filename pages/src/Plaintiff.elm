module Plaintiff exposing (Plaintiff, decoder)

import Json.Decode as Decode exposing (Decoder, Value, bool, float, int, list, nullable, string)
import Json.Decode.Pipeline exposing (custom, hardcoded, optional, required)


type alias Plaintiff =
    { id : Int, name : String, aliases : List String }


decoder : Decoder Plaintiff
decoder =
    Decode.succeed Plaintiff
        |> required "id" int
        |> required "name" string
        |> required "aliases" (list string)
