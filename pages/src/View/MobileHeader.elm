module View.MobileHeader exposing (view)

import Element exposing (Element, column, fill, link, padding, spacing, width)
import Element.Background as Background
import Element.Font as Font
import Html.Attributes as Attrs
import Path exposing (Path)
import Route exposing (Route(..))
import Session exposing (Session)
import UI.Palette as Palette


headerLink attrs isActive =
    link
        ([ Element.htmlAttribute <| Attrs.attribute "elm-pages:prefetch" "true"
         , Font.size 20
         , Element.htmlAttribute (Attrs.class "responsive-mobile")
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
         ]
            ++ attrs
        )


view : Session -> { path : Path, route : Maybe Route } -> Element msg
view session page =
    column
        [ width fill
        , Font.size 28
        , spacing 10
        , padding 10
        , Background.color (Element.rgb255 255 87 87)
        , Element.htmlAttribute (Attrs.class "responsive-mobile")

        -- , Border.widthEach { top = 0, bottom = 1, left = 0, right = 0 }
        ]
        (if String.startsWith "/admin" <| Path.toAbsolute page.path then
            [ headerLink [ ]
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
            [ headerLink []
                (page.route == Just Index)
                { url = "/"
                , label = Element.text "Trends"
                }
            , headerLink []
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
                    { url = "/admin/detainer-warrants"
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
