module Main exposing (main)

import Array exposing (Array)
import Axis
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
import Element.Region as Region
import Html exposing (Html)
import Html.Events
import Http
import Json.Decode as Decode exposing (Decoder, Value, bool, float, int, list, nullable, string)
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
import LineChart.Junk as Junk
import LineChart.Legends as Legends
import LineChart.Line as Line
import Palette
import Path
import Scale exposing (BandConfig, BandScale, ContinuousScale, defaultBandConfig)
import Shape exposing (defaultPieConfig)
import Svg exposing (Svg)
import Time exposing (Month(..))
import Time.Extra as Time exposing (Parts, partsToPosix)
import TypedSvg exposing (circle, g, rect, style, svg, text_)
import TypedSvg.Attributes as Attr exposing (class, dy, stroke, textAnchor, transform, viewBox)
import TypedSvg.Attributes.InPx exposing (cx, cy, height, r, width, x, y)
import TypedSvg.Core exposing (Svg, text)
import TypedSvg.Types exposing (AnchorAlignment(..), Paint(..), Transform(..), em)


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


evictionHistoryDecoder : Decoder EvictionHistory
evictionHistoryDecoder =
    Decode.succeed EvictionHistory
        |> required "date" float
        |> required "eviction_count" float


topEvictorDecoder : Decoder TopEvictor
topEvictorDecoder =
    Decode.succeed TopEvictor
        |> required "name" string
        |> required "history" (list evictionHistoryDecoder)


posix : Decoder Time.Posix
posix =
    Decode.map Time.millisToPosix int


detainerWarrantsPerMonthDecoder : Decoder DetainerWarrantsPerMonth
detainerWarrantsPerMonthDecoder =
    Decode.succeed DetainerWarrantsPerMonth
        |> required "time" posix
        |> required "totalWarrants" int


plantiffAttorneyWarrantCountDecoder : Decoder PlantiffAttorneyWarrantCount
plantiffAttorneyWarrantCountDecoder =
    Decode.succeed PlantiffAttorneyWarrantCount
        |> required "warrant_count" int
        |> required "plantiff_attorney_name" string
        |> required "start_date" posix
        |> required "end_date" posix


type alias Model =
    { warrants : List DetainerWarrant
    , topEvictors : List TopEvictor
    , query : String
    , warrantsCursor : Maybe String
    , hovering : List EvictionHistory
    , warrantsPerMonth : List DetainerWarrantsPerMonth
    , plantiffAttorneyWarrantCounts : List PlantiffAttorneyWarrantCount
    }


type alias ApiMeta =
    { afterCursor : Maybe String
    , hasNextPage : Bool
    }


type alias ApiPage data =
    { data : List data
    , meta : ApiMeta
    }


type alias EvictionHistory =
    { date : Float
    , evictionCount : Float
    }


type alias TopEvictor =
    { name : String
    , history : List EvictionHistory
    }


type alias DetainerWarrantsPerMonth =
    { time : Time.Posix
    , totalWarrants : Int
    }


type alias PlantiffAttorneyWarrantCount =
    { warrantCount : Int
    , plantiffAttorneyName : String
    , startDate : Time.Posix
    , endDate : Time.Posix
    }


type Page
    = Welcome Model


init : Value -> ( Page, Cmd Msg )
init _ =
    ( Welcome
        { warrants = []
        , topEvictors = []
        , query = ""
        , warrantsCursor = Nothing
        , hovering = []
        , warrantsPerMonth = []
        , plantiffAttorneyWarrantCounts = []
        }
    , Cmd.batch [ getEvictionData, getDetainerWarrantsPerMonth, getPlantiffAttorneyWarrantCountPerMonth ]
    )


type Msg
    = SearchWarrants
    | InputQuery String
    | GotEvictionData (Result Http.Error (List TopEvictor))
    | GotDetainerWarrantData (Result Http.Error (List DetainerWarrantsPerMonth))
    | GotPlantiffAttorneyWarrantCount (Result Http.Error (List PlantiffAttorneyWarrantCount))
    | GotWarrants (Result Http.Error (ApiPage DetainerWarrant))
    | Hover (List EvictionHistory)


