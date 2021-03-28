module Settings exposing (Settings)

import Element exposing (Device)
import User exposing (User)
import Viewer exposing (Viewer)


type alias Settings =
    { device : Device
    , user : Maybe User
    , viewer : Maybe Viewer
    }
