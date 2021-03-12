module Main exposing (main)

import Browser
import Color
import Date
import DateFormat exposing (format, monthNameAbbreviated)
import DateTime
import Element exposing (Element, fill)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Input
import Html exposing (Html)
import Html.Attributes exposing (class)
import Html.Events
import Http
import Json.Decode as Decode exposing (Decoder, Value, bool, int, list, nullable, string)
import Json.Decode.Pipeline exposing (optional, required)
import LineChart as LineChart
import LineChart.Area as Area
import LineChart.Axis as Axis
import LineChart.Axis.Intersection as Intersection
import LineChart.Axis.Line as AxisLine
import LineChart.Axis.Range as Range
import LineChart.Axis.Tick as Tick
import LineChart.Axis.Ticks as Ticks
import LineChart.Axis.Title as Title
import LineChart.Container as Container
import LineChart.Coordinate as Coordinate
import LineChart.Dots as Dots
import LineChart.Events as Events
import LineChart.Grid as Grid
import LineChart.Interpolation as Interpolation
import LineChart.Junk as Junk exposing (..)
import LineChart.Legends as Legends
import LineChart.Line as Line
import Palette
import Svg exposing (Svg)
import Time exposing (Month(..))
import Time.Extra as Time exposing (Parts, partsToPosix)


type alias Info =
    { evictions : Float
    , date : Float
    }


date : Int -> Month -> Int -> Float
date year month day =
    toFloat (Time.posixToMillis (partsToPosix Time.utc (Parts year month day 0 0 0 0)))


elmington : List Info
elmington =
    [ Info 10 (date 2020 Apr 1)
    , Info 15 (date 2020 May 1)
    , Info 25 (date 2020 Jun 1)
    , Info 43 (date 2020 Jul 1)
    ]


mdha : List Info
mdha =
    [ Info 12 (date 2020 Apr 1)
    , Info 17 (date 2020 May 1)
    , Info 25 (date 2020 Jun 1)
    , Info 43 (date 2020 Jul 1)
    ]


hickoryhigh : List Info
hickoryhigh =
    [ Info 13 (date 2020 Apr 1)
    , Info 16 (date 2020 May 1)
    , Info 40 (date 2020 Jun 1)
    , Info 5 (date 2020 Jul 1)
    ]


hickorychase : List Info
hickorychase =
    [ Info 30 (date 2020 Apr 1)
    , Info 15 (date 2020 May 1)
    , Info 20 (date 2020 Jun 1)
    , Info 50 (date 2020 Jul 1)
    ]


wood : List Info
wood =
    [ Info 22 (date 2020 Apr 1)
    , Info 11 (date 2020 May 1)
    , Info 33 (date 2020 Jun 1)
    , Info 11 (date 2020 Jul 1)
    ]


cove : List Info
cove =
    [ Info 13 (date 2020 Apr 1)
    , Info 14 (date 2020 May 1)
    , Info 15 (date 2020 Jun 1)
    , Info 16 (date 2020 Jul 1)
    ]


urban : List Info
urban =
    [ Info 26 (date 2020 Apr 1)
    , Info 2 (date 2020 May 1)
    , Info 19 (date 2020 Jun 1)
    , Info 21 (date 2020 Jul 1)
    ]


creekstone : List Info
creekstone =
    [ Info 30 (date 2020 Apr 1)
    , Info 25 (date 2020 May 1)
    , Info 4 (date 2020 Jun 1)
    , Info 9 (date 2020 Jul 1)
    ]


cambridge : List Info
cambridge =
    [ Info 17 (date 2020 Apr 1)
    , Info 19 (date 2020 May 1)
    , Info 12 (date 2020 Jun 1)
    , Info 8 (date 2020 Jul 1)
    ]


nobhill : List Info
nobhill =
    [ Info 3 (date 2020 Apr 1)
    , Info 7 (date 2020 May 1)
    , Info 29 (date 2020 Jun 1)
    , Info 3 (date 2020 Jul 1)
    ]


type Status
    = Closed
    | Pending


type AmountClaimedCategory
    = Possession
    | Fees
    | Both
    | NotApplicable


type alias Defendant =
    { name : String, phone : String, address : String }


