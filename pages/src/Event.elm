module Event exposing (CanvassEvent, Event(..), GenericEvent, PhoneBankEvent, decoder)

import Defendant exposing (Defendant)
import DetainerWarrant exposing (DetainerWarrant)
import Json.Decode as Decode exposing (Decoder, int, list, string)
import Json.Decode.Pipeline exposing (required)


type alias PhoneBankEvent =
    { id : Int
    , name : String
    , tenants : List Defendant
    }


type alias CanvassEvent =
    { id : Int
    , name : String
    , warrants : List DetainerWarrant
    }


type alias GenericEvent =
    { id : Int
    , name : String
    }


type Event
    = PhoneBank PhoneBankEvent
    | Canvass CanvassEvent
    | Generic GenericEvent


phoneBankEventDecoder : Decoder PhoneBankEvent
phoneBankEventDecoder =
    Decode.succeed PhoneBankEvent
        |> required "id" int
        |> required "name" string
        |> required "tenants" (list Defendant.decoder)


canvassEventDecoder : Decoder CanvassEvent
canvassEventDecoder =
    Decode.succeed CanvassEvent
        |> required "id" int
        |> required "name" string
        |> required "warrants" (list DetainerWarrant.decoder)


genericEventDecoder : Decoder GenericEvent
genericEventDecoder =
    Decode.succeed GenericEvent
        |> required "id" int
        |> required "name" string


decoder : Decoder Event
decoder =
    Decode.field "type" string
        |> Decode.andThen
            (\eventType ->
                case eventType of
                    "phone_bank_event" ->
                        Decode.map PhoneBank phoneBankEventDecoder

                    "canvass_event" ->
                        Decode.map Canvass canvassEventDecoder

                    _ ->
                        Decode.map Generic genericEventDecoder
            )
