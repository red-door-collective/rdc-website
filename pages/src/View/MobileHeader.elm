module View.MobileHeader exposing (view)

import Element exposing (Element, column, fill, link, padding, spacing, width)
import Element.Background as Background
import Element.Font as Font
import Html.Attributes as Attrs
import Http
import Path exposing (Path)
import Profile
import RemoteData exposing (RemoteData(..))
import Rest
import Route exposing (Route(..))
import Session exposing (Session)
import UI.Palette as Palette
import UI.Utils.Element exposing (renderIf)
import User exposing (User)


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


view : Maybe User -> Session -> { path : Path, route : Maybe Route } -> Element msg
view profile session page =
    let
        canViewCourtData =
            Profile.can User.canViewCourtData profile

        canViewDefendantInformation =
            Profile.can User.canViewDefendantInformation profile

        isAdmin =
            List.member "admin" <| Path.toSegments page.path
    in
    case ( profile, isAdmin ) of
        ( Nothing, True ) ->
            Element.none

        _ ->
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
                    [ renderIf canViewCourtData <|
                        headerLink []
                            (page.route == Just Admin__DetainerWarrants)
                            { url = "/admin/detainer-warrants"
                            , label = Element.text "Detainer Warrants"
                            }
                    , renderIf canViewCourtData <|
                        headerLink []
                            (page.route == Just Admin__Judgments)
                            { url = "/admin/judgments"
                            , label = Element.text "Judgments"
                            }
                    , headerLink []
                        (page.route == Just Admin__Plaintiffs)
                        { url = "/admin/plaintiffs"
                        , label = Element.text "Plaintiffs"
                        }
                    , headerLink []
                        (page.route == Just Admin__Attorneys)
                        { url = "/admin/attorneys"
                        , label = Element.text "Attorneys"
                        }
                    , headerLink []
                        (page.route == Just Admin__Judges)
                        { url = "/admin/judges"
                        , label = Element.text "Judges"
                        }
                    , if canViewDefendantInformation then
                        headerLink []
                            (page.route == Just Admin__Defendants)
                            { url = "/admin/defendants"
                            , label = Element.text "Defendants"
                            }

                      else
                        Element.none
                    , noPreloadLink []
                        { url = "/logout"
                        , label = Element.text "Logout"
                        }
                    ]

                 else
                    [ headerLink []
                        (page.route == Just Index)
                        { url = "/"
                        , label = Element.text "About"
                        }
                    , headerLink []
                        (page.route == Just Resources)
                        { url = "/resources"
                        , label = Element.text "Resources"
                        }
                    , headerLink []
                        (page.route == Just Education)
                        { url = "/education"
                        , label = Element.text "Education"
                        }
                    , headerLink []
                        (page.route == Just Blog)
                        { url = "/blog"
                        , label = Element.text "Blog"
                        }
                    , headerLink []
                        (page.route == Just Events)
                        { url = "/events"
                        , label = Element.text "Events"
                        }
                    , headerLink []
                        (page.route == Just Trends)
                        { url = "/trends"
                        , label = Element.text "Trends"
                        }
                    , headerLink []
                        (page.route == Just Glossary)
                        { url = "/glossary"
                        , label = Element.text "Glossary"
                        }
                    , if Session.isLoggedIn session then
                        headerLink []
                            False
                            { url = Profile.map User.databaseHomeUrl "/admin/plaintiffs" profile
                            , label =
                                Element.text
                                    (if canViewDefendantInformation then
                                        "Admin"

                                     else
                                        "Database"
                                    )
                            }

                      else
                        headerLink []
                            (page.route == Just Login)
                            { url = "/login"
                            , label = Element.text "Login"
                            }
                    ]
                )
