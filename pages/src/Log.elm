module Log exposing (error, httpErrorMessage, reporting)

import Dict
import Http exposing (Error(..))
import Rollbar exposing (Rollbar)
import Runtime exposing (Runtime)
import Task
import Uuid exposing (Uuid)


httpErrorMessage : Http.Error -> String
httpErrorMessage httpError =
    case httpError of
        BadUrl url ->
            "Bad url: " ++ url

        Timeout ->
            "Network Timeout"

        NetworkError ->
            "Network Error"

        BadStatus statusCode ->
            "Bad HTTP Status: Code " ++ String.fromInt statusCode

        BadBody badBody ->
            "Bad HTTP Body: " ++ badBody


reporting : Runtime -> Rollbar
reporting { rollbarToken, environment, codeVersion } =
    Rollbar.scoped
        (Rollbar.token (Runtime.rollbarToken rollbarToken))
        (Rollbar.codeVersion (Runtime.codeVersion codeVersion))
        (Rollbar.environment (Runtime.environment environment))
        "eviction-tracker"


error : Rollbar -> (Result Error Uuid -> msg) -> String -> Cmd msg
error rollbar toMsg report =
    Task.attempt toMsg (rollbar.error report Dict.empty)
