module User exposing (..)

import Json.Decode as Decode exposing (Decoder, int, list, string)
import Json.Decode.Pipeline exposing (required)


type alias Role =
    { id : Int
    , name : String
    , description : String
    }


type alias User =
    { id : Int
    , firstName : String
    , lastName : String
    , name : String
    , roles : List Role
    }


roleDecoder : Decoder Role
roleDecoder =
    Decode.succeed Role
        |> required "id" int
        |> required "name" string
        |> required "description" string


userDecoder : Decoder User
userDecoder =
    Decode.succeed User
        |> required "id" int
        |> required "first_name" string
        |> required "last_name" string
        |> required "name" string
        |> required "roles" (list roleDecoder)
