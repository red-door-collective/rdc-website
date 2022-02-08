module Profile exposing (can, map)

import RemoteData exposing (RemoteData(..))
import Rest exposing (HttpError)
import User exposing (User)


can : (User -> Bool) -> Maybe (RemoteData HttpError User) -> Bool
can fn profile =
    profile
        |> Maybe.map
            (\userData ->
                userData
                    |> RemoteData.map fn
                    |> RemoteData.withDefault False
            )
        |> Maybe.withDefault False


map : (User -> b) -> b -> Maybe (RemoteData HttpError User) -> b
map fn default profile =
    profile
        |> Maybe.map
            (\userData ->
                userData
                    |> RemoteData.map fn
                    |> RemoteData.withDefault default
            )
        |> Maybe.withDefault default
