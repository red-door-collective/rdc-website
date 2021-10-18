module Shared exposing (Data, Model, Msg, template)

import Browser.Events exposing (onResize)
import Browser.Navigation as Nav
import DataSource
import DataSource.Port
import Element exposing (fill, width)
import Html exposing (Html)
import Json.Encode as Encode
import OptimizedDecoder as Decode exposing (Decoder, int, string)
import OptimizedDecoder.Pipeline exposing (required)
import Pages.Flags exposing (Flags(..))
import Pages.PageUrl exposing (PageUrl)
import Path exposing (Path)
import Rest exposing (Window)
import Rest.Static
import Route exposing (Route)
import Runtime exposing (Runtime)
import Session exposing (Session)
import SharedTemplate exposing (SharedTemplate)
import UI.RenderConfig as RenderConfig exposing (RenderConfig)
import View exposing (View)
import View.Header
import Viewer


template : SharedTemplate Msg Model Data msg
template =
    { init = init
    , update = update
    , view = view
    , data = data
    , subscriptions = subscriptions
    , onPageChange = Just OnPageChange
    }


type Msg
    = OnPageChange
        { path : Path
        , query : Maybe String
        , fragment : Maybe String
        }
    | ToggleMobileMenu
    | GotSession Session
    | SetWindow Int Int


type alias Data =
    { runtime : Runtime
    }


type alias Model =
    { showMobileMenu : Bool
    , navigationKey : Maybe Nav.Key
    , session : Session
    , queryParams : Maybe String
    , window : Window
    , renderConfig : RenderConfig
    }


windowDecoder : Decoder Window
windowDecoder =
    Decode.succeed Window
        |> required "width" int
        |> required "height" int


init :
    Maybe Nav.Key
    -> Pages.Flags.Flags
    ->
        Maybe
            { path :
                { path : Path
                , query : Maybe String
                , fragment : Maybe String
                }
            , metadata : route
            , pageUrl : Maybe PageUrl
            }
    -> ( Model, Cmd Msg )
init navigationKey flags maybePagePath =
    let
        session =
            case flags of
                BrowserFlags value ->
                    Decode.decodeValue (Decode.field "viewer" string) value
                        |> Result.andThen (Decode.decodeString (Rest.Static.storageDecoder Viewer.staticDecoder))
                        |> Result.toMaybe
                        |> Session.fromViewer navigationKey

                PreRenderFlags ->
                    Session.fromViewer Nothing Nothing

        window =
            case flags of
                BrowserFlags value ->
                    Decode.decodeValue (Decode.field "window" windowDecoder) value
                        |> Result.withDefault { width = 0, height = 0 }

                PreRenderFlags ->
                    { width = 0, height = 0 }
    in
    ( { showMobileMenu = False
      , navigationKey = navigationKey
      , session = session
      , queryParams =
            Maybe.andThen (.query << .path) maybePagePath
      , window = window
      , renderConfig =
            RenderConfig.init
                { width = window.width
                , height = window.height
                }
                RenderConfig.localeEnglish
      }
    , Cmd.none
    )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        OnPageChange pageUrl ->
            ( { model
                | showMobileMenu = False
                , queryParams = pageUrl.query
              }
            , Cmd.none
            )

        ToggleMobileMenu ->
            ( { model | showMobileMenu = not model.showMobileMenu }, Cmd.none )

        GotSession session ->
            ( { model | session = session }
            , Maybe.withDefault Cmd.none <|
                Maybe.map
                    (\key ->
                        Nav.replaceUrl key
                            (if Session.isLoggedIn session then
                                "/admin/detainer-warrants"

                             else
                                "/"
                            )
                    )
                    (Session.navKey session)
            )

        SetWindow width height ->
            ( { model | window = { width = width, height = height } }, Cmd.none )


subscriptions : Path -> Model -> Sub Msg
subscriptions _ model =
    Sub.batch
        [ Session.changes GotSession (Session.navKey model.session)
        , onResize SetWindow
        ]


data : DataSource.DataSource Data
data =
    DataSource.map Data
        (DataSource.map4 Runtime
            (DataSource.Port.get "environmentVariable"
                (Encode.string "ENV")
                Runtime.decodeEnvironment
            )
            (DataSource.Port.get "environmentVariable"
                (Encode.string "ROLLBAR_CLIENT_TOKEN")
                Runtime.decodeToken
            )
            (DataSource.Port.get "environmentVariable"
                (Encode.string "VERSION")
                Runtime.decodeCodeVersion
            )
            (DataSource.Port.get "today" (Encode.string "meh") Runtime.decodeDate)
        )


view :
    Data
    ->
        { path : Path
        , route : Maybe Route
        }
    -> Model
    -> (Msg -> msg)
    -> View msg
    -> { body : Html msg, title : String }
view tableOfContents page model toMsg pageView =
    { body =
        (View.Header.view model.showMobileMenu model.session ToggleMobileMenu page
            |> Element.map toMsg
        )
            :: pageView.body
            |> Element.column
                [ width fill

                -- , Font.family [ Font.typeface "system" ]
                ]
            |> Element.layout [ width fill ]
    , title = pageView.title
    }
