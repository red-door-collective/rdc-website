module Page exposing (Page(..), view)

import Browser exposing (Document)
import Element exposing (Device, DeviceClass(..), Element, Orientation(..), alignLeft, alignRight, centerX, centerY, column, el, fill, height, maximum, minimum, px, row, spacing, width)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font exposing (center)
import Element.Region as Region
import Html exposing (Html)
import List
import Logo
import Palette
import Route
import Viewer exposing (Viewer(..))


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
    | Actions
    | Login


{-| Take a page's Html and frames it with a header and footer.

The caller provides the current user, so we can display in either
"signed in" (rendering username) or "signed out" mode.

isLoading is for determining whether we should show a loading spinner
in the header. (This comes up during slow page transitions.)

-}
view : Device -> Maybe Viewer -> Page -> { title : String, content : Element msg } -> Document msg
view device maybeViewer page { title, content } =
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
            (column [ centerX, width fill, Element.spacing 10 ]
                [ navBar device maybeViewer page
                , content
                , viewFooter
                ]
            )
        ]
    }


barColor =
    Element.rgb255 33 37 41


rose =
    "🌹"


roseSeparator =
    Element.el [ Background.color Palette.sred, Element.padding 10 ] (Element.text rose)


navBarLink { url, text, isActive } =
    Element.link
        ([ height (px 40)
         , Font.center
         , width (fill |> Element.minimum 150 |> Element.maximum 300)
         , Element.mouseOver [ Background.color Palette.redLight ]
         , Background.color Palette.sred
         , centerY
         , Font.size 20
         , Font.regular
         ]
            ++ (if isActive then
                    [ Border.widthEach { top = 0, bottom = 3, right = 0, left = 0 }
                    , Border.color Palette.grayLight
                    , Font.color Palette.grayLight
                    ]

                else
                    []
               )
        )
        { url = url
        , label = row [ centerX ] [ Element.text text ]
        }


navBar : Device -> Maybe Viewer -> Page -> Element msg
navBar device maybeViewer page =
    case device.class of
        Phone ->
            phoneBar device.orientation maybeViewer page

        Tablet ->
            tabletBar maybeViewer page

        Desktop ->
            desktopBar maybeViewer page

        BigDesktop ->
            desktopBar maybeViewer page


links maybeViewer page =
    [ { url = Route.href Route.Trends, text = "Trends", isActive = page == Trends }
    , { url = Route.href Route.About
      , text = "About"
      , isActive = page == About
      }
    , { url = Route.href Route.Actions, text = "Actions", isActive = page == Actions }
    ]
        ++ (case maybeViewer of
                Just _ ->
                    [ { url = Route.href Route.WarrantHelp
                      , text = "Warrant Help"
                      , isActive = page == WarrantHelp
                      }
                    , { url = Route.href Route.Logout, text = "Logout", isActive = False }
                    ]

                Nothing ->
                    [ { url = Route.href Route.Login, text = "Login", isActive = page == Login } ]
           )


horizontalBar maybeViewer page =
    Element.row
        [ centerY
        , height fill
        , width (fill |> Element.minimum 600)
        , Font.color Palette.white
        ]
        (List.intersperse roseSeparator (List.map navBarLink (links maybeViewer page)))


verticalTab { url, text, isActive } =
    Element.link
        ([ height (px 40)
         , Font.center
         , width (fill |> Element.minimum 200 |> Element.maximum 300)
         , Element.mouseOver [ Background.color Palette.redLight ]
         , Background.color Palette.sred
         , centerY
         , Font.size 20
         , Font.regular
         ]
            ++ (if isActive then
                    [ Border.width 1
                    , Border.color Palette.grayLight
                    , Font.color Palette.grayLight
                    ]

                else
                    []
               )
        )
        { url = url
        , label =
            if isActive then
                row [ Element.padding 10, width fill ] [ el [ alignLeft ] (Element.text rose), el [ centerX ] (Element.text text), el [ alignRight ] (Element.text rose) ]

            else
                row [ Element.padding 10, width fill ] [ el [ centerX ] (Element.text text) ]
        }


verticalBar maybeViewer page =
    column
        [ Font.color Palette.white, centerX, width (fill |> minimum 200 |> maximum 300) ]
        (List.map verticalTab (links maybeViewer page))


phoneBar orientation maybeViewer page =
    case orientation of
        Portrait ->
            Element.column [ width fill, spacing 10 ]
                [ row [ centerX ] [ Logo.link ]
                , row [ width fill, centerX ] [ verticalBar maybeViewer page ]
                ]

        Landscape ->
            tabletBar maybeViewer page


tabletBar maybeViewer page =
    column [ centerX, Element.spacing 10 ]
        [ row [ centerX ] [ Logo.link ]
        , horizontalBar maybeViewer page
        ]


desktopBar maybeViewer page =
    Element.row
        [ Border.color Palette.black
        , Element.padding 5
        , width (Element.fill |> Element.maximum 1400 |> Element.minimum 200)
        , centerX
        , centerY
        , height fill
        , Element.spacingXY 20 0
        ]
        [ Logo.link
        , horizontalBar maybeViewer page
        ]


viewFooter : Element msg
viewFooter =
    row [ Region.footer, centerX, Border.widthEach { top = 1, bottom = 0, left = 0, right = 0 }, Element.padding 10 ]
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
