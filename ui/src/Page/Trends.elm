module Page.Trends exposing (Model, Msg, init, subscriptions, toSession, update, view)

import Api
import Array exposing (Array)
import Axis
import Color
import DateFormat exposing (format, monthNameAbbreviated)
import Element exposing (Device, Element, fill)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Region as Region
import Html exposing (Html)
import Http
import Json.Decode as Decode exposing (list)
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
import Session exposing (Session)
import Shape exposing (defaultPieConfig)
import Stats exposing (DetainerWarrantsPerMonth, EvictionHistory, PlantiffAttorneyWarrantCount, TopEvictor)
import Svg exposing (Svg)
import Time exposing (Month(..))
import Time.Extra as Time exposing (Parts, partsToPosix)
import TypedSvg exposing (circle, g, rect, style, svg, text_)
import TypedSvg.Attributes as Attr exposing (class, dy, stroke, textAnchor, transform, viewBox)
import TypedSvg.Attributes.InPx exposing (cx, cy, height, r, width, x, y)
import TypedSvg.Core exposing (Svg, text)
import TypedSvg.Types exposing (AnchorAlignment(..), Paint(..), Transform(..), em)


type alias Model =
    { session : Session
    , topEvictors : List TopEvictor
    , hovering : List EvictionHistory
    , warrantsPerMonth : List DetainerWarrantsPerMonth
    , plantiffAttorneyWarrantCounts : List PlantiffAttorneyWarrantCount
    , rollupMeta : Maybe Api.RollupMetadata
    }


getEvictionData : Cmd Msg
getEvictionData =
    Http.get
        { url = "/api/v1/rollup/plantiffs"
        , expect = Http.expectJson GotEvictionData (list Stats.topEvictorDecoder)
        }


getDetainerWarrantsPerMonth : Cmd Msg
getDetainerWarrantsPerMonth =
    Http.get
        { url = "/api/v1/rollup/detainer-warrants"
        , expect = Http.expectJson GotDetainerWarrantData (list Stats.detainerWarrantsPerMonthDecoder)
        }


getPlantiffAttorneyWarrantCountPerMonth : Cmd Msg
getPlantiffAttorneyWarrantCountPerMonth =
    Http.get
        { url = "/api/v1/rollup/plantiff-attorney"
        , expect = Http.expectJson GotPlantiffAttorneyWarrantCount (list Stats.plantiffAttorneyWarrantCountDecoder)
        }


getApiMetadata : Cmd Msg
getApiMetadata =
    Http.get
        { url = "/api/v1/rollup/meta"
        , expect = Http.expectJson GotApiMeta Api.rollupMetadataDecoder
        }


init : Session -> ( Model, Cmd Msg )
init session =
    ( { session = session
      , topEvictors = []
      , hovering = []
      , warrantsPerMonth = []
      , plantiffAttorneyWarrantCounts = []
      , rollupMeta = Nothing
      }
    , Cmd.batch
        [ getEvictionData
        , getDetainerWarrantsPerMonth
        , getPlantiffAttorneyWarrantCountPerMonth
        , getApiMetadata
        ]
    )


type Msg
    = GotEvictionData (Result Http.Error (List TopEvictor))
    | GotDetainerWarrantData (Result Http.Error (List DetainerWarrantsPerMonth))
    | GotPlantiffAttorneyWarrantCount (Result Http.Error (List PlantiffAttorneyWarrantCount))
    | GotApiMeta (Result Http.Error Api.RollupMetadata)
    | Hover (List EvictionHistory)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GotEvictionData result ->
            case result of
                Ok topEvictors ->
                    ( { model | topEvictors = topEvictors }, Cmd.none )

                Err errMsg ->
                    ( model, Cmd.none )

        GotDetainerWarrantData result ->
            case result of
                Ok warrantsPerMonth ->
                    ( { model | warrantsPerMonth = warrantsPerMonth }, Cmd.none )

                Err errMsg ->
                    ( model, Cmd.none )

        GotPlantiffAttorneyWarrantCount result ->
            case result of
                Ok counts ->
                    ( { model | plantiffAttorneyWarrantCounts = counts }, Cmd.none )

                Err errMsg ->
                    ( model, Cmd.none )

        GotApiMeta result ->
            case result of
                Ok rollupMeta ->
                    ( { model | rollupMeta = Just rollupMeta }, Cmd.none )

                Err errMsg ->
                    ( model, Cmd.none )

        Hover hovering ->
            ( { model | hovering = hovering }, Cmd.none )


view : Device -> Model -> { title : String, content : Element Msg }
view device model =
    { title = "Trends"
    , content =
        Element.column
            [ Element.centerX
            , Element.width (fill |> Element.maximum 1000)
            , Element.padding 20
            , Font.size 14
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
                , case model.rollupMeta of
                    Just rollupMeta ->
                        Element.row [ Element.centerX ]
                            [ Element.text ("Detainer Warrants updated via Red Door Collective members as of: " ++ dateFormatLong rollupMeta.lastWarrantUpdatedAt) ]

                    Nothing ->
                        Element.none
                ]
            ]
    }


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


dateFormatLong : Time.Posix -> String
dateFormatLong =
    DateFormat.format [ DateFormat.monthNameFull, DateFormat.text " ", DateFormat.dayOfMonthNumber, DateFormat.text ", ", DateFormat.yearNumber ] Time.utc


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
    Element.column [ Element.padding 20, Element.spacing 20, Element.centerX, Element.width fill ]
        [ Element.paragraph [ Region.heading 1, Font.size 20, Font.bold, Font.center ] [ Element.text "Number of detainer warrants in Davidson Co. TN by month" ]
        , Element.row [ Element.paddingXY 35 0 ]
            [ Element.column [ Element.width (Element.shrink |> Element.minimum w), Element.height (Element.px h) ]
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


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- EXPORT


toSession : Model -> Session
toSession model =
    model.session
