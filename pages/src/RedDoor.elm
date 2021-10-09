module RedDoor exposing (Dimensions, default, view)

import Color
import Svg exposing (Svg)
import TypedSvg exposing (circle, g, rect, svg)
import TypedSvg.Attributes exposing (fill, viewBox)
import TypedSvg.Attributes.InPx exposing (cx, cy, height, r, width, x, y)
import TypedSvg.Types exposing (Paint(..))


type alias Dimensions =
    { width : Float, height : Float, frame : Float }


default : Dimensions
default =
    { width = 50, height = 75, frame = 10 }


view : Dimensions -> Svg msg
view dimensions =
    let
        window attrs =
            rect ([ fill <| Paint Color.black, width dimensions.frame, height dimensions.frame ] ++ attrs) []

        doorknob =
            g []
                [ circle [ cx 42, cy 50, fill <| Paint Color.black, r 3 ] [] ]
    in
    svg [ viewBox 0 0 dimensions.width dimensions.height ]
        [ rect [ x 0, y 0, width dimensions.width, height dimensions.height, fill <| Paint Color.red ] []
        , g []
            [ window [ x 13, y 17 ]
            , window [ x 27, y 17 ]
            , window [ x 13, y 32 ]
            , window [ x 27, y 32 ]
            ]
        , doorknob
        ]
