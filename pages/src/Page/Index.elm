module Page.Index exposing (Data, Model, Msg, page)

import Api.Endpoint as Endpoint
import Array exposing (Array)
import Axis
import Browser.Navigation
import Color
import DataSource exposing (DataSource)
import DataSource.Http
import DataSource.Port
import DateFormat exposing (format, monthNameAbbreviated)
import Element exposing (Device, Element, fill)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Region as Region
import FormatNumber
import FormatNumber.Locales exposing (usLocale)
import Head
import Head.Seo as Seo
import Html exposing (Html)
import Json.Encode
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
import Log
import OptimizedDecoder as Decode exposing (float, int, list, string)
import OptimizedDecoder.Pipeline exposing (decode, optional, required)
import Page exposing (Page, StaticPayload)
import Pages.PageUrl exposing (PageUrl)
import Pages.Secrets as Secrets
import Pages.Url
import Palette
import Path exposing (Path)
import Rest
import Rest.Static exposing (AmountAwardedMonth, DetainerWarrantsPerMonth, EvictionHistory, PlaintiffAttorneyWarrantCount, RollupMetadata, TopEvictor)
import Rollbar exposing (Rollbar)
import Runtime exposing (Runtime)
import Scale exposing (BandConfig, BandScale, ContinuousScale, defaultBandConfig)
import Session exposing (Session)
import Shape exposing (defaultPieConfig)
import Shape.Patch.Pie
import Shared
import Svg exposing (Svg)
import Svg.Path as SvgPath
import Time exposing (Month(..))
import Time.Extra as Time exposing (Parts, partsToPosix)
import TypedSvg exposing (circle, g, rect, style, svg, text_)
import TypedSvg.Attributes as Attr exposing (class, dy, stroke, textAnchor, transform, viewBox)
import TypedSvg.Attributes.InPx exposing (cx, cy, height, r, width, x, y)
import TypedSvg.Core exposing (Svg, text)
import TypedSvg.Types exposing (AnchorAlignment(..), Paint(..), Transform(..), em)
import View exposing (View)


type alias Model =
    { runtime : Runtime
    , hovering : List EvictionHistory
    , hoveringAmounts : List AmountAwardedMonth
    }


type alias RouteParams =
    {}


page : Page.PageWithState RouteParams Data Model Msg
page =
    Page.single
        { head = head
        , data = data
        }
        |> Page.buildWithLocalState
            { init = init
            , update = update
            , view = view
            , subscriptions = subscriptions
            }


data : DataSource Data
data =
    DataSource.Port.get "environmentVariable"
        (Json.Encode.string "ENV")
        Runtime.decodeEnvironment
        |> DataSource.andThen
            (\env ->
                let
                    domain =
                        Runtime.domain env
                in
                DataSource.map5 Data
                    (topEvictorsData domain)
                    (detainerWarrantsPerMonth domain)
                    (plaintiffAttorneyWarrantCountPerMonth domain)
                    (amountAwardedHistoryData domain)
                    (apiMetadata domain)
            )


head :
    StaticPayload Data RouteParams
    -> List Head.Tag
head static =
    Seo.summary
        { canonicalUrlOverride = Nothing
        , siteName = "Red Door Collective"
        , image =
            { url = Pages.Url.external "TODO"
            , alt = "Red Door Collective Logo"
            , dimensions = Nothing
            , mimeType = Nothing
            }
        , description = "Organizing Nashville tenants for dignified housing."
        , locale = Nothing
        , title = "Red Door Collective"
        }
        |> Seo.website


type alias Data =
    { topEvictors : List TopEvictor
    , warrantsPerMonth : List DetainerWarrantsPerMonth
    , plaintiffAttorneyWarrantCounts : List PlaintiffAttorneyWarrantCount
    , amountAwardedHistory : List Rest.Static.AmountAwardedMonth
    , rollupMeta : RollupMetadata
    }


view :
    Maybe PageUrl
    -> Shared.Model
    -> Model
    -> StaticPayload Data RouteParams
    -> View Msg
view maybeUrl sharedModel model static =
    { title = "Trends"
    , body =
        [ Element.column
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
                    [ chart model static ]
                , Element.row []
                    [ viewDetainerWarrantsHistory static.data.warrantsPerMonth
                    ]
                , Element.row [ Element.width fill ]
                    [ viewPlaintiffAttorneyChart static.data.plaintiffAttorneyWarrantCounts ]
                , Element.row [ Element.height (Element.px 30) ] []
                , Element.row []
                    [ amountAwardedChart model static.data.amountAwardedHistory
                    ]
                , Element.row [ Element.centerX ]
                    [ Element.text ("Detainer Warrants updated via Red Door Collective members as of: " ++ dateFormatLong static.data.rollupMeta.lastWarrantUpdatedAt) ]
                ]
            ]
        ]
    }


