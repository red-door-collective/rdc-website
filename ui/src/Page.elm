module Page exposing (Page(..), view, viewHeader)

import Browser exposing (Document)
import Color
import Element exposing (Device, DeviceClass(..), Element, Orientation(..), alignLeft, alignRight, centerX, centerY, column, el, fill, height, link, maximum, minimum, px, row, spacing, text, width)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font exposing (center)
import Element.Input as Input
import Element.Region as Region
import FeatherIcons
import Html exposing (Html)
import LineChart exposing (dash)
import List
import Logo
import Palette
import Route
import Settings exposing (Settings)
import User exposing (Permissions(..))
import Viewer exposing (Viewer(..))
import Widget
import Widget.Icon exposing (Icon)


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
    | ManageDetainerWarrants
    | OrganizerDashboard
    | CampaignOverview Int
    | Event Int Int
    | DetainerWarrantCreation (Maybe String)


type alias NavBar msg =
    { hamburgerMenuOpen : Bool, onHamburgerMenuOpen : msg }


{-| Take a page's Html and frames it with a header and footer.

The caller provides the current user, so we can display in either
"signed in" (rendering username) or "signed out" mode.

isLoading is for determining whether we should show a loading spinner
in the header. (This comes up during slow page transitions.)

-}
viewHeader : NavBar msg -> Settings -> Page -> Element msg
viewHeader config settings page =
    navBar config settings page


