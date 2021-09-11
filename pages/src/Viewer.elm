module Viewer exposing (Viewer, cred, decoder, staticDecoder, store)

{-| The logged-in user currently viewing this page. It stores enough data to
be able to render the menu bar (username and avatar), along with Cred so it's
impossible to have a Viewer if you aren't logged in.
-}

import Email exposing (Email)
import Json.Decode as Decode exposing (Decoder)
import Json.Decode.Pipeline exposing (custom, required)
import Json.Encode as Encode exposing (Value)
import OptimizedDecoder
import Rest exposing (Cred)



-- TYPES


type Viewer
    = Viewer Cred


cred : Viewer -> Cred
cred (Viewer val) =
    val



-- SERIALIZATION


decoder : Decoder (Cred -> Viewer)
decoder =
    Decode.succeed Viewer


staticDecoder : OptimizedDecoder.Decoder (Cred -> Viewer)
staticDecoder =
    OptimizedDecoder.succeed Viewer


store : Viewer -> Cmd msg
store (Viewer credVal) =
    Rest.storeCred credVal
