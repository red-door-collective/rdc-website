module User exposing (NavigationOnSuccess(..), Permissions(..), Role, User, canViewCourtData, canViewDefendantInformation, databaseHomeUrl, decoder, navigationToText)

import Json.Decode as Decode exposing (Decoder, int, list, nullable, string)
import Json.Decode.Pipeline exposing (required)


type Permissions
    = Superuser


type alias Role =
    { id : Int
    , name : String
    , description : Maybe String
    }


type NavigationOnSuccess
    = Remain
    | PreviousWarrant
    | NextWarrant
    | NewWarrant


type alias User =
    { id : Int
    , email : String
    , firstName : String
    , lastName : String
    , name : String
    , roles : List Role
    , preferredNavigation : NavigationOnSuccess
    }


databaseHomeUrl user =
    if canViewDefendantInformation user then
        "/admin/detainer-warrants"

    else
        "/admin/plaintiffs"


canViewCourtData : User -> Bool
canViewCourtData user =
    user.roles
        |> List.filter (\role -> List.member role.name [ "Partner", "Organizer", "Admin", "Superuser" ])
        |> List.head
        |> (/=) Nothing


canViewDefendantInformation : User -> Bool
canViewDefendantInformation user =
    user.roles
        |> List.filter (\role -> List.member role.name [ "Organizer", "Admin", "Superuser" ])
        |> List.head
        |> (/=) Nothing


navigationToText : NavigationOnSuccess -> String
navigationToText nav =
    case nav of
        Remain ->
            "REMAIN"

        PreviousWarrant ->
            "PREVIOUS_WARRANT"

        NextWarrant ->
            "NEXT_WARRANT"

        NewWarrant ->
            "NEW_WARRANT"


navigationFromText : String -> NavigationOnSuccess
navigationFromText str =
    case str of
        "REMAIN" ->
            Remain

        "PREVIOUS_WARRANT" ->
            PreviousWarrant

        "NEXT_WARRANT" ->
            NextWarrant

        "NEW_WARRANT" ->
            NewWarrant

        _ ->
            Remain


navigationSuccessDecoder =
    Decode.string
        |> Decode.andThen
            (\str ->
                Decode.succeed <| navigationFromText str
            )


roleDecoder =
    Decode.succeed Role
        |> required "id" int
        |> required "name" string
        |> required "description" (nullable string)


decoder : Decoder User
decoder =
    Decode.succeed User
        |> required "id" int
        |> required "email" string
        |> required "first_name" string
        |> required "last_name" string
        |> required "name" string
        |> required "roles" (list roleDecoder)
        |> required "preferred_navigation" navigationSuccessDecoder
