module Route exposing (Route(..), fromUrl, href, replaceUrl)

import Browser.Navigation as Nav
import Date
import Search
import Url exposing (Url)
import Url.Parser as Parser exposing ((</>), (<?>), Parser, fragment, int, oneOf, query, s, string)
import Url.Parser.Query as Query



-- ROUTING


type Route
    = Root
    | Login
    | Logout
    | Trends
    | About
    | WarrantHelp
    | Actions
    | Glossary (Maybe String)
    | OrganizerDashboard
    | CampaignOverview Int
    | Event Int Int
    | ManageDetainerWarrants Search.DetainerWarrants
    | DetainerWarrantCreation (Maybe String)
    | ManagePlaintiffs Search.Plaintiffs
    | PlaintiffCreation (Maybe Int)


searchWarrantsParser =
    Query.map7 Search.DetainerWarrants
        (Query.string "docket_id")
        (Query.map (Result.toMaybe << Date.fromIsoString << Maybe.withDefault "") (Query.string "file_date"))
        (Query.map (Result.toMaybe << Date.fromIsoString << Maybe.withDefault "") (Query.string "court_date"))
        (Query.string "plaintiff")
        (Query.string "plaintiff_attorney")
        (Query.string "defendant_name")
        (Query.string "address")


searchPlaintiffsParser =
    Query.map Search.Plaintiffs
        (Query.string "name")


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
        , Parser.map Glossary (s "glossary" </> fragment identity)
        , Parser.map OrganizerDashboard (s "organize" </> s "dashboard")
        , Parser.map CampaignOverview (s "organize" </> s "campaigns" </> int)
        , Parser.map Event (s "organize" </> s "campaigns" </> int </> s "events" </> int)
        , Parser.map ManageDetainerWarrants (s "organize" </> s "detainer-warrants" <?> searchWarrantsParser)
        , Parser.map (DetainerWarrantCreation Nothing) (s "organize" </> s "detainer-warrants" </> s "edit")
        , Parser.map (DetainerWarrantCreation << Just) (s "organize" </> s "detainer-warrants" </> s "edit" </> string)
        , Parser.map ManagePlaintiffs (s "organize" </> s "plaintiffs" <?> searchPlaintiffsParser)
        , Parser.map (PlaintiffCreation Nothing) (s "organize" </> s "plaintiffs" </> s "edit")
        , Parser.map (PlaintiffCreation << Just) (s "organize" </> s "plaintiffs" </> s "edit" </> int)
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

        Glossary fragment ->
            [ "glossary" ]
                ++ (case fragment of
                        Just termId ->
                            [ termId ]

                        Nothing ->
                            []
                   )

        WarrantHelp ->
            [ "warrant-help" ]

        Actions ->
            [ "actions" ]

        OrganizerDashboard ->
            [ "organize", "dashboard" ]

        CampaignOverview id ->
            [ "organize", "campaigns", String.fromInt id ]

        Event campaignId eventId ->
            [ "organize", "campaigns", String.fromInt campaignId, "events", String.fromInt eventId ]

        ManageDetainerWarrants filters ->
            [ "organize", "detainer-warrants" ++ Search.detainerWarrantsQuery filters ]

        DetainerWarrantCreation maybeId ->
            [ "organize", "detainer-warrants", "edit" ]
                ++ (case maybeId of
                        Just id ->
                            [ id ]

                        Nothing ->
                            []
                   )

        ManagePlaintiffs filters ->
            [ "organize", "plaintiffs" ++ Search.plaintiffsQuery filters ]

        PlaintiffCreation maybeId ->
            [ "organize", "plaintiffs", "edit" ]
                ++ (case maybeId of
                        Just id ->
                            [ String.fromInt id ]

                        Nothing ->
                            []
                   )
