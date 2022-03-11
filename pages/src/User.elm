module User exposing (NavigationOnSuccess(..), Permissions(..), Role, User, canViewCourtData, canViewDefendantInformation, databaseHomeUrl, decoder, encode, navigationToText, staticDecoder)

import Json.Decode as Decode exposing (Decoder, int, list, nullable, string)
import Json.Decode.Pipeline exposing (required)
import Json.Encode as Encode
import OptimizedDecoder as OD
import OptimizedDecoder.Pipeline as OP


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


staticNavigationSuccessDecoder =
    OD.string
        |> OD.andThen
            (\str ->
                OD.succeed <| navigationFromText str
            )


roleDecoder =
    Decode.succeed Role
        |> required "id" int
        |> required "name" string
        |> required "description" (nullable string)


staticRoleDecoder =
    OD.succeed Role
        |> OP.required "id" OD.int
        |> OP.required "name" OD.string
        |> OP.required "description" (OD.nullable OD.string)


encodeRole : Role -> Encode.Value
encodeRole role =
    Encode.object
        [ ( "id", Encode.int role.id )
        , ( "name", Encode.string role.name )
        , ( "description"
          , case role.description of
                Just description ->
                    Encode.string description

                Nothing ->
                    Encode.null
          )
        ]


encode : User -> Encode.Value
encode user =
    Encode.object
        [ ( "id", Encode.int user.id )
        , ( "email", Encode.string user.email )
        , ( "first_name", Encode.string user.firstName )
        , ( "last_name", Encode.string user.lastName )
        , ( "name", Encode.string user.name )
        , ( "roles", Encode.list encodeRole user.roles )
        , ( "preferred_navigation", Encode.string (navigationToText user.preferredNavigation) )
        ]


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


staticDecoder : OD.Decoder User
staticDecoder =
    OD.succeed User
        |> OP.required "id" OD.int
        |> OP.required "email" OD.string
        |> OP.required "first_name" OD.string
        |> OP.required "last_name" OD.string
        |> OP.required "name" OD.string
        |> OP.required "roles" (OD.list staticRoleDecoder)
        |> OP.required "preferred_navigation" staticNavigationSuccessDecoder
