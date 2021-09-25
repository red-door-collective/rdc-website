module Page.Index exposing (Data, Model, Msg, page)

import Array exposing (Array)
import Axis
import Browser.Navigation
import Chart as C
import Chart.Attributes as CA
import Color
import DataSource exposing (DataSource)
import DataSource.Http
import DataSource.Port
import DateFormat exposing (format, monthNameAbbreviated)
import Element exposing (Device, Element, fill, px, row)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Region as Region
import FormatNumber
import FormatNumber.Locales exposing (usLocale)
import Head
import Head.Seo as Seo
import Html exposing (Html)
import Html.Attributes as Attrs
import Json.Encode
import Log
import Logo
import OptimizedDecoder as Decode exposing (float, int, list, string)
import OptimizedDecoder.Pipeline exposing (decode, optional, required)
import Page exposing (Page, StaticPayload)
import Pages.PageUrl exposing (PageUrl)
import Pages.Secrets as Secrets
import Pages.Url
import Palette
import Path exposing (Path)
import Rest
import Rest.Endpoint as Endpoint
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
    { hovering : List EvictionHistory
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
        , image = Logo.smallImage
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
    { title = "Red Door Collective | Eviction Trends"
    , body =
        [ Element.column
            [ Element.centerX
            , Element.width (fill |> Element.maximum 1000)
            , Font.size 14
            , Element.paddingXY 5 10
            ]
            [ Element.column
                [ Element.spacing 40
                , Element.centerX
                , Element.width fill

                -- , Element.explain Debug.todo
                ]
                [ row
                    [ Element.htmlAttribute (Attrs.class "responsive-desktop")
                    ]
                    [ topEvictorsChart { width = 1000, height = 600 } model static
                    ]
                , row
                    [ Element.htmlAttribute <| Attrs.class "responsive-mobile"
                    ]
                    [ topEvictorsChart { width = 365, height = 400 } model static
                    ]
                , row [ Element.htmlAttribute (Attrs.class "responsive-desktop") ]
                    [ viewDetainerWarrantsHistory { width = 1000, height = 600 } static.data.warrantsPerMonth
                    ]
                , row [ Element.htmlAttribute (Attrs.class "responsive-mobile") ]
                    [ viewDetainerWarrantsHistory { width = 365, height = 365 } static.data.warrantsPerMonth
                    ]
                , row
                    [ Element.width fill
                    , Element.htmlAttribute <| Attrs.class "responsive-desktop"
                    ]
                    [ viewPlaintiffAttorneyChart { width = 1000, height = 600 } static.data.plaintiffAttorneyWarrantCounts ]
                , row
                    [ Element.htmlAttribute <| Attrs.class "responsive-mobile"
                    , Element.width fill
                    ]
                    [ viewPlaintiffAttorneyChart { width = 365, height = 365 } static.data.plaintiffAttorneyWarrantCounts ]
                , row [ Element.htmlAttribute <| Attrs.class "responsive-desktop", Element.centerX ]
                    [ Element.text ("Detainer Warrants updated via Red Door Collective members as of: " ++ dateFormatLong static.data.rollupMeta.lastWarrantUpdatedAt) ]
                , row
                    [ Element.width fill
                    , Element.htmlAttribute <| Attrs.class "responsive-mobile"
                    ]
                    [ Element.paragraph
                        [ Element.centerX
                        , Element.width (fill |> Element.maximum 365)
                        ]
                        [ Element.text ("Detainer Warrants updated via Red Door Collective members as of: " ++ dateFormatLong static.data.rollupMeta.lastWarrantUpdatedAt) ]
                    ]
                , row [ Element.height (Element.px 20) ] []
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
    ( { hovering = []
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


type alias EvictorData =
    List { date : Float, evictionCount : Float, name : String }



-- topEvictorsToData : List TopEvictor -> EvictorData
-- topEvictorsToData evictors =
--     List.foldl (\evictor xs -> { name = evictor.name, evictionCount = evictor.evictionCount, date = evictor.date } :: xs) evictors


topEvictorsChart : { width : Int, height : Int } -> Model -> StaticPayload Data RouteParams -> Element Msg
topEvictorsChart { width, height } model static =
    -- let
    --     topEvictors =
    --         topEvictorsToData static.data.topEvictors
    --     evictors =
    --         if width < 600 then
    --             topEvictors
    --         else
    --             topEvictors
    -- in
    Element.column [ Element.spacing 20 ]
        [ row [ Element.width fill ]
            [ Element.paragraph
                ([ Region.heading 1
                 , Font.size 20
                 , Font.bold
                 , Font.center
                 , Element.centerX
                 ]
                    ++ (if width <= 600 then
                            [ Element.width (fill |> Element.maximum 365) ]

                        else
                            [ Element.width fill ]
                       )
                )
                [ Element.text "Top 10 Evictors in Davidson Co. TN by month"
                ]
            ]
        , row []
            [ Element.el [ Element.width (px width), Element.height (px height) ]
                (Element.html
                    (C.chart
                        [ CA.height (toFloat height)
                        , CA.width (toFloat width)
                        ]
                        ([ C.xLabels
                            [ CA.format (\num -> dateFormat (Time.millisToPosix (round num)))
                            ]
                         , C.yLabels [ CA.withGrid ]
                         ]
                            ++ List.map
                                (\evictor ->
                                    C.series .date
                                        [ C.interpolated .evictionCount [] [ CA.cross, CA.borderWidth 2, CA.border "white" ]
                                            |> C.named evictor.name
                                        ]
                                        evictor.history
                                )
                                static.data.topEvictors
                            ++ [ --C.each model.hovering <|
                                 --         \p item ->
                                 --             [ C.tooltip item.date [] [] [] ]
                                 C.legendsAt .min
                                    .max
                                    [ CA.column
                                    , CA.moveRight 25
                                    , CA.spacing 5
                                    ]
                                    [ CA.width 20
                                    , CA.fontSize 12
                                    ]
                               ]
                        )
                    )
                )
            ]
        ]


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



-- BAR CHART


padding : Float
padding =
    30


type alias Datum =
    { time : Time.Posix, total : Int }


xScale : Int -> List Datum -> BandScale Time.Posix
xScale width times =
    List.map .time times
        |> Scale.band { defaultBandConfig | paddingInner = 0.1, paddingOuter = 0.2 } ( 0, toFloat width - 2 * padding )


yScale : Int -> ContinuousScale Float
yScale height =
    Scale.linear ( toFloat height - 2 * padding, 0 ) ( 0, 800 )


barDateFormat : Time.Posix -> String
barDateFormat =
    DateFormat.format [ DateFormat.monthNameAbbreviated, DateFormat.text " ", DateFormat.yearNumberLastTwo ] Time.utc


xAxis : Int -> List Datum -> Svg msg
xAxis width times =
    Axis.bottom [] (Scale.toRenderable barDateFormat (xScale width times))


yAxis : Int -> Svg msg
yAxis height =
    Axis.left [ Axis.tickCount 5 ] (yScale height)


type alias Dimensions =
    { width : Int, height : Int }


column : Dimensions -> BandScale Time.Posix -> { time : Time.Posix, total : Int } -> Svg msg
column dimens scale { time, total } =
    g [ class [ "column" ] ]
        [ rect
            [ x <| Scale.convert scale time
            , y <| Scale.convert (yScale dimens.height) (toFloat total)
            , width <| Scale.bandwidth scale
            , height <| toFloat dimens.height - Scale.convert (yScale dimens.height) (toFloat total) - 2 * padding
            ]
            []
        , text_
            [ x <| Scale.convert (Scale.toRenderable barDateFormat scale) time
            , y <| Scale.convert (yScale dimens.height) (toFloat total) - 5
            , textAnchor AnchorMiddle
            ]
            [ text <| String.fromInt total ]
        ]


viewDetainerWarrantsHistory : { width : Int, height : Int } -> List DetainerWarrantsPerMonth -> Element msg
viewDetainerWarrantsHistory ({ width, height } as dimens) allWarrants =
    let
        warrants =
            if width < 600 then
                List.drop 6 allWarrants

            else
                allWarrants

        series =
            List.map (\s -> { time = s.time, total = s.totalWarrants }) warrants
    in
    Element.column [ Element.spacing 10, Element.centerX, Element.width fill ]
        [ row [ Element.width fill ]
            [ Element.paragraph
                ([ Region.heading 1
                 , Font.size 20
                 , Font.bold
                 , Font.center
                 ]
                    ++ (if width <= 600 then
                            [ Element.width (fill |> Element.maximum 365) ]

                        else
                            [ Element.width fill ]
                       )
                )
                [ Element.text "Number of detainer warrants in Davidson Co. TN by month" ]
            ]
        , row [ Element.width fill ]
            [ Element.column [ Element.width (Element.shrink |> Element.minimum width), Element.height (Element.px height) ]
                [ Element.html
                    (svg [ viewBox 0 0 (toFloat width) (toFloat height) ]
                        [ style [] [ text """
            .column rect { fill: rgba(12, 84, 228, 0.8); }
            .column text { display: none; }
            .column:hover rect { fill: rgb(129, 169, 248); }
            .column:hover text { display: inline; }
          """ ]
                        , g [ transform [ Translate (padding - 1) (toFloat height - padding) ] ]
                            [ xAxis width series ]
                        , g [ transform [ Translate (padding - 1) padding ] ]
                            [ yAxis height ]
                        , g [ transform [ Translate padding padding ], class [ "series" ] ] <|
                            List.map (column dimens (xScale width series)) series
                        ]
                    )
                ]
            ]
        ]


calcRadius : Float -> Float -> Float
calcRadius w h =
    min w h / 2


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
    row [ Element.spacing 10, Element.width fill ] [ Element.column [ Element.alignLeft ] [ Element.text name ], viewPieColor color ]


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


viewPlaintiffAttorneyChart : { width : Int, height : Int } -> List PlaintiffAttorneyWarrantCount -> Element Msg
viewPlaintiffAttorneyChart { width, height } counts =
    let
        radius =
            calcRadius (toFloat width) (toFloat height)

        total =
            List.sum <| List.map .warrantCount counts

        shares =
            List.map (\stats -> ( stats.plaintiffAttorneyName, toFloat stats.warrantCount / toFloat total )) counts

        pieData =
            shares |> List.map Tuple.second |> Shape.pie { defaultPieConfig | outerRadius = radius }

        colors =
            Array.fromList pieColors

        makeSlice index datum =
            SvgPath.element (Shape.Patch.Pie.arc datum)
                [ Attr.fill <|
                    Paint <|
                        Maybe.withDefault Color.black <|
                            Array.get index colors
                , stroke <| Paint <| Color.white
                ]

        makeLabel slice ( name, percentage ) =
            let
                ( x, y ) =
                    Shape.centroid
                        { slice
                            | innerRadius = radius - 120
                            , outerRadius = radius - 40
                        }

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
    Element.column [ Element.spacing 10, Element.centerX, Element.width fill ]
        [ row [ Element.width fill ]
            [ Element.paragraph
                ([ Region.heading 1
                 , Font.size 20
                 , Font.bold
                 , Font.center
                 ]
                    ++ (if width <= 600 then
                            [ Element.width (fill |> Element.maximum 365) ]

                        else
                            [ Element.width fill ]
                       )
                )
                [ Element.text "Plaintiff attorney listed on detainer warrants, Davidson Co. TN" ]
            ]
        , Element.wrappedRow [ Element.spacing 10 ]
            [ pieLegend (List.map Tuple.first shares)
            , Element.column
                [ Element.width (Element.shrink |> Element.minimum width)
                , Element.height (Element.px height)
                ]
                [ Element.html
                    (svg [ viewBox 0 0 (toFloat width) (toFloat height) ]
                        [ g [ transform [ Translate (toFloat width / 2) (toFloat height / 2) ] ]
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
