module Loader exposing (horizontal)

import Color
import Svg exposing (Svg, animate, circle, svg)
import Svg.Attributes exposing (attributeName, begin, cx, cy, dur, enableBackground, fill, height, r, repeatCount, stroke, values, version, viewBox, width, x, xmlSpace, y)


horizontal : Color.Color -> Svg msg
horizontal color =
    let
        fillColor =
            Color.toCssString color
    in
    svg [ width "100px", height "50px", version "1.1", x "0px", y "0px", viewBox "0 0 100 50", enableBackground "new 0 0 0 0", xmlSpace "preserve" ]
        [ circle [ fill fillColor, stroke "none", cx "30", cy "25", r "6" ]
            [ animate [ attributeName "opacity", dur "1s", values "0;1;0", repeatCount "indefinite", begin "0.1" ] []
            ]
        , circle [ fill fillColor, stroke "none", cx "50", cy "25", r "6" ]
            [ animate [ attributeName "opacity", dur "1s", values "0;1;0", repeatCount "indefinite", begin "0.2" ] []
            ]
        , circle [ fill fillColor, stroke "none", cx "70", cy "25", r "6" ]
            [ animate [ attributeName "opacity", dur "1s", values "0;1;0", repeatCount "indefinite", begin "0.3" ]
                []
            ]
        ]
