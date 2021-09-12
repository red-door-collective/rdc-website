module Shared exposing (Data, Model, Msg, template)

import Browser.Navigation as Nav
import DataSource exposing (DataSource)
import DataSource.Port
import Element exposing (Element, fill, width)
import Element.Font as Font
import Html exposing (Html)
import Html.Styled
import Http
import Json.Encode as Encode
import OptimizedDecoder as Decode exposing (Decoder, int, string)
import OptimizedDecoder.Pipeline exposing (optional, required)
import Pages.Flags exposing (Flags(..))
import Pages.PageUrl exposing (PageUrl)
import Path exposing (Path)
import Rest exposing (Window)
import Rest.Static
import Route exposing (Route)
import Runtime exposing (Runtime)
import Session exposing (Session)
import SharedTemplate exposing (SharedTemplate)
import Url.Builder
import View exposing (View)
import View.Header
import View.MobileHeader
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
    | OnResize Int Int


type alias Data =
    { runtime : Runtime
    }


type alias Model =
    { showMobileMenu : Bool
    , navigationKey : Maybe Nav.Key
    , session : Session
    , queryParams : Maybe String
    , window : Window
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
    ( { showMobileMenu = False
      , navigationKey = navigationKey
      , session =
            case flags of
                BrowserFlags value ->
                    Decode.decodeValue (Decode.field "viewer" string) value
                        |> Result.andThen (Decode.decodeString (Rest.Static.storageDecoder Viewer.staticDecoder))
                        |> Result.toMaybe
                        |> Session.fromViewer navigationKey

                PreRenderFlags ->
                    Session.fromViewer Nothing Nothing
      , queryParams =
            Maybe.andThen (.query << .path) maybePagePath
      , window =
            case flags of
                BrowserFlags value ->
                    Decode.decodeValue (Decode.field "window" windowDecoder) value
                        |> Result.withDefault { width = 0, height = 0 }

                PreRenderFlags ->
                    { width = 0, height = 0 }
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
                                "/admin/dashboard"

                             else
                                "/"
                            )
                    )
                    (Session.navKey session)
            )

        OnResize width height ->
            ( { model | window = { width = width, height = height } }, Cmd.none )


subscriptions : Path -> Model -> Sub Msg
subscriptions _ model =
    Session.changes GotSession (Session.navKey model.session)


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
        (View.Header.view model.session ToggleMobileMenu page
            |> Element.map toMsg
        )
            :: (if model.showMobileMenu then
                    View.MobileHeader.view model.session page
                        |> Element.map toMsg

                else
                    Element.none
               )
            :: pageView.body
            |> Element.column
                [ width fill
                , Font.family [ Font.typeface "system" ]
                ]
            |> Element.layout [ width fill ]
    , title = pageView.title
    }
