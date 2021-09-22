module Progress exposing (Config, Tracking, bar)

import Svg exposing (Svg, rect, svg)
import Svg.Attributes exposing (fill, height, stroke, width, x, y)


type alias Tracking =
    { current : Int
    , total : Int
    , errored : Int
    }


type alias Config =
    { width : Float
    , height : Float
    , tracking : Tracking
    }


progress : Tracking -> Float
progress tracking =
    toFloat (tracking.current + tracking.errored) / toFloat tracking.total


widthFromTracking : Float -> Config -> Float
widthFromTracking percent config =
    percent * config.width


bar : Config -> Svg msg
bar config =
    let
        percent =
            progress config.tracking

        widthInPx =
            widthFromTracking percent config
    in
    svg
        [ width (String.fromFloat config.width)
        , height (String.fromFloat config.height)
        ]
        [ rect
            [ width (String.fromFloat config.width)
            , height (String.fromFloat config.height)
            , fill "#666666"
            ]
            []
        , rect
            [ width (String.fromFloat widthInPx)
            , height (String.fromFloat config.height)
            , fill "#FF5757"
            ]
            []
        , Svg.text_
            [ x "20"
            , y "20"
            , stroke "#FFFFFF"
            , fill "#FFFFFF"
            ]
            [ Svg.text (String.fromInt (Basics.round (100 * percent)) ++ "%") ]
        ]