getEvictionData : Cmd Msg
getEvictionData =
    Http.get
        { url = "/api/v1/rollup/plantiffs"
        , expect = Http.expectJson GotEvictionData (list topEvictorDecoder)
        }


getWarrants : String -> Cmd Msg
getWarrants query =
    Http.get
        { url = "/api/v1/detainer-warrants/?defendant_name=" ++ query
        , expect = Http.expectJson GotWarrants detainerWarrantApiDecoder
        }


getDetainerWarrantsPerMonth : Cmd Msg
getDetainerWarrantsPerMonth =
    Http.get
        { url = "/api/v1/rollup/detainer-warrants"
        , expect = Http.expectJson GotDetainerWarrantData (list detainerWarrantsPerMonthDecoder)
        }


getPlantiffAttorneyWarrantCountPerMonth : Cmd Msg
getPlantiffAttorneyWarrantCountPerMonth =
    Http.get
        { url = "/api/v1/rollup/plantiff-attorney"
        , expect = Http.expectJson GotPlantiffAttorneyWarrantCount (list plantiffAttorneyWarrantCountDecoder)
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

                GotEvictionData result ->
                    case result of
                        Ok topEvictors ->
                            ( Welcome { model | topEvictors = topEvictors }, Cmd.none )

                        Err errMsg ->
                            ( Welcome model, Cmd.none )

                GotWarrants result ->
                    case result of
                        Ok detainerWarrantsPage ->
                            ( Welcome { model | warrants = detainerWarrantsPage.data, warrantsCursor = detainerWarrantsPage.meta.afterCursor }, Cmd.none )

                        Err errMsg ->
                            ( Welcome model, Cmd.none )

                GotDetainerWarrantData result ->
                    case result of
                        Ok warrantsPerMonth ->
                            ( Welcome { model | warrantsPerMonth = warrantsPerMonth }, Cmd.none )

                        Err errMsg ->
                            ( Welcome model, Cmd.none )

                GotPlantiffAttorneyWarrantCount result ->
                    case result of
                        Ok counts ->
                            ( Welcome { model | plantiffAttorneyWarrantCounts = counts }, Cmd.none )

                        Err errMsg ->
                            ( Welcome model, Cmd.none )

                Hover hovering ->
                    ( Welcome { model | hovering = hovering }, Cmd.none )



-- VIEW


navBarLink { url, text } =
    Element.link
        [ Element.height fill
        , Font.center
        , Element.width (Element.px 200)
        , Element.mouseOver [ Background.color Palette.redLight ]
        , Element.centerY
        , Element.centerX
        , Font.center
        , Font.size 20
        , Font.semiBold
        ]
        { url = url
        , label = Element.row [ Element.centerX ] [ Element.text text ]
        }


navBar : Element Msg
navBar =
    Element.wrappedRow
        [ Border.color Palette.black
        , Border.widthEach { bottom = 2, top = 0, left = 0, right = 0 }
        , Element.padding 5
        , Element.width (Element.fill |> Element.maximum 1200 |> Element.minimum 400)
        , Element.centerX
        , Element.centerY
        , Element.spacing 50
        ]
        [ redDoor
        , Element.column [ Element.width fill, Element.height fill, Element.centerY ]
            [ Element.row [ Element.centerY, Element.height fill, Element.spaceEvenly, Element.width (fill |> Element.maximum 500 |> Element.minimum 400) ]
                [ navBarLink
                    { url = "/about"
                    , text = "About"
                    }
                , navBarLink
                    { url = "/warrant-lookup"
                    , text = "Warrant Lookup"
                    }
                , navBarLink { url = "/trends", text = "Trends" }
                , navBarLink { url = "/actions", text = "Actions" }
                ]
            ]
        ]


redDoorWidth =
    50


redDoorHeight =
    75


redDoorFrame =
    10


redDoor : Element Msg
redDoor =
    Element.column [ Element.width Element.shrink ]
        [ Element.row [ Element.inFront logo, Element.centerX, Element.width (Element.px (redDoorWidth + 34)), Element.height (Element.px (30 + redDoorHeight)) ]
            [ Element.el [ Element.alignRight, Element.width (Element.px redDoorWidth), Element.height (Element.px redDoorHeight) ]
                (Element.html
                    (svg [ viewBox 0 0 redDoorWidth redDoorHeight ]
                        [ rect [ x 0, y 0, width redDoorWidth, height redDoorHeight, Attr.fill <| Paint Color.red ] []
                        , g []
                            [ rect [ x 13, y 17, Attr.fill <| Paint Color.black, width redDoorFrame, height redDoorFrame ]
                                []
                            , rect [ x 27, y 17, Attr.fill <| Paint Color.black, width redDoorFrame, height redDoorFrame ]
                                []
                            , rect [ x 13, y 32, Attr.fill <| Paint Color.black, width redDoorFrame, height redDoorFrame ]
                                []
                            , rect [ x 27, y 32, Attr.fill <| Paint Color.black, width redDoorFrame, height redDoorFrame ]
                                []
                            ]
                        , g []
                            [ circle [ cx 42, cy 50, Attr.fill <| Paint Color.black, r 3 ] [] ]
                        ]
                    )
                )
            ]
        ]


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
        , Font.semiBold
        , Border.solid
        , Border.color Palette.grayLight
        , Border.widthEach { bottom = 1, left = 0, right = 0, top = 0 }
        ]
        [ Element.text text ]


