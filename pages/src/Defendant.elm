module Defendant exposing (Defendant, decoder)

import Json.Decode as Decode exposing (Decoder, int, list, nullable, string)
import Json.Decode.Pipeline exposing (optional, required)


type alias VerifiedPhone =
    { callerName : Maybe String
    , phoneType : Maybe String
    , nationalFormat : String
    }


type alias Defendant =
    { id : Int
    , name : String
    , firstName : String
    , middleName : Maybe String
    , lastName : String
    , suffix : Maybe String
    , aliases : List String
    , potentialPhones : Maybe String
    , verifiedPhone : Maybe VerifiedPhone
    }


verifiedPhoneDecoder : Decoder VerifiedPhone
verifiedPhoneDecoder =
    Decode.succeed VerifiedPhone
        |> required "caller_name" (nullable string)
        |> required "phone_type" (nullable string)
        |> required "national_format" string


decoder : Decoder Defendant
decoder =
    Decode.succeed Defendant
        |> required "id" int
        |> required "name" string
        |> optional "first_name" string ""
        |> required "middle_name" (nullable string)
        |> optional "last_name" string ""
        |> required "suffix" (nullable string)
        |> required "aliases" (list string)
        |> required "potential_phones" (nullable string)
        |> required "verified_phone" (nullable verifiedPhoneDecoder)
