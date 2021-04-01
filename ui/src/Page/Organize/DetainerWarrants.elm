module Page.Organize.DetainerWarrants exposing (Model, Msg, init, subscriptions, toSession, update, view)

import Api exposing (Cred)
import Api.Endpoint as Endpoint
import Color
import DetainerWarrant exposing (DetainerWarrant)
import Element exposing (Element, centerX, column, fill, height, image, maximum, minimum, padding, paragraph, px, row, spacing, text, textColumn, width)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Input as Input
import FeatherIcons
import Html.Events
import Http
import Json.Decode as Decode
import Palette
import Session exposing (Session)
import Settings exposing (Settings)
import User exposing (User)
import Widget
import Widget.Icon


type alias Model =
    { session : Session
    , warrants : List DetainerWarrant
    , query : String
    , warrantsCursor : Maybe String
    }


init : Session -> ( Model, Cmd Msg )
init session =
    ( { session = session
      , warrants = []
      , query = ""
      , warrantsCursor = Nothing
      }
    , Cmd.none
    )


getWarrants : Maybe Cred -> Cmd Msg
getWarrants viewer =
    Api.get Endpoint.detainerWarrants viewer GotWarrants Api.detainerWarrantApiDecoder


type Msg
    = InputQuery String
    | SearchWarrants
    | GotWarrants (Result Http.Error (Api.Collection DetainerWarrant))
    | ChangedSorting String


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        InputQuery query ->
            ( { model | query = query }, Cmd.none )

        SearchWarrants ->
            let
                maybeCred =
                    Session.cred model.session
            in
            ( model, getWarrants maybeCred )

        GotWarrants result ->
            case result of
                Ok detainerWarrantsPage ->
                    ( { model | warrants = detainerWarrantsPage.data, warrantsCursor = detainerWarrantsPage.meta.afterCursor }, Cmd.none )

                Err errMsg ->
                    ( model, Cmd.none )

        ChangedSorting _ ->
            ( model, Cmd.none )


onEnter : msg -> Element.Attribute msg
onEnter msg =
    Element.htmlAttribute
        (Html.Events.on "keyup"
            (Decode.field "key" Decode.string
                |> Decode.andThen
                    (\key ->
                        if key == "Enter" then
                            Decode.succeed msg

                        else
                            Decode.fail "Not the enter key"
                    )
            )
        )


viewSearchBar : Model -> Element Msg
viewSearchBar model =
    Element.row
        [ --Element.width fill
          Element.spacing 10
        , Element.padding 10
        , Element.centerY
        , Element.centerX
        ]
        [ Input.search
            [ Element.width (fill |> Element.maximum 600)
            , onEnter SearchWarrants
            ]
            { onChange = InputQuery
            , text = model.query
            , placeholder = Just (Input.placeholder [] (Element.text "Search for a defendant"))
            , label = Input.labelHidden "Search for a defendant"
            }
        , Input.button
            [ Element.centerY
            , Background.color Palette.redLight
            , Element.focused [ Background.color Palette.red ]
            , Element.height fill
            , Font.color (Element.rgb 255 255 255)
            , Element.padding 10
            , Border.rounded 5
            ]
            { onPress = Just SearchWarrants, label = Element.text "Search" }
        ]


view : Settings -> Model -> { title : String, content : Element Msg }
view settings model =
    { title = "Admin - Detainer Warrants"
    , content =
        row [ centerX, padding 10, Font.size 20, width (fill |> maximum 1000 |> minimum 400) ]
            [ column [ centerX, spacing 10 ]
                [ viewSearchBar model
                , viewWarrants model.warrants
                ]
            ]
    }


ascIcon =
    FeatherIcons.chevronUp
        |> Widget.Icon.elmFeather FeatherIcons.toHtml


sortIconStyle =
    { size = 20, color = Color.white }


descIcon =
    FeatherIcons.chevronDown
        |> Widget.Icon.elmFeather FeatherIcons.toHtml


noSortIcon =
    FeatherIcons.chevronDown
        |> Widget.Icon.elmFeather FeatherIcons.toHtml


tableStyle =
    { elementTable = []
    , content =
        { header = buttonStyle
        , ascIcon = ascIcon
        , descIcon = descIcon
        , defaultIcon = noSortIcon
        }
    }


buttonStyle =
    { elementButton =
        [ width (px 40), height (px 40), Background.color Palette.sred, centerX, Font.center ]
    , ifDisabled = []
    , ifActive = []
    , otherwise = []
    , content =
        { elementRow = [ centerX, Font.center ]
        , content =
            { text = { contentText = [] }
            , icon = { ifDisabled = sortIconStyle, ifActive = sortIconStyle, otherwise = sortIconStyle }
            }
        }
    }


sortBy : String
sortBy =
    "Docket ID"


asc : Bool
asc =
    True


viewWarrants : List DetainerWarrant -> Element Msg
viewWarrants warrants =
    Widget.sortTable tableStyle
        { content = warrants
        , columns =
            [ Widget.stringColumn
                { title = "Docket ID"
                , value = .docketId
                , toString = \str -> "#" ++ str
                , width = Element.fill
                }
            , Widget.stringColumn
                { title = "Court Date"
                , value = Maybe.withDefault "N/A" << .courtDate
                , toString = identity
                , width = Element.fill
                }
            , Widget.stringColumn
                { title = "File Date"
                , value = .fileDate
                , toString = identity
                , width = Element.fill
                }
            , Widget.stringColumn
                { title = "Plantiff"
                , value = .plantiff >> .name
                , toString = identity
                , width = Element.fill
                }
            ]
        , asc = asc
        , sortBy = sortBy
        , onChange = ChangedSorting
        }


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- EXPORT


toSession : Model -> Session
toSession model =
    model.session
