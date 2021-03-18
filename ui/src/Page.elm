module Page exposing (Page(..), view)

import Browser exposing (Document)
import Color
import Element exposing (Element, fill)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Region as Region
import Html exposing (Html)
import Palette
import Route
import TypedSvg exposing (circle, g, rect, style, svg, text_)
import TypedSvg.Attributes as Attr exposing (class, dy, stroke, textAnchor, transform, viewBox)
import TypedSvg.Attributes.InPx exposing (cx, cy, height, r, width, x, y)
import TypedSvg.Core exposing (text)
import TypedSvg.Types exposing (AnchorAlignment(..), Paint(..), Transform(..), em)
import Viewer exposing (Viewer)


{-| Determines which navbar link (if any) will be rendered as active.

Note that we don't enumerate every page here, because the navbar doesn't
have links for every page. Anything that's not part of the navbar falls
under Other.

-}
type Page
    = Other
    | Trends
    | About
    | WarrantHelp


{-| Take a page's Html and frames it with a header and footer.

The caller provides the current user, so we can display in either
"signed in" (rendering username) or "signed out" mode.

isLoading is for determining whether we should show a loading spinner
in the header. (This comes up during slow page transitions.)

-}
view : Maybe Viewer -> Page -> { title : String, content : Element msg } -> Document msg
view maybeViewer page { title, content } =
    { title = title ++ " - RDC"
    , body =
        [ Element.layoutWith
            { options =
                [ Element.focusStyle
                    { borderColor = Just Palette.grayLight
                    , backgroundColor = Nothing
                    , shadow =
                        Just
                            { color = Palette.gray
                            , offset = ( 0, 0 )
                            , blur = 3
                            , size = 3
                            }
                    }
                ]
            }
            [ Font.family
                [ Font.typeface "Lato"
                , Font.sansSerif
                ]
            ]
            (Element.column [ Element.centerX, Element.width fill ]
                [ navBar page
                , content
                , viewFooter
                ]
            )
        ]
    }


redDoorWidth =
    50


redDoorHeight =
    75


redDoorFrame =
    10


redDoor : Element msg
redDoor =
    Element.column [ Element.width Element.shrink ]
        [ Element.row [ Element.inFront logo, Element.centerX, Element.width (Element.px (redDoorWidth + 55)), Element.height (Element.px (45 + redDoorHeight)) ]
            [ Element.el [ Element.alignRight, Element.width (Element.px redDoorWidth), Element.height (Element.px redDoorHeight) ]
                (Element.html
                    (svg [ viewBox 0 0 redDoorWidth redDoorHeight ]
                        [ rect [ x 0, y 0, width redDoorWidth, height redDoorHeight, Attr.fill <| Paint Color.red ] []
                        , g []
                            [ rect [ x 13, y 17, Attr.fill <| Paint Color.black, width redDoorFrame, height redDoorFrame ]
                                []
                            , rect [ x 27, y 17, Attr.fill <| Paint Color.black, width redDoorFrame, height redDoorFrame ]
                                []
                            , rect [ x 13, y 32, Attr.fill <| Paint Color.black, width redDoorFrame, height redDoorFrame ]
                                []
                            , rect [ x 27, y 32, Attr.fill <| Paint Color.black, width redDoorFrame, height redDoorFrame ]
                                []
                            ]
                        , g []
                            [ circle [ cx 42, cy 50, Attr.fill <| Paint Color.black, r 3 ] [] ]
                        ]
                    )
                )
            ]
        ]


logo : Element msg
logo =
    Element.textColumn [ Element.width Element.shrink, Element.alignBottom ]
        [ Element.paragraph [ Font.color Palette.red ] [ Element.text "Red" ]
        , Element.paragraph [] [ Element.text "Door" ]
        , Element.paragraph [] [ Element.text "Collective" ]
        ]


navBarLink { url, text, isActive } =
    Element.link
        ([ Element.height fill
         , Font.center
         , Element.width (Element.px 200)
         , Element.mouseOver [ Background.color Palette.redLight ]
         , Element.centerY
         , Element.centerX
         , Font.center
         , Font.size 20
         , Font.regular
         ]
            ++ (if isActive then
                    [ Border.widthEach { top = 0, bottom = 0, left = 1, right = 1 }, Border.color Palette.white ]

                else
                    []
               )
        )
        { url = url
        , label = Element.row [ Element.centerX ] [ Element.text text ]
        }


navBar : Page -> Element msg
navBar page =
    Element.wrappedRow
        [ Border.color Palette.black

        -- , Border.widthEach { bottom = 2, top = 0, left = 0, right = 0 }
        , Element.padding 5
        , Element.width (Element.fill |> Element.maximum 1200 |> Element.minimum 400)
        , Element.centerX
        , Element.centerY
        , Element.spacing 50
        ]
        [ redDoor
        , Element.column [ Element.width fill, Element.height (Element.px 40), Element.centerY ]
            [ Element.row
                [ Element.centerY
                , Element.height fill
                , Element.spaceEvenly
                , Element.width (fill |> Element.maximum 800 |> Element.minimum 400)
                , Background.color Palette.sred
                , Font.color Palette.white
                ]
                [ navBarLink
                    { url = Route.href Route.About
                    , text = "About"
                    , isActive = page == About
                    }
                , navBarLink
                    { url = Route.href Route.WarrantHelp
                    , text = "Warrant Help"
                    , isActive = page == WarrantHelp
                    }
                , navBarLink { url = Route.href Route.Trends, text = "Trends", isActive = page == Trends }
                , navBarLink { url = Route.href Route.Trends, text = "Actions", isActive = False }
                ]
            ]
        ]


viewFooter : Element msg
viewFooter =
    Element.row [ Region.footer, Element.centerX, Border.widthEach { top = 1, bottom = 0, left = 0, right = 0 }, Element.padding 10 ]
        [ Element.textColumn [ Font.center, Font.size 20, Element.spacing 10 ]
            [ Element.el [ Font.medium ] (Element.text "Data collected and provided for free to the people of Davidson County.")
            , Element.paragraph [ Font.color Palette.red ]
                [ Element.link []
                    { url = "https://midtndsa.org/rdc/"
                    , label = Element.text "Red Door Collective"
                    }
                , Element.text " © 2021"
                ]
            ]
        ]
