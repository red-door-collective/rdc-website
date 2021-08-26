module Dimensions exposing (Attributes, Dimensions, init, isMobile)

import Element


init : Attributes -> Dimensions
init attributes =
    Dimensions attributes


type alias Attributes =
    { width : Float
    , height : Float
    , device : Element.Device
    }


type Dimensions
    = Dimensions Attributes


isMobile (Dimensions { width }) =
    width <= 1000
