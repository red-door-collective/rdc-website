module Main exposing (main)

import Api
import Browser
import Browser.Events
import Browser.Navigation as Nav
import Element
import Html
import Json.Decode as Decode exposing (Decoder, Value)
import Json.Decode.Pipeline exposing (optional, required)
import Page
import Page.About as About
import Page.Actions as Actions
import Page.Blank as Blank
import Page.Login as Login
import Page.NotFound as NotFound
import Page.Trends as Trends
import Page.WarrantHelp as WarrantHelp
import Route exposing (Route)
import Session exposing (Session)
import Url exposing (Url)
import Viewer exposing (Viewer)


type CurrentPage
    = Redirect Session
    | NotFound Session
    | Login Login.Model
    | Trends Trends.Model
    | WarrantHelp WarrantHelp.Model
    | About About.Model
    | Actions Actions.Model


type alias Model =
    { window : Api.Window
    , page : CurrentPage
    }


init : Api.Flags Viewer -> Url -> Nav.Key -> ( Model, Cmd Msg )
init { window, viewer } url navKey =
    changeRouteTo (Route.fromUrl url)
        { window = window, page = Redirect (Session.fromViewer navKey viewer) }


type Msg
    = ChangedUrl Url
    | ClickedLink Browser.UrlRequest
    | GotLoginMsg Login.Msg
    | GotTrendsMsg Trends.Msg
    | GotAboutMsg About.Msg
    | GotWarrantHelpMsg WarrantHelp.Msg
    | GotActionsMsg Actions.Msg
    | GotSession Session
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

        WarrantHelp warrantHelp ->
            WarrantHelp.toSession warrantHelp

        Actions actions ->
            Actions.toSession actions


changeRouteTo : Maybe Route -> Model -> ( Model, Cmd Msg )
changeRouteTo maybeRoute model =
    let
        session =
            toSession model
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
            ( model, Api.logout )

        Just Route.Trends ->
            Trends.init session
                |> updateWith Trends GotTrendsMsg model

        Just Route.About ->
            About.init session
                |> updateWith About GotAboutMsg model

        Just Route.WarrantHelp ->
            WarrantHelp.init session
                |> updateWith WarrantHelp GotWarrantHelpMsg model

        Just Route.Actions ->
            Actions.init session
                |> updateWith Actions GotActionsMsg model


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

        ( GotSession session, Redirect _ ) ->
            ( { model | page = Redirect session }
            , Route.replaceUrl (Session.navKey session) Route.Trends
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


view : Model -> Browser.Document Msg
view model =
    let
        viewer =
            Session.viewer (toSession model)

        device =
            Element.classifyDevice model.window

        viewPage page toMsg config =
            let
                { title, body } =
                    Page.view device viewer page config
            in
            { title = title
            , body = List.map (Html.map toMsg) body
            }
    in
    case model.page of
        Redirect _ ->
            Page.view device viewer Page.Other Blank.view

        NotFound _ ->
            Page.view device viewer Page.Other NotFound.view

        Login login ->
            viewPage Page.Other GotLoginMsg (Login.view login)

        Trends trends ->
            viewPage Page.Trends GotTrendsMsg (Trends.view device trends)

        About about ->
            viewPage Page.About GotAboutMsg (About.view about)

        WarrantHelp warrantHelp ->
            viewPage Page.WarrantHelp GotWarrantHelpMsg (WarrantHelp.view warrantHelp)

        Actions actions ->
            viewPage Page.Actions GotActionsMsg (Actions.view actions)


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        ((case model.page of
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
         )
            :: [ Browser.Events.onResize OnResize ]
        )


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
