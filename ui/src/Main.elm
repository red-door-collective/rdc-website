module Main exposing (main)

import Api
import Browser
import Browser.Navigation as Nav
import Html
import Json.Decode exposing (Value)
import Page
import Page.About as About
import Page.Blank as Blank
import Page.NotFound as NotFound
import Page.Trends as Trends
import Page.WarrantHelp as WarrantHelp
import Route exposing (Route)
import Session exposing (Session)
import Url exposing (Url)
import Viewer exposing (Viewer)


type Model
    = Redirect Session
    | NotFound Session
    | Trends Trends.Model
    | WarrantHelp WarrantHelp.Model
    | About About.Model


init : Maybe Viewer -> Url -> Nav.Key -> ( Model, Cmd Msg )
init maybeViewer url navKey =
    changeRouteTo (Route.fromUrl url)
        (Redirect (Session.fromViewer navKey maybeViewer))


type Msg
    = ChangedUrl Url
    | ClickedLink Browser.UrlRequest
    | GotTrendsMsg Trends.Msg
    | GotAboutMsg About.Msg
    | GotWarrantHelpMsg WarrantHelp.Msg
    | GotSession Session


toSession : Model -> Session
toSession model =
    case model of
        Redirect session ->
            session

        NotFound session ->
            session

        Trends home ->
            Trends.toSession home

        About settings ->
            About.toSession settings

        WarrantHelp warrantHelp ->
            WarrantHelp.toSession warrantHelp


changeRouteTo : Maybe Route -> Model -> ( Model, Cmd Msg )
changeRouteTo maybeRoute model =
    let
        session =
            toSession model
    in
    case maybeRoute of
        Nothing ->
            ( NotFound session, Cmd.none )

        Just Route.Root ->
            ( model, Route.replaceUrl (Session.navKey session) Route.Trends )

        Just Route.Trends ->
            Trends.init session
                |> updateWith Trends GotTrendsMsg model

        Just Route.About ->
            About.init session
                |> updateWith About GotAboutMsg model

        Just Route.WarrantHelp ->
            WarrantHelp.init session
                |> updateWith WarrantHelp GotWarrantHelpMsg model


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case ( msg, model ) of
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

        ( GotTrendsMsg subMsg, Trends trends ) ->
            Trends.update subMsg trends
                |> updateWith Trends GotTrendsMsg model

        ( GotAboutMsg subMsg, About about ) ->
            About.update subMsg about
                |> updateWith About GotAboutMsg model

        ( GotWarrantHelpMsg subMsg, WarrantHelp warrantHelp ) ->
            WarrantHelp.update subMsg warrantHelp
                |> updateWith WarrantHelp GotWarrantHelpMsg model

        ( GotSession session, Redirect _ ) ->
            ( Redirect session
            , Route.replaceUrl (Session.navKey session) Route.Trends
            )

        ( _, _ ) ->
            ( model, Cmd.none )


updateWith : (subModel -> Model) -> (subMsg -> Msg) -> Model -> ( subModel, Cmd subMsg ) -> ( Model, Cmd Msg )
updateWith toModel toMsg model ( subModel, subCmd ) =
    ( toModel subModel
    , Cmd.map toMsg subCmd
    )



-- VIEW


view : Model -> Browser.Document Msg
view model =
    let
        viewer =
            Session.viewer (toSession model)

        viewPage page toMsg config =
            let
                { title, body } =
                    Page.view viewer page config
            in
            { title = title
            , body = List.map (Html.map toMsg) body
            }
    in
    case model of
        Redirect _ ->
            Page.view viewer Page.Other Blank.view

        NotFound _ ->
            Page.view viewer Page.Other NotFound.view

        Trends trends ->
            viewPage Page.Trends GotTrendsMsg (Trends.view trends)

        About about ->
            viewPage Page.About GotAboutMsg (About.view about)

        WarrantHelp warrantHelp ->
            viewPage Page.WarrantHelp GotWarrantHelpMsg (WarrantHelp.view warrantHelp)


subscriptions : Model -> Sub Msg
subscriptions model =
    case model of
        Redirect _ ->
            Sub.none

        NotFound _ ->
            Sub.none

        Trends trends ->
            Sub.map GotTrendsMsg (Trends.subscriptions trends)

        About about ->
            Sub.map GotAboutMsg (About.subscriptions about)

        WarrantHelp warrantHelp ->
            Sub.map GotWarrantHelpMsg (WarrantHelp.subscriptions warrantHelp)


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
