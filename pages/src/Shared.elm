module Shared exposing (Data, Model, Msg, template)

import Browser.Navigation
import DataSource exposing (DataSource)
import Element exposing (Element, fill, width)
import Element.Font as Font
import Html exposing (Html)
import Html.Styled
import Pages.Flags
import Pages.PageUrl exposing (PageUrl)
import Path exposing (Path)
import Route exposing (Route)
import SharedTemplate exposing (SharedTemplate)
import View exposing (View)
import View.Header


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
    | IncrementFromChild


type alias Data =
    ()


type alias Model =
    { showMobileMenu : Bool
    , counter : Int
    , navigationKey : Maybe Browser.Navigation.Key
    }


init :
    Maybe Browser.Navigation.Key
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
      , counter = 0
      , navigationKey = navigationKey
      }
    , Cmd.none
    )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        OnPageChange _ ->
            ( { model | showMobileMenu = False }, Cmd.none )

        ToggleMobileMenu ->
            ( { model | showMobileMenu = not model.showMobileMenu }, Cmd.none )

        IncrementFromChild ->
            ( { model | counter = model.counter + 1 }, Cmd.none )


subscriptions : Path -> Model -> Sub Msg
subscriptions _ _ =
    Sub.none


data =
    DataSource.succeed ()


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
        (View.Header.view ToggleMobileMenu page.path
            |> Element.map toMsg
        )
            :: pageView.body
            |> Element.column
                [ width fill
                , Font.family [ Font.typeface "system" ]
                ]
            |> Element.layout [ width fill ]
    , title = pageView.title
    }
