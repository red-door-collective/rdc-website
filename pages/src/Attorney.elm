module Attorney exposing (Attorney, decoder)

import Json.Decode as Decode exposing (Decoder, Value, bool, float, int, list, nullable, string)
import Json.Decode.Pipeline exposing (custom, hardcoded, optional, required)


type alias Attorney =
    { id : Int, name : String, aliases : List String }


decoder : Decoder Attorney
decoder =
    Decode.succeed Attorney
        |> required "id" int
        |> required "name" string
        |> required "aliases" (list string)
