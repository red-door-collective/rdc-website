module Api.Endpoint exposing (Endpoint, campaign, campaigns, currentUser, detainerWarrantStats, detainerWarrants, event, evictionStats, login, logout, plaintiffAttorneyStats, request, users)

import Http
import Url.Builder exposing (QueryParameter, string)


{-| Http.request, except it takes an Endpoint instead of a Url.
-}
request :
    { body : Http.Body
    , expect : Http.Expect a
    , headers : List Http.Header
    , method : String
    , timeout : Maybe Float
    , url : Endpoint
    , tracker : Maybe String
    }
    -> Cmd a
request config =
    Http.request
        { body = config.body
        , expect = config.expect
        , headers = config.headers
        , method = config.method
        , timeout = config.timeout
        , url = unwrap config.url
        , tracker = config.tracker
        }



-- TYPES


{-| Get a URL to the RDC API.

This is not publicly exposed, because we want to make sure the only way to get one of these URLs is from this module.

-}
type Endpoint
    = Endpoint String


unwrap : Endpoint -> String
unwrap (Endpoint str) =
    str


url : List String -> List QueryParameter -> Endpoint
url paths queryParams =
    -- NOTE: Url.Builder takes care of percent-encoding special URL characters.
    -- See https://package.elm-lang.org/packages/elm/url/latest/Url#percentEncode
    Url.Builder.absolute
        ("api" :: "v1" :: paths)
        queryParams
        |> Endpoint



-- ENDPOINTS


login : Endpoint
login =
    url [ "accounts", "login" ] [ string "include_auth_token" "true" ]


logout : Endpoint
logout =
    url [ "accounts", "logout" ] []


detainerWarrants : Endpoint
detainerWarrants =
    url [ "detainer-warrants" ] []


campaigns : Endpoint
campaigns =
    url [ "campaigns" ] []


campaign : Int -> Endpoint
campaign id =
    url [ "campaigns", String.fromInt id ] []


event : Int -> Endpoint
event id =
    url [ "events", String.fromInt id ] []


users : Endpoint
users =
    url [ "users" ] []


currentUser : Endpoint
currentUser =
    url [ "current_user" ] []



-- STATS ENDPOINTS


detainerWarrantStats : Endpoint
detainerWarrantStats =
    url [ "rollup", "detainer-warrants" ] []


plaintiffAttorneyStats : Endpoint
plaintiffAttorneyStats =
    url [ "plaintiff-attorneys" ] []


evictionStats : Endpoint
evictionStats =
    url [ "plaintiffs" ] []
