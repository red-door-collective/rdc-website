module Profile exposing (can, map)

import RemoteData exposing (RemoteData(..))
import Rest exposing (HttpError)
import User exposing (User)


can : (User -> Bool) -> Maybe User -> Bool
can fn profile =
    profile
        |> Maybe.map fn
        |> Maybe.withDefault False


map : (User -> b) -> b -> Maybe User -> b
map fn default profile =
    profile
        |> Maybe.map fn
        |> Maybe.withDefault default