type alias Judge =
    { name : String }


type alias Attorney =
    { name : String }


type alias Plantiff =
    { name : String, attorney : Attorney }


type alias Courtroom =
    { name : String }


type alias DetainerWarrant =
    { docketId : String
    , fileDate : String
    , status : Status
    , plantiff : Plantiff
    , courtDate : Maybe String
    , courtroom : Maybe Courtroom
    , presidingJudge : Maybe Judge
    , amountClaimed : Maybe String
    , amountClaimedCategory : AmountClaimedCategory
    , defendants : List Defendant
    }


statusDecoder : Decoder Status
statusDecoder =
    Decode.string
        |> Decode.andThen
            (\str ->
                case str of
                    "CLOSED" ->
                        Decode.succeed Closed

                    "PENDING" ->
                        Decode.succeed Pending

                    somethingElse ->
                        Decode.fail <| "Unknown status:" ++ somethingElse
            )


amountClaimedCategoryDecoder : Decoder AmountClaimedCategory
amountClaimedCategoryDecoder =
    Decode.string
        |> Decode.andThen
            (\str ->
                case str of
                    "POSS" ->
                        Decode.succeed Possession

                    "FEES" ->
                        Decode.succeed Fees

                    "BOTH" ->
                        Decode.succeed Both

                    "N/A" ->
                        Decode.succeed NotApplicable

                    somethingElse ->
                        Decode.fail <| "Unknown amount claimed category:" ++ somethingElse
            )


attorneyDecoder : Decoder Attorney
attorneyDecoder =
    Decode.succeed Attorney
        |> required "name" string


courtroomDecoder : Decoder Courtroom
courtroomDecoder =
    Decode.succeed Courtroom
        |> required "name" string


judgeDecoder : Decoder Judge
judgeDecoder =
    Decode.succeed Judge
        |> required "name" string


plantiffDecoder : Decoder Plantiff
plantiffDecoder =
    Decode.succeed Plantiff
        |> required "name" string
        |> required "attorney" attorneyDecoder


defendantDecoder : Decoder Defendant
defendantDecoder =
    Decode.succeed Defendant
        |> required "name" string
        |> optional "phone" string "not provided"
        |> required "address" string


detainerWarrantDecoder : Decoder DetainerWarrant
detainerWarrantDecoder =
    Decode.succeed DetainerWarrant
        |> required "docket_id" string
        |> required "file_date" string
        |> required "status" statusDecoder
        |> required "plantiff" plantiffDecoder
        |> required "court_date" (nullable string)
        |> required "courtroom" (nullable courtroomDecoder)
        |> required "presiding_judge" (nullable judgeDecoder)
        |> required "amount_claimed" (nullable string)
        |> required "amount_claimed_category" amountClaimedCategoryDecoder
        |> required "defendants" (list defendantDecoder)


apiMetaDecoder : Decoder ApiMeta
apiMetaDecoder =
    Decode.succeed ApiMeta
        |> required "after_cursor" (nullable string)
        |> required "has_next_page" bool


detainerWarrantApiDecoder : Decoder (ApiPage DetainerWarrant)
detainerWarrantApiDecoder =
    Decode.succeed ApiPage
        |> required "data" (list detainerWarrantDecoder)
        |> required "meta" apiMetaDecoder


type alias Model =
    { warrants : List DetainerWarrant
    , query : String
    , warrantsCursor : Maybe String
    , hovering : List Info
    }


type alias ApiMeta =
    { afterCursor : Maybe String
    , hasNextPage : Bool
    }


type alias ApiPage data =
    { data : List data
    , meta : ApiMeta
    }


type Page
    = Welcome Model


init : Value -> ( Page, Cmd Msg )
init _ =
    ( Welcome
        { warrants = []
        , query = ""
        , warrantsCursor = Nothing
        , hovering = []
        }
    , Cmd.none
    )


type Msg
    = SearchWarrants
    | InputQuery String
    | GotWarrants (Result Http.Error (ApiPage DetainerWarrant))
    | Hover (List Info)


