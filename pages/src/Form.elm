module Form exposing (Problem(..), viewProblem)

import Element exposing (Element, column, text)
import Rest exposing (Error)


{-| Recording validation problems on a per-field basis facilitates displaying
them inline next to the field where the error occurred.
-}
type Problem field
    = InvalidEntry field String
    | ServerError (List Error)


viewProblem : Problem field -> Element msg
viewProblem problem =
    let
        errorMessage =
            case problem of
                InvalidEntry _ str ->
                    str

                ServerError err ->
                    String.join "\n" (List.map Rest.errorToString err)
    in
    column [] [ text errorMessage ]
