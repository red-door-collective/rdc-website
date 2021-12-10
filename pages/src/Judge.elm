module Judge exposing (Judge, decoder)

import Json.Decode as Decode exposing (Decoder, int, list, string)
import Json.Decode.Pipeline exposing (required)


type alias Judge =
    { id : Int, name : String, aliases : List String }


decoder : Decoder Judge
decoder =
    Decode.succeed Judge
        |> required "id" int
        |> required "name" string
        |> required "aliases" (list string)