topEvictorsData : String -> DataSource (List TopEvictor)
topEvictorsData domain =
    DataSource.Http.get (Secrets.succeed (Rest.Static.api domain "plaintiffs"))
        (list
            (decode TopEvictor
                |> required "name" string
                |> required "history"
                    (list
                        (decode EvictionHistory
                            |> required "date" float
                            |> required "eviction_count" float
                        )
                    )
            )
        )


detainerWarrantsPerMonth : String -> DataSource (List DetainerWarrantsPerMonth)
detainerWarrantsPerMonth domain =
    DataSource.Http.get (Secrets.succeed (Rest.Static.api domain "detainer-warrants"))
        (list Rest.Static.detainerWarrantsPerMonthDecoder)


plaintiffAttorneyWarrantCountPerMonth : String -> DataSource (List PlaintiffAttorneyWarrantCount)
plaintiffAttorneyWarrantCountPerMonth domain =
    DataSource.Http.get (Secrets.succeed (Rest.Static.api domain "plaintiff-attorney"))
        (list Rest.Static.plaintiffAttorneyWarrantCountDecoder)


amountAwardedHistoryData : String -> DataSource (List AmountAwardedMonth)
amountAwardedHistoryData domain =
    DataSource.Http.get (Secrets.succeed (Rest.Static.api domain "amount-awarded/history"))
        (Decode.field "data" (list Rest.Static.amountAwardedMonthDecoder))


apiMetadata : String -> DataSource RollupMetadata
apiMetadata domain =
    DataSource.Http.get (Secrets.succeed (Rest.Static.api domain "meta"))
        Rest.Static.rollupMetadataDecoder


init :
    Maybe PageUrl
    -> Shared.Model
    -> StaticPayload Data RouteParams
    -> ( Model, Cmd Msg )
init pageUrl sharedModel payload =
    ( { runtime = Runtime.default
      , hovering = []
      , hoveringAmounts = []
      }
    , Cmd.none
    )


type Msg
    = Hover (List EvictionHistory)
    | HoverAmounts (List AmountAwardedMonth)
    | NoOp


update :
    PageUrl
    -> Maybe Browser.Navigation.Key
    -> Shared.Model
    -> StaticPayload Data RouteParams
    -> Msg
    -> Model
    -> ( Model, Cmd Msg )
update pageUrl navKey sharedModel payload msg model =
    case msg of
        Hover hovering ->
            ( { model | hovering = hovering }, Cmd.none )

        HoverAmounts hovering ->
            ( { model | hoveringAmounts = hovering }, Cmd.none )

        NoOp ->
            ( model, Cmd.none )


error : Rollbar -> String -> Cmd Msg
error rollbar report =
    Log.error rollbar (\_ -> NoOp) report


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


chart : Model -> StaticPayload Data RouteParams -> Element Msg
chart model static =
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
                    (lines static.data.topEvictors)
                )
            ]
        ]


viewAmountAwardedLine : (String -> List AmountAwardedMonth -> LineChart.Series AmountAwardedMonth) -> List AmountAwardedMonth -> LineChart.Series AmountAwardedMonth
viewAmountAwardedLine toLine amounts =
    toLine "Amount awarded" amounts


amountAwardedLines : List AmountAwardedMonth -> List (LineChart.Series AmountAwardedMonth)
amountAwardedLines amounts =
    let
        colors =
            [ Color.lightGreen ]

        shapes =
            [ Dots.triangle, Dots.circle, Dots.diamond, Dots.square ]

        color =
            \index -> List.drop index colors |> List.head |> Maybe.withDefault Color.red

        shape =
            \index -> List.drop index shapes |> List.head |> Maybe.withDefault Dots.triangle
    in
    [ viewAmountAwardedLine (LineChart.line (color 0) (shape 0)) amounts ]


