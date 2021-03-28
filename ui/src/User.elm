module User exposing (Permissions(..), Role, User, permissions, roleDecoder, userDecoder)

import Json.Decode as Decode exposing (Decoder, int, list, string)
import Json.Decode.Pipeline exposing (required)


type Permissions
    = Superuser
    | Admin
    | Organizer
    | Defendant


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


hasPermission : String -> List Role -> Bool
hasPermission name roles =
    roles
        |> List.filter (\role -> role.name == name)
        |> List.isEmpty
        |> not


permissions : User -> Permissions
permissions user =
    if hasPermission "Superuser" user.roles then
        Superuser

    else if hasPermission "Admin" user.roles then
        Admin

    else if hasPermission "Organizer" user.roles then
        Organizer

    else if hasPermission "Defendant" user.roles then
        Defendant

    else
        Defendant


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
