module Api.Endpoint exposing (Endpoint, amountAwardedHistory, attorney, attorneys, campaign, campaigns, courtroom, courtrooms, currentUser, defendant, defendants, detainerWarrant, detainerWarrantStats, detainerWarrants, detainerWarrantsSearch, event, evictionStats, judge, judgement, judgements, judges, login, logout, plaintiff, plaintiffAttorneyStats, plaintiffs, plaintiffsSearch, request, toQueryArgs, users)

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


type alias Param =
    ( String, String )


toQueryArgs : List Param -> List QueryParameter
toQueryArgs params =
    List.map (\( k, v ) -> string k v) params


detainerWarrantsSearch : List Param -> Endpoint
detainerWarrantsSearch params =
    url [ "detainer-warrants" ] (toQueryArgs params)


detainerWarrant : String -> Endpoint
detainerWarrant id =
    url [ "detainer-warrants", id ] []


plaintiffs : List Param -> Endpoint
plaintiffs =
    url [ "plaintiffs", "" ] << toQueryArgs


plaintiff : Int -> Endpoint
plaintiff id =
    url [ "plaintiffs", String.fromInt id ] []


plaintiffsSearch : List Param -> Endpoint
plaintiffsSearch params =
    url [ "plaintiffs" ] (toQueryArgs params)


attorneys : List Param -> Endpoint
attorneys =
    url [ "attorneys", "" ] << toQueryArgs


attorney : Int -> Endpoint
attorney id =
    url [ "attorneys", String.fromInt id ] []


judges : List Param -> Endpoint
judges =
    url [ "judges", "" ] << toQueryArgs


judge : Int -> Endpoint
judge id =
    url [ "judges", String.fromInt id ] []


defendants : List Param -> Endpoint
defendants =
    url [ "defendants", "" ] << toQueryArgs


defendant : Int -> Endpoint
defendant id =
    url [ "defendants", String.fromInt id ] []


judgements : List Param -> Endpoint
judgements =
    url [ "judgements", "" ] << toQueryArgs


judgement : Int -> Endpoint
judgement id =
    url [ "judgements", String.fromInt id ] []


courtrooms : List Param -> Endpoint
courtrooms =
    url [ "courtrooms", "" ] << toQueryArgs


courtroom : Int -> Endpoint
courtroom id =
    url [ "courtrooms", String.fromInt id ] []


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


amountAwardedHistory : Endpoint
amountAwardedHistory =
    url [ "rollup", "amount-awarded", "history" ] []


plaintiffAttorneyStats : Endpoint
plaintiffAttorneyStats =
    url [ "plaintiff-attorneys" ] []


evictionStats : Endpoint
evictionStats =
    url [ "plaintiffs" ] []