viewWarrants : Model -> Element Msg
viewWarrants model =
    Element.table [ Font.size 14 ]
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
        [ --Element.width fill
          Element.spacing 10
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


logo : Element Msg
logo =
    Element.textColumn [ Element.width Element.shrink, Element.alignBottom ]
        [ Element.paragraph [ Font.color Palette.red ] [ Element.text "Red" ]
        , Element.paragraph [] [ Element.text "Door" ]
        , Element.paragraph [] [ Element.text "Collective" ]
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
        [ Element.padding 20
        , Font.size 14
        ]
        (Element.column
            [ Element.width fill
            , Element.spacing 20
            ]
            [ navBar
            , Element.row
                [ Element.centerX
                , Element.width (fill |> Element.maximum 1000)
                ]
                [ Element.column
                    [ Element.spacing 30
                    , Element.centerX
                    , Element.width fill
                    ]
                    [ Element.row []
                        [ chart model ]
                    , Element.row []
                        [ viewDetainerWarrantsHistory model.warrantsPerMonth
                        ]
                    , Element.row [ Element.width fill ]
                        [ viewPlantiffAttorneyChart model.plantiffAttorneyWarrantCounts ]
                    , Element.row [ Element.height (Element.px 30) ] []
                    , Element.row [ Font.size 20, Element.width (fill |> Element.maximum 1000 |> Element.minimum 400) ]
                        [ Element.column [ Element.centerX ]
                            [ Element.row [ Element.centerX, Font.center ] [ Element.text "Find your Detainer Warrant case" ]
                            , viewSearchBar model
                            , Element.row [ Element.centerX, Element.width (fill |> Element.maximum 1000 |> Element.minimum 400) ]
                                (if List.isEmpty model.warrants then
                                    []

                                 else
                                    [ viewWarrants model ]
                                )
                            ]
                        ]
                    , Element.row [ Region.footer, Element.centerX ]
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
                    ]
                ]
            ]
        )


viewTopEvictorLine : (String -> List EvictionHistory -> LineChart.Series EvictionHistory) -> TopEvictor -> LineChart.Series EvictionHistory
viewTopEvictorLine toLine evictor =
    toLine evictor.name evictor.history


lines : List TopEvictor -> List (LineChart.Series EvictionHistory)
lines topEvictors =
    let
        colors =
            [ Color.orange, Color.yellow, Color.purple, Color.red, Color.darkBlue, Color.lightBlue, Color.darkGreen, Color.darkGrey, Color.lightGreen, Color.brown ]

        shapes =
            [ Dots.triangle, Dots.circle, Dots.diamond, Dots.square ]

        color =
            \index -> List.drop index colors |> List.head |> Maybe.withDefault Color.red

        shape =
            \index -> List.drop index shapes |> List.head |> Maybe.withDefault Dots.triangle
    in
    List.indexedMap (\index evictor -> viewTopEvictorLine (LineChart.line (color index) (shape index)) evictor) topEvictors


chart : Model -> Element Msg
chart model =
    Element.column [ Element.centerX ]
        [ Element.paragraph [ Region.heading 1, Font.size 20, Font.bold, Font.center ] [ Element.text "Top 10 Evictors in Davidson Co. TN by month" ]
        , Element.row []
            [ Element.html
                (LineChart.viewCustom
                    { y = Axis.default 600 "Evictions" .evictionCount
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
                    (lines model.topEvictors)
                )
            ]
        ]


viewLegends : Coordinate.System -> List (Legends.Legend msg) -> Svg.Svg msg
viewLegends system legends =
    Svg.g
        [ Junk.transform
            [ Junk.move system system.x.max system.y.max
            , Junk.offset -240 20
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


formatX : EvictionHistory -> String
formatX info =
    "Month: " ++ dateFormat (Time.millisToPosix (round info.date))


dateFormat : Time.Posix -> String
dateFormat =
    DateFormat.format [ DateFormat.dayOfMonthFixed, DateFormat.text " ", DateFormat.monthNameAbbreviated ] Time.utc


formatY : EvictionHistory -> String
formatY info =
    String.fromFloat info.evictionCount


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
        -- interval =
        --     time.interval
        -- month =
        --     { interval | unit = Tick.Month }
        label =
            Junk.label Color.black (Tick.format time)
    in
    Tick.custom
        { position = toFloat (Time.posixToMillis time.timestamp)
        , color = Color.black
        , width = 1
        , length = 7
        , grid = True
        , direction = Tick.negative
        , label = Just label
        }


xAxisConfig : Axis.Config EvictionHistory msg
xAxisConfig =
    Axis.custom
        { title = Title.default "Month"
        , variable = Just << .date
        , pixels = 1000
        , range = Range.padded 20 20
        , axisLine = AxisLine.full Color.black
        , ticks = ticksConfig
        }



-- BAR CHART


w =
    1000


h =
    600


padding : Float
padding =
    30


xScale : List DetainerWarrantsPerMonth -> BandScale Time.Posix
xScale warrants =
    List.map .time warrants
        |> Scale.band { defaultBandConfig | paddingInner = 0.1, paddingOuter = 0.2 } ( 0, w - 2 * padding )


yScale : ContinuousScale Float
yScale =
    Scale.linear ( h - 2 * padding, 0 ) ( 0, 800 )


barDateFormat : Time.Posix -> String
barDateFormat =
    DateFormat.format [ DateFormat.monthNameAbbreviated, DateFormat.text " ", DateFormat.yearNumberLastTwo ] Time.utc


xAxis : List DetainerWarrantsPerMonth -> Svg msg
xAxis warrants =
    Axis.bottom [] (Scale.toRenderable barDateFormat (xScale warrants))


yAxis : Svg msg
yAxis =
    Axis.left [ Axis.tickCount 5 ] yScale


column : BandScale Time.Posix -> DetainerWarrantsPerMonth -> Svg msg
column scale { time, totalWarrants } =
    g [ class [ "column" ] ]
        [ rect
            [ x <| Scale.convert scale time
            , y <| Scale.convert yScale (toFloat totalWarrants)
            , width <| Scale.bandwidth scale
            , height <| h - Scale.convert yScale (toFloat totalWarrants) - 2 * padding
            ]
            []
        , text_
            [ x <| Scale.convert (Scale.toRenderable barDateFormat scale) time
            , y <| Scale.convert yScale (toFloat totalWarrants) - 5
            , textAnchor AnchorMiddle
            ]
            [ text <| String.fromInt totalWarrants ]
        ]


viewDetainerWarrantsHistory : List DetainerWarrantsPerMonth -> Element msg
viewDetainerWarrantsHistory series =
    Element.column [ Element.width (Element.px w), Element.height (Element.px h), Element.spacing 20, Element.centerX ]
        [ Element.paragraph [ Region.heading 1, Font.size 20, Font.bold, Font.center ] [ Element.text "Number of detainer warrants in Davidson Co. TN by month" ]
        , Element.row [ Element.paddingXY 55 0 ]
            [ Element.html
                (svg [ viewBox 0 0 w h ]
                    [ style [] [ text """
            .column rect { fill: rgba(12, 84, 228, 0.8); }
            .column text { display: none; }
            .column:hover rect { fill: rgb(129, 169, 248); }
            .column:hover text { display: inline; }
          """ ]
                    , g [ transform [ Translate (padding - 1) (h - padding) ] ]
                        [ xAxis series ]
                    , g [ transform [ Translate (padding - 1) padding ] ]
                        [ yAxis ]
                    , g [ transform [ Translate padding padding ], class [ "series" ] ] <|
                        List.map (column (xScale series)) series
                    ]
                )
            ]
        ]


ticksConfig : Ticks.Config msg
ticksConfig =
    Ticks.timeCustom Time.utc 10 Tick.time


pieWidth =
    504


pieHeight =
    504


radius : Float
radius =
    min pieWidth pieHeight / 2


viewPieColor : Element.Color -> Element Msg
viewPieColor color =
    Element.el
        [ Background.color color
        , Border.rounded 5
        , Element.width (Element.px 20)
        , Element.height (Element.px 20)
        , Element.alignRight
        ]
        Element.none


pieLegendName : ( String, Element.Color ) -> Element Msg
pieLegendName ( name, color ) =
    Element.row [ Element.spacing 10, Element.width fill ] [ Element.column [ Element.alignLeft ] [ Element.text name ], viewPieColor color ]


pieLegend : List String -> Element Msg
pieLegend names =
    let
        legendData =
            List.map2 Tuple.pair names pieColorsAsElements
    in
    Element.column [ Font.size 18, Element.spacing 10 ] (List.map pieLegendName legendData)


pieColorsHelp toColor =
    [ toColor 176 140 212
    , toColor 166 230 235
    , toColor 180 212 140
    , toColor 247 212 163
    , toColor 212 140 149
    , toColor 220 174 90
    ]


pieColors =
    pieColorsHelp Color.rgb255


pieColorsAsElements =
    pieColorsHelp Element.rgb255


viewPlantiffAttorneyChart : List PlantiffAttorneyWarrantCount -> Element Msg
viewPlantiffAttorneyChart counts =
    let
        total =
            List.sum <| List.map .warrantCount counts

        shares =
            List.map (\stats -> ( stats.plantiffAttorneyName, toFloat stats.warrantCount / toFloat total )) counts

        pieData =
            shares |> List.map Tuple.second |> Shape.pie { defaultPieConfig | outerRadius = radius }

        colors =
            Array.fromList pieColors

        makeSlice index datum =
            Path.element (Shape.arc datum) [ Attr.fill <| Paint <| Maybe.withDefault Color.black <| Array.get index colors, stroke <| Paint <| Color.white ]

        makeLabel slice ( name, percentage ) =
            let
                ( x, y ) =
                    Shape.centroid { slice | innerRadius = radius - 120, outerRadius = radius - 40 }

                label =
                    percentage
                        * 100
                        |> String.fromFloat
                        |> String.left 4
            in
            text_
                [ transform [ Translate x y ]
                , dy (em 0.35)
                , textAnchor AnchorMiddle
                ]
                [ text (label ++ "%") ]
    in
    Element.column [ Element.padding 20, Element.spacing 20, Element.centerX, Element.width fill ]
        [ Element.paragraph [ Region.heading 1, Font.size 20, Font.bold, Font.center ] [ Element.text "Plantiff attorney listed on detainer warrants, Davidson Co. TN" ]
        , Element.row [ Element.padding 10, Element.spacing 40 ]
            [ pieLegend (List.map Tuple.first shares)
            , Element.column [ Element.width (Element.shrink |> Element.minimum pieWidth), Element.height (Element.px pieHeight) ]
                [ Element.html
                    (svg [ viewBox 0 0 pieWidth pieHeight ]
                        [ g [ transform [ Translate (pieWidth / 2) (pieHeight / 2) ] ]
                            [ g [] <| List.indexedMap makeSlice pieData
                            , g [] <| List.map2 makeLabel pieData shares
                            ]
                        ]
                    )
                ]
            ]
        ]


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
