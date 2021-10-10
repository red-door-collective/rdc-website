module Attorney exposing (Attorney, AttorneyForm, decoder)

import Json.Decode as Decode exposing (Decoder, int, list, string)
import Json.Decode.Pipeline exposing (required)
import SearchBox


type alias Attorney =
    { id : Int, name : String, aliases : List String }


type alias AttorneyForm =
    { person : Maybe Attorney
    , text : String
    , searchBox : SearchBox.State
    }


decoder : Decoder Attorney
decoder =
    Decode.succeed Attorney
        |> required "id" int
        |> required "name" string
        |> required "aliases" (list string)
