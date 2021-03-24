module Route exposing (Route(..), fromUrl, href, replaceUrl)

import Browser.Navigation as Nav
import Url exposing (Url)
import Url.Parser as Parser exposing ((</>), Parser, oneOf, s, string)



-- ROUTING


type Route
    = Root
    | Login
    | Logout
    | Trends
    | About
    | WarrantHelp
    | Actions


parser : Parser (Route -> a) a
parser =
    oneOf
        [ Parser.map Trends Parser.top
        , Parser.map Login (s "login")
        , Parser.map Logout (s "logout")
        , Parser.map Trends (s "trends")
        , Parser.map About (s "about")
        , Parser.map WarrantHelp (s "warrant-help")
        , Parser.map Actions (s "actions")
        ]



-- PUBLIC HELPERS


href : Route -> String
href targetRoute =
    routeToString targetRoute


replaceUrl : Nav.Key -> Route -> Cmd msg
replaceUrl key route =
    Nav.replaceUrl key (routeToString route)


fromUrl : Url -> Maybe Route
fromUrl url =
    Parser.parse parser url



-- INTERNAL


routeToString : Route -> String
routeToString page =
    "/" ++ String.join "/" (routeToPieces page)


routeToPieces : Route -> List String
routeToPieces page =
    case page of
        Root ->
            []

        Login ->
            [ "login" ]

        Logout ->
            [ "logout" ]

        Trends ->
            [ "trends" ]

        About ->
            [ "about" ]

        WarrantHelp ->
            [ "warrant-help" ]

        Actions ->
            [ "actions" ]
