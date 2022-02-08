module Log exposing (error, httpErrorMessage, reporting)

import Dict
import Http
import Rest exposing (HttpError(..))
import Rollbar exposing (Rollbar)
import Runtime exposing (Runtime)
import Task
import Uuid exposing (Uuid)


httpErrorMessage : Rest.HttpError -> String
httpErrorMessage httpError =
    case httpError of
        BadUrl url ->
            "Bad url: " ++ url

        Timeout ->
            "Network Timeout"

        NetworkError ->
            "Network Error"

        BadStatus metadata _ ->
            "Bad HTTP Status: Code " ++ String.fromInt metadata.statusCode

        BadBody _ errors ->
            "Bad HTTP Body: " ++ (String.join "\n" <| List.map Rest.errorToString errors)


reporting : Runtime -> Rollbar
reporting { rollbarToken, environment, codeVersion } =
    Rollbar.scoped
        (Rollbar.token (Runtime.rollbarToken rollbarToken))
        (Rollbar.codeVersion (Runtime.codeVersion codeVersion))
        (Rollbar.environment (Runtime.environment environment))
        "eviction-tracker"


error : Rollbar -> (Result Http.Error Uuid -> msg) -> String -> Cmd msg
error rollbar toMsg report =
    Task.attempt toMsg (rollbar.error report Dict.empty)
