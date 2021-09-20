module Design exposing (..)

import Element exposing (Attribute, Element, fill, height, padding, paddingXY, px, spacing, spacingXY, width)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Input as Input
import FeatherIcons
import Palette


button : List (Element.Attr () msg) -> { onPress : Maybe msg, label : Element msg } -> Element msg
button attrs config =
    Input.button
        ([ Background.color Palette.sred
         , Font.color Palette.white
         , Font.size 20
         , padding 10
         , Border.rounded 3
         ]
            ++ attrs
        )
        config


link : List (Attribute msg) -> { url : String, label : Element msg } -> Element msg
link attrs =
    Element.newTabLink
        ([ Font.color Palette.blue
         , Border.widthEach { bottom = 1, left = 0, top = 0, right = 0 }
         , Border.color <| Element.rgba 0 0 0 0
         , Element.mouseOver [ Border.color <| Palette.blue ]
         ]
            ++ attrs
        )


externalLink : List (Attribute msg) -> { url : String, label : Element msg, hovering : Bool, fontSize : Int } -> Element msg
externalLink attrs { url, label, hovering, fontSize } =
    Element.newTabLink
        ([ Font.color Palette.blue
         , Border.widthEach { bottom = 1, left = 0, top = 0, right = 0 }
         , Border.color <| Element.rgba 0 0 0 0
         , Element.mouseOver [ Border.color <| Palette.blue ]
         ]
            ++ attrs
        )
        { url = url
        , label =
            Element.paragraph [ Font.size fontSize ]
                [ label
                , if hovering then
                    Element.el [ Element.width (px 4), height (px 4), paddingXY 5 2, Element.alignBottom ]
                        (Element.html
                            (FeatherIcons.externalLink
                                |> FeatherIcons.toHtml []
                            )
                        )

                  else
                    Element.none
                ]
        }


headerLink : List (Attribute msg) -> { url : String, label : Element msg } -> Element msg
headerLink attrs =
    Element.link
        ([ Font.color Palette.black
         , Border.widthEach { bottom = 1, left = 0, top = 0, right = 0 }
         , Border.color <| Element.rgba 0 0 0 0
         , Element.mouseOver [ Border.color <| Palette.black ]
         ]
            ++ attrs
        )
