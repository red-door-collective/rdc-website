module Campaign exposing (Campaign, ShallowEvent, decoder)

import Json.Decode as Decode exposing (Decoder, int, list, string)
import Json.Decode.Pipeline exposing (required)


type alias Campaign =
    { id : Int, name : String, events : List ShallowEvent }


type alias ShallowEvent =
    { id : Int, name : String }


shallowEventDecoder : Decoder ShallowEvent
shallowEventDecoder =
    Decode.succeed ShallowEvent
        |> required "id" int
        |> required "name" string


decoder : Decoder Campaign
decoder =
    Decode.succeed Campaign
        |> required "id" int
        |> required "name" string
        |> required "events" (list shallowEventDecoder)
