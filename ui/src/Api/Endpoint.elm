module Api.Endpoint exposing (Endpoint, detainerWarrantStats, detainerWarrants, evictionStats, plantiffAttorneyStats, request)

import Http
import Url.Builder exposing (QueryParameter)


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
        ("api" :: paths)
        queryParams
        |> Endpoint



-- ENDPOINTS


detainerWarrants : Endpoint
detainerWarrants =
    url [ "detainer-warrants" ] []



-- STATS ENDPOINTS


detainerWarrantStats : Endpoint
detainerWarrantStats =
    url [ "rollup", "detainer-warrants" ] []


plantiffAttorneyStats : Endpoint
plantiffAttorneyStats =
    url [ "rollup", "plantiff-attorneys" ] []


evictionStats : Endpoint
evictionStats =
    url [ "rollup", "plantiffs" ] []
