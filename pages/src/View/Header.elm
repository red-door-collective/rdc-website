module View.Header exposing (..)

import Css
import Element exposing (Element, alignRight, column, el, fill, height, link, padding, px, row, spacing, text, width)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Html.Attributes as Attrs
import Html.Styled exposing (..)
import Html.Styled.Attributes as Attr exposing (css)
import Html.Styled.Events
import Palette
import Path exposing (Path)
import RedDoor
import Route exposing (Route(..))
import Session exposing (Session)
import Svg.Styled exposing (path, svg)
import Svg.Styled.Attributes as SvgAttr
import Tailwind.Breakpoints as Bp
import Tailwind.Utilities as Tw


headerLink attrs isActive =
    link
        ([ Element.htmlAttribute <| Attrs.attribute "elm-pages:prefetch" "true"
         , Font.size 20
         ]
            ++ (if isActive then
                    [ Font.color Palette.white ]

                else
                    []
               )
            ++ attrs
        )


noPreloadLink attrs =
    link
        ([ Font.size 20
         ]
            ++ attrs
        )


sectionLink attrs =
    link ([ Element.htmlAttribute <| Attrs.attribute "elm-pages:prefetch" "true" ] ++ attrs)


view : Session -> msg -> { path : Path, route : Maybe Route } -> Element msg
view session toggleMobileMenuMsg page =
    row
        [ width fill
        , Font.size 28
        , spacing 10
        , padding 10
        , Background.color (Element.rgb255 255 87 87)
        , Border.widthEach { top = 0, bottom = 1, left = 0, right = 0 }
        , Element.htmlAttribute (Attrs.style "position" "sticky")
        , Element.htmlAttribute (Attrs.style "top" "0")
        , Element.htmlAttribute (Attrs.style "left" "0")
        , Element.htmlAttribute (Attrs.style "z-index" "1")
        ]
        (if String.startsWith "/admin" <| Path.toAbsolute page.path then
            [ sectionLink []
                { url = "/"
                , label =
                    el [ height (px 32), width (px 32) ] <|
                        Element.html <|
                            RedDoor.view RedDoor.default
                }
            , sectionLink []
                { url = "/admin/dashboard"
                , label = Element.text "RDC Admin"
                }
            , headerLink [ alignRight ]
                (page.route == Just Admin__Dashboard)
                { url = "/admin/dashboard"
                , label = Element.text "Dashboard"
                }
            , headerLink []
                (page.route == Just Admin__DetainerWarrants)
                { url = "/admin/detainer-warrants"
                , label = Element.text "Detainer Warrants"
                }
            , headerLink []
                (page.route == Just Admin__Plaintiffs)
                { url = "/admin/plaintiffs"
                , label = Element.text "Plaintiffs"
                }
            , noPreloadLink []
                { url = "/logout"
                , label = Element.text "Logout"
                }
            ]

         else
            [ sectionLink []
                { url = "/"
                , label = Element.text "Red Door Collective"
                }
            , headerLink [ alignRight ]
                (page.route == Just Index)
                { url = "/"
                , label = Element.text "Trends"
                }
            , headerLink [ alignRight ]
                (page.route == Just Blog)
                { url = "/blog"
                , label = Element.text "Blog"
                }
            , headerLink []
                (page.route == Just About)
                { url = "/about"
                , label = Element.text "About"
                }
            , headerLink []
                (page.route == Just Glossary)
                { url = "/glossary"
                , label = Element.text "Glossary"
                }
            , if Session.isLoggedIn session then
                headerLink []
                    False
                    { url = "/admin/dashboard"
                    , label = Element.text "Admin"
                    }

              else
                headerLink []
                    (page.route == Just Login)
                    { url = "/login"
                    , label = Element.text "Login"
                    }
            ]
        )


linkInner : Path -> String -> String -> Html msg
linkInner currentPagePath linkTo name =
    let
        isCurrentPath : Bool
        isCurrentPath =
            List.head (Path.toSegments currentPagePath) == Just linkTo
    in
    span
        [ css
            [ Tw.text_sm
            , Tw.p_2
            , if isCurrentPath then
                Css.batch
                    [ Tw.text_blue_600
                    , Css.hover
                        [ Tw.text_blue_700
                        ]
                    ]

              else
                Css.batch
                    [ Tw.text_gray_600
                    , Css.hover
                        [ Tw.text_gray_900
                        ]
                    ]
            ]
        ]
        [ Html.Styled.text name ]
