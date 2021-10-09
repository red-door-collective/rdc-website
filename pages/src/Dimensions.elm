module Dimensions exposing (Dimensions)

import Element


type alias Attributes =
    { width : Float
    , height : Float
    , device : Element.Device
    }


type Dimensions
    = Dimensions Attributes
