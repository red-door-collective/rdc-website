module Main exposing (main)

import Api
import Browser exposing (Document)
import Browser.Events
import Browser.Navigation as Nav
import Element exposing (Device, DeviceClass(..), Element, Orientation(..))
import Html
import Http
import Json.Decode as Decode exposing (Decoder, Value, list)
import Json.Decode.Pipeline exposing (optional, required)
import Page exposing (Page)
import Page.About as About
import Page.Actions as Actions
import Page.Blank as Blank
import Page.Glossary as Glossary
import Page.Login as Login
import Page.NotFound as NotFound
import Page.Organize.CampaignOverview as CampaignOverview
import Page.Organize.Dashboard as OrganizerDashboard
import Page.Organize.DetainerWarrantCreation as DetainerWarrantCreation
import Page.Organize.DetainerWarrants as ManageDetainerWarrants
import Page.Organize.Event as Event
import Page.Trends as Trends
import Page.WarrantHelp as WarrantHelp
import Route exposing (Route)
import Runtime exposing (Runtime)
import Session exposing (Session)
import Url exposing (Url)
import User exposing (User)
import Viewer exposing (Viewer)


type CurrentPage
    = Redirect Session
    | NotFound Session
    | Login Login.Model
    | Trends Trends.Model
    | WarrantHelp WarrantHelp.Model
    | About About.Model
    | Actions Actions.Model
    | Glossary Glossary.Model
    | OrganizerDashboard OrganizerDashboard.Model
    | CampaignOverview Int CampaignOverview.Model
    | Event Int Int Event.Model
    | ManageDetainerWarrants ManageDetainerWarrants.Model
    | DetainerWarrantCreation (Maybe String) DetainerWarrantCreation.Model


type alias Model =
    { window : Api.Window
    , profile : Maybe User
    , hamburgerMenuOpen : Bool
    , page : CurrentPage
    , runtime : Runtime
    }


init : Api.Flags Viewer -> Url -> Nav.Key -> ( Model, Cmd Msg )
init { window, viewer, runtime } url navKey =
    let
        session =
            Session.fromViewer navKey viewer

        maybeCred =
            Session.cred session
    in
    Tuple.mapSecond (\cmd -> Cmd.batch [ cmd, Api.currentUser maybeCred GotProfile User.userDecoder ])
        (changeRouteTo (Route.fromUrl url)
            { window = window
            , page = Redirect session
            , profile = Nothing
            , hamburgerMenuOpen = False
            , runtime = runtime
            }
        )


type Msg
    = ChangedUrl Url
    | ClickedLink Browser.UrlRequest
    | GotLoginMsg Login.Msg
    | GotLogoutMsg (Result Http.Error ())
    | GotTrendsMsg Trends.Msg
    | GotAboutMsg About.Msg
    | GotWarrantHelpMsg WarrantHelp.Msg
    | GotActionsMsg Actions.Msg
    | GotGlossaryMsg Glossary.Msg
    | GotOrganizerDashboardMsg OrganizerDashboard.Msg
    | GotCampaignOverviewMsg CampaignOverview.Msg
    | GotEventMsg Event.Msg
    | GotManageDetainerWarrantsMsg ManageDetainerWarrants.Msg
    | GotDetainerWarrantCreationMsg DetainerWarrantCreation.Msg
    | GotSession Session
    | GotHamburgerMenuPress
    | GotProfile (Result Http.Error User)
    | OnResize Int Int


toSession : Model -> Session
toSession model =
    case model.page of
        Redirect session ->
            session

        NotFound session ->
            session

        Login login ->
            Login.toSession login

        Trends home ->
            Trends.toSession home

        About about ->
            About.toSession about

        Glossary glossary ->
            Glossary.toSession glossary

        WarrantHelp warrantHelp ->
            WarrantHelp.toSession warrantHelp

        Actions actions ->
            Actions.toSession actions

        OrganizerDashboard dashboard ->
            OrganizerDashboard.toSession dashboard

        Event _ _ event ->
            Event.toSession event

        CampaignOverview _ campaign ->
            CampaignOverview.toSession campaign

        ManageDetainerWarrants dw ->
            ManageDetainerWarrants.toSession dw

        DetainerWarrantCreation _ dwc ->
            DetainerWarrantCreation.toSession dwc


