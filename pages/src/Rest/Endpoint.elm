module Rest.Endpoint exposing (Endpoint, attorney, attorneys, attorneysSearch, courtrooms, currentUser, defendant, defendants, defendantsSearch, detainerWarrant, detainerWarrantsExport, detainerWarrantsSearch, judge, judges, judgesSearch, judgment, judgments, judgmentsSearch, login, logout, plaintiff, plaintiffs, plaintiffsSearch, request, toQueryArgs, user)

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


url : String -> List String -> List QueryParameter -> Endpoint
url domain paths queryParams =
    -- NOTE: Url.Builder takes care of percent-encoding special URL characters.
    -- See https://package.elm-lang.org/packages/elm/url/latest/Url#percentEncode
    Url.Builder.crossOrigin
        domain
        ("api" :: "v1" :: paths)
        queryParams
        |> Endpoint



-- ENDPOINTS


login : String -> Endpoint
login domain =
    url domain [ "accounts", "login" ] [ string "include_auth_token" "true" ]


logout : String -> Endpoint
logout domain =
    url domain [ "accounts", "logout" ] []


type alias Param =
    ( String, String )


toQueryArgs : List Param -> List QueryParameter
toQueryArgs params =
    List.map (\( k, v ) -> string k v) params


detainerWarrantsSearch : String -> List Param -> Endpoint
detainerWarrantsSearch domain params =
    url domain [ "detainer-warrants", "" ] (toQueryArgs params)


judgmentsSearch : String -> List Param -> Endpoint
judgmentsSearch domain params =
    url domain [ "judgments", "" ] (toQueryArgs params)


detainerWarrantsExport : String -> Endpoint
detainerWarrantsExport domain =
    Url.Builder.crossOrigin
        domain
        [ "scheduler", "jobs", "export", "run" ]
        []
        |> Endpoint


detainerWarrant : String -> String -> Endpoint
detainerWarrant domain id =
    url domain [ "detainer-warrants", id ] []


plaintiffs : String -> List Param -> Endpoint
plaintiffs domain =
    url domain [ "plaintiffs", "" ] << toQueryArgs


plaintiff : String -> Int -> Endpoint
plaintiff domain id =
    url domain [ "plaintiffs", String.fromInt id ] []


plaintiffsSearch : String -> List Param -> Endpoint
plaintiffsSearch domain params =
    url domain [ "plaintiffs", "" ] (toQueryArgs params)


attorneys : String -> List Param -> Endpoint
attorneys domain =
    url domain [ "attorneys", "" ] << toQueryArgs


attorneysSearch : String -> List Param -> Endpoint
attorneysSearch domain params =
    url domain [ "attorneys", "" ] (toQueryArgs params)


attorney : String -> Int -> Endpoint
attorney domain id =
    url domain [ "attorneys", String.fromInt id ] []


judge : String -> Int -> Endpoint
judge domain id =
    url domain [ "judges", String.fromInt id ] []


judges : String -> List Param -> Endpoint
judges domain =
    url domain [ "judges", "" ] << toQueryArgs


judgesSearch : String -> List Param -> Endpoint
judgesSearch domain params =
    url domain [ "judges", "" ] (toQueryArgs params)


defendants : String -> List Param -> Endpoint
defendants domain =
    url domain [ "defendants", "" ] << toQueryArgs


defendantsSearch : String -> List Param -> Endpoint
defendantsSearch domain params =
    url domain [ "defendants", "" ] (toQueryArgs params)


defendant : String -> Int -> Endpoint
defendant domain id =
    url domain [ "defendants", String.fromInt id ] []


judgments : String -> List Param -> Endpoint
judgments domain =
    url domain [ "judgments", "" ] << toQueryArgs


judgment : String -> Int -> Endpoint
judgment domain id =
    url domain [ "judgments", String.fromInt id ] []


courtrooms : String -> List Param -> Endpoint
courtrooms domain =
    url domain [ "courtrooms", "" ] << toQueryArgs


currentUser : String -> Endpoint
currentUser domain =
    url domain [ "current-user" ] []


user : String -> Int -> Endpoint
user domain id =
    url domain [ "users", String.fromInt id ] []
