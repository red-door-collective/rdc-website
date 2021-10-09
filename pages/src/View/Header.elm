module View.Header exposing (..)

import Element exposing (Element, alignRight, centerY, column, el, fill, height, link, padding, paddingXY, px, row, spacing, width)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Input as Input
import FeatherIcons
import Html.Attributes as Attrs
import Path exposing (Path)
import RedDoor
import Route exposing (Route(..))
import Session exposing (Session)
import UI.Palette as Palette
import View.MobileHeader


headerLink attrs isActive =
    link
        ([ Element.htmlAttribute <| Attrs.attribute "elm-pages:prefetch" "true"
         , Font.size 20
         , Element.htmlAttribute (Attrs.class "responsive-desktop")
         ]
            ++ (if isActive then
                    [ Palette.toFontColor Palette.genericWhite ]

                else
                    []
               )
            ++ attrs
        )


noPreloadLink attrs =
    link
        ([ Font.size 20
         , Element.htmlAttribute (Attrs.class "responsive-desktop")
         ]
            ++ attrs
        )


sectionLink attrs =
    link
        ([ Element.htmlAttribute <| Attrs.attribute "elm-pages:prefetch" "true"
         , Font.size 22
         ]
            ++ attrs
        )


mobileMenuButton : Session -> msg -> { path : Path, route : Maybe Route } -> Element msg
mobileMenuButton session toggleMsg page =
    Input.button
        [ Element.htmlAttribute (Attrs.class "responsive-mobile")
        ]
        { onPress = Just toggleMsg
        , label =
            Element.el
                [ Element.width (px 40)
                , height (px 40)
                , paddingXY 8 8
                , centerY
                , Element.alignBottom
                ]
                (Element.html
                    (FeatherIcons.moreVertical
                        |> FeatherIcons.toHtml []
                    )
                )
        }


view : Bool -> Session -> msg -> { path : Path, route : Maybe Route } -> Element msg
view showMobileMenu session toggleMobileMenuMsg page =
    column
        [ width fill
        , Element.htmlAttribute (Attrs.style "position" "sticky")
        , Element.htmlAttribute (Attrs.style "top" "0")
        , Element.htmlAttribute (Attrs.style "left" "0")
        , Element.htmlAttribute (Attrs.style "z-index" "1")
        ]
        [ row
            [ width fill
            , Font.size 28
            , spacing 10
            , padding 10
            , Background.color (Element.rgb255 255 87 87)
            , Border.widthEach { top = 0, bottom = 1, left = 0, right = 0 }
            ]
            ((if String.startsWith "/admin" <| Path.toAbsolute page.path then
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
                    { url = "/glossary/"
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
                ++ [ mobileMenuButton session toggleMobileMenuMsg page ]
            )
        , if showMobileMenu then
            View.MobileHeader.view session page

          else
            Element.none
        ]
