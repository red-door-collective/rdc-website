module Judge exposing (Judge, JudgeForm, decoder)

import Json.Decode as Decode exposing (Decoder, Value, bool, float, int, list, nullable, string)
import Json.Decode.Pipeline exposing (custom, hardcoded, optional, required)
import SearchBox


type alias Judge =
    { id : Int, name : String, aliases : List String }


type alias JudgeForm =
    { person : Maybe Judge
    , text : String
    , searchBox : SearchBox.State
    }


decoder : Decoder Judge
decoder =
    Decode.succeed Judge
        |> required "id" int
        |> required "name" string
        |> required "aliases" (list string)
