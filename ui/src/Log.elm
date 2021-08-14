module Log exposing (error, httpErrorMessage, info, reporting)

import Dict
import Http exposing (Error(..))
import Rollbar exposing (Rollbar)
import Runtime exposing (Environment, RollbarToken)
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


reporting : RollbarToken -> Environment -> Rollbar
reporting token environment =
    Rollbar.scoped
        (Rollbar.token (Runtime.rollbarToken token))
        (Rollbar.codeVersion "0.0.1")
        (Rollbar.environment (Runtime.environment environment))
        "eviction-tracker"


info : Rollbar -> (Result Error Uuid -> msg) -> String -> Cmd msg
info rollbar toMsg report =
    Task.attempt toMsg (rollbar.info report Dict.empty)


error : Rollbar -> (Result Error Uuid -> msg) -> String -> Cmd msg
error rollbar toMsg report =
    Task.attempt toMsg (rollbar.error report Dict.empty)