getWarrants : String -> Cmd Msg
getWarrants query =
    Http.get
        { url = "/api/v1/detainer-warrants/?defendant_name=" ++ query
        , expect = Http.expectJson GotWarrants detainerWarrantApiDecoder
        }


update : Msg -> Page -> ( Page, Cmd Msg )
update msg page =
    case page of
        Welcome model ->
            case msg of
                InputQuery query ->
                    ( Welcome { model | query = query }, Cmd.none )

                SearchWarrants ->
                    ( Welcome model, getWarrants model.query )

                GotWarrants result ->
                    case result of
                        Ok detainerWarrantsPage ->
                            ( Welcome { model | warrants = detainerWarrantsPage.data, warrantsCursor = detainerWarrantsPage.meta.afterCursor }, Cmd.none )

                        Err errMsg ->
                            ( Welcome model, Cmd.none )

                Hover hovering ->
                    ( Welcome { model | hovering = hovering }, Cmd.none )



-- VIEW


viewPage : Page -> Browser.Document Msg
viewPage page =
    case page of
        Welcome model ->
            { title = "Detainer Warrant Database", body = [ viewWarrantsPage model ] }


viewDefendant : Defendant -> Element Msg
viewDefendant defendant =
    viewTextRow defendant.name


viewDefendants : DetainerWarrant -> Element Msg
viewDefendants warrant =
    Element.column []
        (List.map viewDefendant warrant.defendants)


viewCourtDate : DetainerWarrant -> Element Msg
viewCourtDate warrant =
    viewTextRow
        (case warrant.courtDate of
            Just courtDate ->
                courtDate

            Nothing ->
                "Unknown"
        )


viewTextRow text =
    Element.row
        [ Element.width fill
        , Element.padding 10
        , Border.solid
        , Border.color Palette.grayLight
        , Border.widthEach { bottom = 1, left = 0, right = 0, top = 0 }
        ]
        [ Element.text text ]


viewHeaderCell text =
    Element.row
        [ Element.width fill
        , Element.padding 10
        , Font.bold
        , Border.solid
        , Border.color Palette.grayLight
        , Border.widthEach { bottom = 1, left = 0, right = 0, top = 0 }
        ]
        [ Element.text text ]