amountAwardedChart : Model -> List AmountAwardedMonth -> Element Msg
amountAwardedChart model amountAwardedHistory =
    Element.column [ Element.centerX ]
        [ Element.paragraph [ Region.heading 1, Font.size 20, Font.bold, Font.center ] [ Element.text "Amount awarded in fees to plaintiffs" ]
        , Element.row []
            [ Element.html
                (LineChart.viewCustom
                    { y =
                        Axis.custom
                            { title = Title.default "Awards"
                            , variable = Just << toFloat << .totalAmount
                            , pixels = 600
                            , range = Range.padded 20 20
                            , axisLine = AxisLine.full Color.black
                            , ticks =
                                Ticks.floatCustom 7
                                    (\number ->
                                        Tick.custom
                                            { position = number
                                            , color = Color.black
                                            , width = 1
                                            , length = 7
                                            , grid = True
                                            , direction = Tick.positive
                                            , label = Just (Junk.label Color.black (formatDollars number))
                                            }
                                    )
                            }
                    , x = amountsXAxisConfig --Axis.time Time.utc 2000 "Date" .date
                    , container = Container.styled "line-chart-2" [ ( "font-family", "monospace" ) ]
                    , interpolation = Interpolation.default
                    , intersection = Intersection.default
                    , legends = Legends.groupedCustom 30 viewLegends
                    , events = Events.hoverMany HoverAmounts
                    , junk = Junk.hoverMany model.hoveringAmounts formatXAmounts formatYAmounts
                    , grid = Grid.default
                    , area = Area.default
                    , line = Line.default
                    , dots = Dots.hoverMany model.hoveringAmounts
                    }
                    (amountAwardedLines amountAwardedHistory)
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


formatXAmounts : AmountAwardedMonth -> String
formatXAmounts info =
    "Month: " ++ dateFormat info.time


formatYAmounts : AmountAwardedMonth -> String
formatYAmounts info =
    formatDollars (toFloat info.totalAmount)


formatDollars number =
    "$" ++ FormatNumber.format usLocale number


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


amountsXAxisConfig : Axis.Config AmountAwardedMonth msg
amountsXAxisConfig =
    Axis.custom
        { title = Title.default "Month"
        , variable = Just << toFloat << Time.posixToMillis << .time
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


type alias Datum =
    { time : Time.Posix, total : Int }


xScale : List Datum -> BandScale Time.Posix
xScale times =
    List.map .time times
        |> Scale.band { defaultBandConfig | paddingInner = 0.1, paddingOuter = 0.2 } ( 0, w - 2 * padding )


yScale : ContinuousScale Float
yScale =
    Scale.linear ( h - 2 * padding, 0 ) ( 0, 800 )


barDateFormat : Time.Posix -> String
barDateFormat =
    DateFormat.format [ DateFormat.monthNameAbbreviated, DateFormat.text " ", DateFormat.yearNumberLastTwo ] Time.utc


xAxis : List Datum -> Svg msg
xAxis times =
    Axis.bottom [] (Scale.toRenderable barDateFormat (xScale times))


yAxis : Svg msg
yAxis =
    Axis.left [ Axis.tickCount 5 ] yScale


column : BandScale Time.Posix -> { time : Time.Posix, total : Int } -> Svg msg
column scale { time, total } =
    g [ class [ "column" ] ]
        [ rect
            [ x <| Scale.convert scale time
            , y <| Scale.convert yScale (toFloat total)
            , width <| Scale.bandwidth scale
            , height <| h - Scale.convert yScale (toFloat total) - 2 * padding
            ]
            []
        , text_
            [ x <| Scale.convert (Scale.toRenderable barDateFormat scale) time
            , y <| Scale.convert yScale (toFloat total) - 5
            , textAnchor AnchorMiddle
            ]
            [ text <| String.fromInt total ]
        ]


viewAmountAwardedHistory : List AmountAwardedMonth -> Element msg
viewAmountAwardedHistory amounts =
    let
        series =
            List.map (\s -> { time = s.time, total = s.totalAmount }) amounts
    in
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


viewDetainerWarrantsHistory : List DetainerWarrantsPerMonth -> Element msg
viewDetainerWarrantsHistory warrants =
    let
        series =
            List.map (\s -> { time = s.time, total = s.totalWarrants }) warrants
    in
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


viewPlaintiffAttorneyChart : List PlaintiffAttorneyWarrantCount -> Element Msg
viewPlaintiffAttorneyChart counts =
    let
        total =
            List.sum <| List.map .warrantCount counts

        shares =
            List.map (\stats -> ( stats.plaintiffAttorneyName, toFloat stats.warrantCount / toFloat total )) counts

        pieData =
            shares |> List.map Tuple.second |> Shape.pie { defaultPieConfig | outerRadius = radius }

        colors =
            Array.fromList pieColors

        makeSlice index datum =
            SvgPath.element (Shape.Patch.Pie.arc datum) [ Attr.fill <| Paint <| Maybe.withDefault Color.black <| Array.get index colors, stroke <| Paint <| Color.white ]

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
        [ Element.paragraph [ Region.heading 1, Font.size 20, Font.bold, Font.center ] [ Element.text "Plaintiff attorney listed on detainer warrants, Davidson Co. TN" ]
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


subscriptions : Maybe PageUrl -> RouteParams -> Path -> Model -> Sub Msg
subscriptions pageUrl params path model =
    Sub.none
