module Viewer exposing (Viewer, cred, decoder, profile, staticDecoder, store, updateProfile)

{-| The logged-in user currently viewing this page. It stores enough data to
be able to render the menu bar (username and avatar), along with Cred so it's
impossible to have a Viewer if you aren't logged in.
-}

import Json.Decode as Decode exposing (Decoder)
import OptimizedDecoder
import Rest exposing (Cred)
import User exposing (User)



-- TYPES


type Viewer
    = Viewer Cred User


cred : Viewer -> Cred
cred (Viewer val user) =
    val


profile : Viewer -> User
profile (Viewer val user) =
    user


updateProfile : User -> Viewer -> Viewer
updateProfile user (Viewer val _) =
    Viewer val user



-- SERIALIZATION


decoder : Decoder (Cred -> User -> Viewer)
decoder =
    Decode.succeed Viewer


staticDecoder : OptimizedDecoder.Decoder (Cred -> User -> Viewer)
staticDecoder =
    OptimizedDecoder.succeed Viewer


store : Viewer -> Cmd msg
store (Viewer credVal user) =
    Rest.storeCredAndProfile credVal user