viewWarrants : Model -> Element Msg
viewWarrants model =
    Element.table []
        { data = List.filter (\warrant -> List.any (\defendant -> String.contains (String.toUpper model.query) (String.toUpper defendant.name)) warrant.defendants) model.warrants
        , columns =
            [ { header = viewHeaderCell "Docket ID"
              , width = fill
              , view =
                    \warrant ->
                        viewTextRow warrant.docketId
              }
            , { header = viewHeaderCell "Court Date"
              , width = fill
              , view = viewCourtDate
              }
            , { header = viewHeaderCell "File Date"
              , width = fill
              , view =
                    \warrant ->
                        viewTextRow warrant.fileDate
              }
            , { header = viewHeaderCell "Defendants"
              , width = fill
              , view = viewDefendants
              }
            , { header = viewHeaderCell "Plantiff"
              , width = fill
              , view =
                    \warrant ->
                        viewTextRow warrant.plantiff.name
              }
            ]
        }


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
        [ Element.width fill
        , Element.spacing 10
        , Element.padding 10
        , Element.centerY
        , Element.centerX
        ]
        [ Element.Input.search
            [ Element.width (fill |> Element.maximum 600)
            , onEnter SearchWarrants
            ]
            { onChange = InputQuery
            , text = model.query
            , placeholder = Just (Element.Input.placeholder [] (Element.text "Search for a defendant"))
            , label = Element.Input.labelHidden "Search for a defendant"
            }
        , Element.Input.button
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


viewWarrantsPage : Model -> Html Msg
viewWarrantsPage model =
    Element.layoutWith
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
        [ Element.width fill, Element.padding 20, Font.size 14 ]
        (Element.column
            [ Element.spacing 10
            , Element.centerX
            , Element.centerY
            ]
            [ Element.html (chart model)
            , Element.row [ Font.size 20, Element.width (fill |> Element.maximum 1200 |> Element.minimum 400) ]
                [ Element.column []
                    [ Element.row [] [ Element.text "Find your Detainer Warrant case" ]
                    , viewSearchBar model
                    , Element.row []
                        [ viewWarrants model ]
                    ]
                ]
            ]
        )


chart : Model -> Svg Msg
chart model =
    LineChart.viewCustom
        { y = Axis.default 600 "Evictions" .evictions
        , x = xAxisConfig --Axis.time Time.utc 2000 "Date" .date
        , container = Container.styled "line-chart-1" [ ( "font-family", "monospace" ) ]
        , interpolation = Interpolation.default
        , intersection = Intersection.default
        , legends = Legends.groupedCustom 30 viewLegends
        , events = Events.hoverMany Hover
        , junk = Junk.hoverMany model.hovering formatX formatY
        , grid = Grid.default
        , area = Area.default
        , line = Line.default
        , dots = Dots.hoverMany model.hovering
        }
        [ LineChart.line Color.orange Dots.triangle "Elmington Property Management" elmington
        , LineChart.line Color.yellow Dots.circle "M D H A" mdha
        , LineChart.line Color.purple Dots.diamond "Hickory Highlands Apartment Homes" hickoryhigh
        , LineChart.line Color.red Dots.square "Hickory Chase Apartments" hickorychase
        , LineChart.line Color.darkBlue Dots.triangle "Woodbine Community" wood
        , LineChart.line Color.lightBlue Dots.circle "Cove at Priest Lake Apartments" cove
        , LineChart.line Color.darkGreen Dots.triangle "Urban Housing Solutions" urban
        , LineChart.line Color.darkGrey Dots.circle "Creekstone Apartments" creekstone
        , LineChart.line Color.lightGreen Dots.diamond "Cambridge at Hickory Hollow" cambridge
        , LineChart.line Color.brown Dots.square "Nob Hill Villa Apartments" nobhill
        ]


viewLegends : Coordinate.System -> List (Legends.Legend msg) -> Svg.Svg msg
viewLegends system legends =
    Svg.g
        [ Junk.transform
            [ Junk.move system system.x.min system.y.max
            , Junk.offset 20 20
            ]
        ]
        (List.indexedMap viewLegend legends)


viewLegend : Int -> Legends.Legend msg -> Svg.Svg msg
viewLegend index { sample, label } =
    Svg.g
        [ Junk.transform [ Junk.offset 20 (toFloat index * 14) ] ]
        [ sample, viewLabel label ]


viewLabel : String -> Svg.Svg msg
viewLabel label =
    Svg.g
        [ Junk.transform [ Junk.offset 40 4 ] ]
        [ Junk.label Color.black label ]


formatX : Info -> String
formatX info =
    "Month: " ++ dateFormat (Time.millisToPosix (round info.date))


dateFormat : Time.Posix -> String
dateFormat =
    DateFormat.format [ DateFormat.dayOfMonthFixed, DateFormat.text " ", DateFormat.monthNameAbbreviated ] Time.utc


formatY : Info -> String
formatY info =
    String.fromFloat info.evictions


formatMonth : Time.Posix -> String
formatMonth time =
    format
        [ monthNameAbbreviated ]
        Time.utc
        time


tickLabel : String -> Svg.Svg msg
tickLabel =
    Junk.label Color.black


tickTime : Tick.Time -> Tick.Config msg
tickTime time =
    let
        label =
            Junk.label Color.black (Tick.format time)
    in
    Tick.custom
        { position = 6
        , color = Color.black
        , width = 1
        , length = 7
        , grid = True
        , direction = Tick.positive
        , label = Just label
        }


xAxisConfig : Axis.Config Info msg
xAxisConfig =
    Axis.custom
        { title = Title.default "Month"
        , variable = Just << .date
        , pixels = 1000
        , range = Range.padded 20 20
        , axisLine = AxisLine.full Color.black
        , ticks = ticksConfig
        }


ticksConfig : Ticks.Config msg
ticksConfig =
    Ticks.timeCustom Time.utc 5 tickTime


subscriptions : Page -> Sub Msg
subscriptions page =
    case page of
        Welcome _ ->
            Sub.none


main : Program Value Page Msg
main =
    Browser.document
        { init = init
        , view = viewPage
        , update = update
        , subscriptions = subscriptions
        }
