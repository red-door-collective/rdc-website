module Attorney exposing (Attorney, decoder)

import Json.Decode as Decode exposing (Decoder, int, list, string)
import Json.Decode.Pipeline exposing (required)


type alias Attorney =
    { id : Int, name : String, aliases : List String }


decoder : Decoder Attorney
decoder =
    Decode.succeed Attorney
        |> required "id" int
        |> required "name" string
        |> required "aliases" (list string)