changeRouteTo : Maybe Route -> Model -> ( Model, Cmd Msg )
changeRouteTo maybeRoute model =
    let
        session =
            toSession model

        runtime =
            model.runtime
    in
    case maybeRoute of
        Nothing ->
            ( { model | page = NotFound session }, Cmd.none )

        Just Route.Root ->
            ( model, Route.replaceUrl (Session.navKey session) Route.Trends )

        Just Route.Login ->
            Login.init session
                |> updateWith Login GotLoginMsg model

        Just Route.Logout ->
            ( model, Api.logout (Session.cred session) GotLogoutMsg )

        Just Route.Trends ->
            Trends.init runtime session
                |> updateWith Trends GotTrendsMsg model

        Just Route.About ->
            About.init session
                |> updateWith About GotAboutMsg model

        Just (Route.Glossary fragment) ->
            Glossary.init fragment session
                |> updateWith Glossary GotGlossaryMsg model

        Just Route.WarrantHelp ->
            WarrantHelp.init session
                |> updateWith WarrantHelp GotWarrantHelpMsg model

        Just Route.Actions ->
            Actions.init session
                |> updateWith Actions GotActionsMsg model

        Just (Route.CampaignOverview id) ->
            CampaignOverview.init id session
                |> updateWith (CampaignOverview id) GotCampaignOverviewMsg model

        Just (Route.Event campaignId eventId) ->
            Event.init campaignId eventId session
                |> updateWith (Event campaignId eventId) GotEventMsg model

        Just Route.OrganizerDashboard ->
            OrganizerDashboard.init session
                |> updateWith OrganizerDashboard GotOrganizerDashboardMsg model

        Just Route.ManageDetainerWarrants ->
            ManageDetainerWarrants.init runtime session
                |> updateWith ManageDetainerWarrants GotManageDetainerWarrantsMsg model

        Just (Route.DetainerWarrantCreation maybeId) ->
            DetainerWarrantCreation.init maybeId runtime session
                |> updateWith (DetainerWarrantCreation maybeId) GotDetainerWarrantCreationMsg model


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case ( msg, model.page ) of
        ( ClickedLink urlRequest, _ ) ->
            case urlRequest of
                Browser.Internal url ->
                    case url.fragment of
                        Nothing ->
                            ( model
                            , Nav.pushUrl (Session.navKey (toSession model)) (Url.toString url)
                            )

                        Just _ ->
                            ( model
                            , Nav.pushUrl (Session.navKey (toSession model)) (Url.toString url)
                            )

                Browser.External href ->
                    ( model, Nav.load href )

        ( ChangedUrl url, _ ) ->
            changeRouteTo (Route.fromUrl url) model

        ( GotLoginMsg subMsg, Login login ) ->
            Login.update subMsg login
                |> updateWith Login GotLoginMsg model

        ( GotTrendsMsg subMsg, Trends trends ) ->
            Trends.update subMsg trends
                |> updateWith Trends GotTrendsMsg model

        ( GotAboutMsg subMsg, About about ) ->
            About.update subMsg about
                |> updateWith About GotAboutMsg model

        ( GotWarrantHelpMsg subMsg, WarrantHelp warrantHelp ) ->
            WarrantHelp.update subMsg warrantHelp
                |> updateWith WarrantHelp GotWarrantHelpMsg model

        ( GotActionsMsg subMsg, Actions actions ) ->
            Actions.update subMsg actions
                |> updateWith Actions GotActionsMsg model

        ( GotGlossaryMsg subMsg, Glossary glossary ) ->
            Glossary.update subMsg glossary
                |> updateWith Glossary GotGlossaryMsg model

        ( GotOrganizerDashboardMsg subMsg, OrganizerDashboard dashboard ) ->
            OrganizerDashboard.update subMsg dashboard
                |> updateWith OrganizerDashboard GotOrganizerDashboardMsg model

        ( GotEventMsg subMsg, Event campaignId id event ) ->
            Event.update subMsg event
                |> updateWith (Event campaignId id) GotEventMsg model

        ( GotCampaignOverviewMsg subMsg, CampaignOverview id campaign ) ->
            CampaignOverview.update subMsg campaign
                |> updateWith (CampaignOverview id) GotCampaignOverviewMsg model

        ( GotManageDetainerWarrantsMsg subMsg, ManageDetainerWarrants dw ) ->
            ManageDetainerWarrants.update subMsg dw
                |> updateWith ManageDetainerWarrants GotManageDetainerWarrantsMsg model

        ( GotDetainerWarrantCreationMsg subMsg, DetainerWarrantCreation maybeId dwc ) ->
            DetainerWarrantCreation.update subMsg dwc
                |> updateWith (DetainerWarrantCreation maybeId) GotDetainerWarrantCreationMsg model

        ( GotHamburgerMenuPress, _ ) ->
            ( { model | hamburgerMenuOpen = not model.hamburgerMenuOpen }, Cmd.none )

        ( GotProfile result, _ ) ->
            case result of
                Ok me ->
                    ( { model | profile = Just me }, Cmd.none )

                Err _ ->
                    ( model, Cmd.none )

        ( GotSession session, _ ) ->
            let
                maybeCred =
                    Session.cred session
            in
            ( { model | page = Redirect session }
            , Cmd.batch
                [ Route.replaceUrl (Session.navKey session) Route.Trends
                , Api.currentUser maybeCred GotProfile User.userDecoder
                ]
            )

        ( OnResize width height, _ ) ->
            ( { model | window = { width = width, height = height } }, Cmd.none )

        ( _, _ ) ->
            ( model, Cmd.none )


updateWith : (subModel -> CurrentPage) -> (subMsg -> Msg) -> Model -> ( subModel, Cmd subMsg ) -> ( Model, Cmd Msg )
updateWith toModel toMsg model ( subModel, subCmd ) =
    ( { model | page = toModel subModel }
    , Cmd.map toMsg subCmd
    )