view : Element msg -> { title : String, content : Element msg } -> Document msg
view header { title, content } =
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
            (column [ centerX, width fill, spacing 10 ]
                [ header, content, viewFooter ]
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
    link
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


navBar : NavBar msg -> Settings -> Page -> Element msg
navBar config settings page =
    column [ width fill ]
        [ case settings.device.class of
            Phone ->
                phoneBar config settings page

            Tablet ->
                tabletBar config settings page

            Desktop ->
                desktopBar config settings page

            BigDesktop ->
                desktopBar config settings page
        , viewBreadcrumbs page
        ]


links settings page =
    [ { url = Route.href Route.Trends, text = "Trends", isActive = page == Trends }
    , { url = Route.href Route.About
      , text = "About"
      , isActive = page == About
      }
    , { url = Route.href Route.Actions, text = "Actions", isActive = page == Actions }
    ]
        ++ (case settings.viewer of
                Just _ ->
                    [ { url = Route.href Route.WarrantHelp
                      , text = "Warrant Help"
                      , isActive = page == WarrantHelp
                      }
                    ]

                Nothing ->
                    [ { url = Route.href Route.Login, text = "Login", isActive = page == Login } ]
           )


viewHamburgerMenu config settings page =
    case settings.viewer of
        Just viewer ->
            [ hamburgerMenu config settings page ]

        Nothing ->
            []


horizontalBar config settings page =
    row
        [ centerY
        , height fill
        , width (fill |> Element.minimum 600)
        , Font.color Palette.white
        ]
        (List.intersperse roseSeparator (List.map navBarLink (links settings page) ++ viewHamburgerMenu config settings page))


menuLink { label, url, isActive } =
    link
        ([ height (px 40)
         , Font.center
         , width fill
         , Element.mouseOver [ Background.color Palette.redLight ]
         , Background.color Palette.sred
         , centerY
         , Font.size 18
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
        { label = row [] [ text label ]
        , url = url
        }


logoutLink =
    { url = Route.href Route.Logout, label = "Logout", isActive = False }


dashboard page =
    { url = Route.href Route.OrganizerDashboard, label = "Dashboard", isActive = page == OrganizerDashboard }


detainerWarrants page =
    { url = Route.href Route.ManageDetainerWarrants, label = "Detainer Warrants", isActive = page == ManageDetainerWarrants }


adminOptions settings page =
    [ dashboard page
    , detainerWarrants page
    ]


organizerOptions settings page =
    [ dashboard page
    , detainerWarrants page
    ]


defendantOptions settings page =
    []


accountOptions settings page =
    column []
        (List.map menuLink
            ((case settings.user of
                Just user ->
                    case User.permissions user of
                        Superuser ->
                            adminOptions settings page

                        Admin ->
                            adminOptions settings page

                        Organizer ->
                            organizerOptions settings page

                        Defendant ->
                            defendantOptions settings page

                Nothing ->
                    []
             )
                ++ [ logoutLink ]
            )
        )


menuIcon =
    FeatherIcons.menu
        |> Widget.Icon.elmFeather FeatherIcons.toHtml


menuIconStyle =
    { size = 20
    , color = Color.white
    }


hamburgerMenu config settings page =
    Widget.iconButton
        { elementButton =
            [ width (px 40), height (px 40), Background.color Palette.sred, centerX, Font.center ]
                ++ (if config.hamburgerMenuOpen then
                        [ Element.below (accountOptions settings page) ]

                    else
                        []
                   )
        , ifDisabled = []
        , ifActive = []
        , otherwise = []
        , content =
            { elementRow = [ centerX, Font.center ]
            , content =
                { text = { contentText = [] }
                , icon = { ifDisabled = menuIconStyle, ifActive = menuIconStyle, otherwise = menuIconStyle }
                }
            }
        }
        { text = "Toggle menu"
        , icon = menuIcon
        , onPress = Just config.onHamburgerMenuOpen
        }


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


verticalBar config settings page =
    column
        [ Font.color Palette.white, centerX, width (fill |> minimum 200 |> maximum 300) ]
        (List.map verticalTab (links settings page) ++ viewHamburgerMenu config settings page)


phoneBar config settings page =
    case settings.device.orientation of
        Portrait ->
            Element.column [ width fill, spacing 10 ]
                [ row [ centerX ] [ Logo.link ]
                , row [ width fill, centerX ] [ verticalBar config settings page ]
                ]

        Landscape ->
            tabletBar config settings page


tabletBar config settings page =
    column [ centerX, Element.spacing 10 ]
        [ row [ centerX ] [ Logo.link ]
        , horizontalBar config settings page
        ]


desktopBar config settings page =
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
        , horizontalBar config settings page
        ]



-- chevronRight : Icon msg


chevronRight =
    (FeatherIcons.chevronRight
        |> Widget.Icon.elmFeather FeatherIcons.toHtml
    )
        { size = 20, color = Color.red }


breadCrumbLink route name enabled =
    link
        (if enabled then
            [ Font.color Palette.sred ]

         else
            []
        )
        { url = Route.href route, label = text name }


dashboardLink =
    breadCrumbLink Route.OrganizerDashboard "Organizer Dashboard"


campaignLink id =
    breadCrumbLink (Route.CampaignOverview id) "Campaign"


eventLink campaignId id =
    breadCrumbLink (Route.Event campaignId id) "Event"


detainerWarrantLink maybeId =
    breadCrumbLink (Route.DetainerWarrantCreation maybeId) "Edit"


detainerWarrantsLink =
    breadCrumbLink Route.ManageDetainerWarrants "Manage Detainer Warrants"


viewBreadcrumbsHelp breadcrumbs =
    row [ spacing 10 ]
        (List.intersperse chevronRight breadcrumbs)


viewBreadcrumbs : Page -> Element msg
viewBreadcrumbs page =
    row [ width fill ]
        [ column [ centerX ]
            [ viewBreadcrumbsHelp
                (case page of
                    CampaignOverview campaignId ->
                        [ dashboardLink True, campaignLink campaignId False ]

                    Event campaignId eventId ->
                        [ dashboardLink True, campaignLink campaignId True, eventLink campaignId eventId False ]

                    DetainerWarrantCreation maybeId ->
                        [ detainerWarrantsLink True, detainerWarrantLink maybeId False ]

                    _ ->
                        []
                )
            ]
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
