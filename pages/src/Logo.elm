module Logo exposing (link, smallImage)

import Element exposing (Element, alignBottom, alignRight, centerX, column, height, paragraph, px, row, shrink, text, width)
import Element.Font as Font
import Pages.Url
import Palette
import Path
import RedDoor


smallImage =
    { url = [ "images", "red-door-logo.png" ] |> Path.join |> Pages.Url.fromPath
    , alt = "Red Door Collective logo"
    , dimensions = Just { width = 300, height = 300 }
    , mimeType = Just "png"
    }


name : Element msg
name =
    Element.textColumn [ width Element.shrink, alignBottom ]
        [ paragraph [ Font.color Palette.red ] [ text "Red" ]
        , paragraph [] [ text "Door" ]
        , paragraph [] [ text "Collective" ]
        ]


floatPx =
    px << round


link : Element msg
link =
    let
        dimensions =
            RedDoor.default
    in
    Element.link []
        { url = "/"
        , label =
            column [ width shrink ]
                [ row [ Element.inFront name, centerX, width (floatPx (dimensions.width + 55)), height (floatPx (45 + dimensions.height)) ]
                    [ Element.el [ alignRight, width (floatPx dimensions.width), height (floatPx dimensions.height) ]
                        (Element.html (RedDoor.view RedDoor.default))
                    ]
                ]
        }