-- VIEW


classifyDevice : { window | height : Int, width : Int } -> Device
classifyDevice window =
    -- Tested in this ellie:
    -- https://ellie-app.com/68QM7wLW8b9a1
    { class =
        let
            longSide =
                max window.width window.height

            shortSide =
                min window.width window.height
        in
        if shortSide < 1000 then
            Phone

        else if longSide <= 1400 then
            Tablet

        else if longSide > 1200 && longSide <= 1920 then
            Desktop

        else
            BigDesktop
    , orientation =
        if window.width < window.height then
            Portrait

        else
            Landscape
    }


view : Model -> Browser.Document Msg
view model =
    let
        viewer =
            Session.viewer (toSession model)

        device =
            classifyDevice model.window

        settings =
            { device = device
            , user = model.profile
            , viewer = viewer
            }

        navBar =
            { hamburgerMenuOpen = model.hamburgerMenuOpen
            , onHamburgerMenuOpen = GotHamburgerMenuPress
            }

        viewPage : Page -> (msg -> Msg) -> { title : String, content : Element msg } -> { title : String, body : List (Html.Html Msg) }
        viewPage page toMsg { title, content } =
            let
                header =
                    Page.viewHeader
                        navBar
                        settings
                        page

                document =
                    Page.view header { title = title, content = Element.map toMsg content }
            in
            { title = document.title
            , body = document.body
            }
    in
    case model.page of
        Redirect _ ->
            Page.view (Page.viewHeader navBar settings Page.Other) Blank.view

        NotFound _ ->
            Page.view (Page.viewHeader navBar settings Page.Other) NotFound.view

        Login login ->
            viewPage Page.Other GotLoginMsg (Login.view login)

        Trends trends ->
            viewPage Page.Trends GotTrendsMsg (Trends.view device trends)

        About about ->
            viewPage Page.About GotAboutMsg (About.view about)

        Glossary glossary ->
            viewPage Page.Glossary GotGlossaryMsg (Glossary.view device glossary)

        WarrantHelp warrantHelp ->
            viewPage Page.WarrantHelp GotWarrantHelpMsg (WarrantHelp.view model.profile warrantHelp)

        Actions actions ->
            viewPage Page.Actions GotActionsMsg (Actions.view actions)

        OrganizerDashboard dashboard ->
            viewPage Page.OrganizerDashboard GotOrganizerDashboardMsg (OrganizerDashboard.view settings dashboard)

        Event campaignId eventId event ->
            viewPage (Page.Event campaignId eventId) GotEventMsg (Event.view settings event)

        CampaignOverview id campaign ->
            viewPage (Page.CampaignOverview id) GotCampaignOverviewMsg (CampaignOverview.view settings campaign)

        ManageDetainerWarrants dw ->
            viewPage Page.ManageDetainerWarrants GotManageDetainerWarrantsMsg (ManageDetainerWarrants.view settings dw)

        DetainerWarrantCreation maybeId dwc ->
            viewPage (Page.DetainerWarrantCreation maybeId) GotDetainerWarrantCreationMsg (DetainerWarrantCreation.view settings dwc)


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ case model.page of
            Redirect _ ->
                Sub.none

            NotFound _ ->
                Sub.none

            Login login ->
                Sub.map GotLoginMsg (Login.subscriptions login)

            Trends trends ->
                Sub.map GotTrendsMsg (Trends.subscriptions trends)

            About about ->
                Sub.map GotAboutMsg (About.subscriptions about)

            WarrantHelp warrantHelp ->
                Sub.map GotWarrantHelpMsg (WarrantHelp.subscriptions warrantHelp)

            Actions actions ->
                Sub.map GotActionsMsg (Actions.subscriptions actions)

            Glossary glossary ->
                Sub.map GotGlossaryMsg (Glossary.subscriptions glossary)

            OrganizerDashboard dashboard ->
                Sub.map GotOrganizerDashboardMsg (OrganizerDashboard.subscriptions dashboard)

            CampaignOverview _ campaign ->
                Sub.map GotCampaignOverviewMsg (CampaignOverview.subscriptions campaign)

            Event _ _ event ->
                Sub.map GotEventMsg (Event.subscriptions event)

            ManageDetainerWarrants dw ->
                Sub.map GotManageDetainerWarrantsMsg (ManageDetainerWarrants.subscriptions dw)

            DetainerWarrantCreation _ dwc ->
                Sub.map GotDetainerWarrantCreationMsg (DetainerWarrantCreation.subscriptions dwc)
        , Browser.Events.onResize OnResize
        , Session.changes GotSession (Session.navKey (toSession model))
        ]



-- SUBSCRIPTIONS


main : Program Value Model Msg
main =
    Api.application Viewer.decoder
        { init = init
        , onUrlChange = ChangedUrl
        , onUrlRequest = ClickedLink
        , subscriptions = subscriptions
        , update = update
        , view = view
        }
