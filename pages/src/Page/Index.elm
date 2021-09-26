module Page.Index exposing (Data, Model, Msg, page)

import Array exposing (Array)
import Browser.Navigation
import Chart as C
import Chart.Attributes as CA
import Chart.Events as CE
import Chart.Item as CI
import Color
import DataSource exposing (DataSource)
import DataSource.Http
import DataSource.Port
import DateFormat exposing (format, monthNameAbbreviated)
import Dict
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
import List.Extra
import Log
import Logo
import OptimizedDecoder as Decode exposing (float, int, list, string)
import OptimizedDecoder.Pipeline exposing (decode, optional, required)
import Page exposing (Page, StaticPayload)
import Pages.PageUrl exposing (PageUrl)
import Pages.Secrets as Secrets
import Path exposing (Path)
import Rest
import Rest.Endpoint as Endpoint
import Rest.Static exposing (AmountAwardedMonth, DetainerWarrantsPerMonth, EvictionHistory, PlaintiffAttorneyWarrantCount, RollupMetadata, TopEvictor)
import Rollbar exposing (Rollbar)
import Runtime exposing (Runtime)
import Session exposing (Session)
import Shared
import Svg exposing (Svg)
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
    , hoveringOnBar : List (CI.One Datum CI.Bar)
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
        , title = title
        }
        |> Seo.website


type alias Data =
    { topEvictors : List TopEvictor
    , warrantsPerMonth : List DetainerWarrantsPerMonth
    , plaintiffAttorneyWarrantCounts : List PlaintiffAttorneyWarrantCount
    , amountAwardedHistory : List Rest.Static.AmountAwardedMonth
    , rollupMeta : RollupMetadata
    }


title =
    "Red Door Collective"


view :
    Maybe PageUrl
    -> Shared.Model
    -> Model
    -> StaticPayload Data RouteParams
    -> View Msg
view maybeUrl sharedModel model static =
    { title = title
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
                    [ viewDetainerWarrantsHistory model { width = 1000, height = 600 } static.data.warrantsPerMonth
                    ]
                , row [ Element.htmlAttribute (Attrs.class "responsive-mobile") ]
                    [ viewDetainerWarrantsHistory model { width = 365, height = 365 } static.data.warrantsPerMonth
                    ]
                , row
                    [ Element.width fill
                    , Element.htmlAttribute <| Attrs.class "responsive-desktop"
                    ]
                    [ viewPlaintiffAttorneyChart model { width = 1000, height = 600 } static.data.plaintiffAttorneyWarrantCounts ]
                , row
                    [ Element.htmlAttribute <| Attrs.class "responsive-mobile"
                    , Element.width fill
                    ]
                    [ viewPlaintiffAttorneyChart model { width = 365, height = 365 } static.data.plaintiffAttorneyWarrantCounts ]
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
      , hoveringOnBar = []
      }
    , Cmd.none
    )


type Msg
    = Hover (List EvictionHistory)
    | HoverAmounts (List AmountAwardedMonth)
    | HoverOnBar (List (CI.One Datum CI.Bar))
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

        HoverOnBar hovering ->
            ( { model | hoveringOnBar = hovering }, Cmd.none )

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


topEvictorsChart : Dimensions -> Model -> StaticPayload Data RouteParams -> Element Msg
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
    { time : Time.Posix, total : Float }


barDateFormat : Time.Posix -> String
barDateFormat =
    DateFormat.format [ DateFormat.monthNameAbbreviated, DateFormat.text " ", DateFormat.yearNumberLastTwo ] Time.utc


type alias Dimensions =
    { width : Int, height : Int }


viewBarChart : Model -> Dimensions -> List DetainerWarrantsPerMonth -> Element Msg
viewBarChart model dimens warrants =
    let
        series =
            List.map (\s -> { time = s.time, total = toFloat s.totalWarrants }) warrants
    in
    Element.html <|
        C.chart
            [ CA.height (toFloat dimens.height)
            , CA.width (toFloat dimens.width)
            , CE.onMouseMove HoverOnBar (CE.getNearest CI.bars)
            , CE.onMouseLeave (HoverOnBar [])
            , CA.padding { top = 10, bottom = 0, left = 0, right = 0 }
            ]
            [ C.yLabels [ CA.withGrid ]
            , C.bars
                [ CA.roundTop 0.2
                , CA.margin 0.1
                , CA.spacing 0.15
                ]
                [ C.bar .total [ CA.borderWidth 1 ]
                    |> C.named "Evictions"
                    |> C.amongst model.hoveringOnBar (\_ -> [ CA.highlight 0.25 ])
                ]
                series
            , C.barLabels [ CA.moveUp 10 ]
            , C.binLabels (barDateFormat << .time) [ CA.moveDown 15 ]
            , C.each model.hoveringOnBar <|
                \p item ->
                    [ C.tooltip item [] [] [] ]
            ]


viewDetainerWarrantsHistory : Model -> Dimensions -> List DetainerWarrantsPerMonth -> Element Msg
viewDetainerWarrantsHistory model ({ width, height } as dimens) allWarrants =
    let
        warrants =
            if width < 600 then
                List.drop 6 allWarrants

            else
                allWarrants
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
            [ viewBarChart model dimens warrants
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


emptyStack =
    { name = "UNKNOWN", count = 0.0 }


emptyStacks =
    { first = emptyStack
    , second = emptyStack
    , third = emptyStack
    , fourth = emptyStack
    , fifth = emptyStack
    , other = emptyStack
    }


viewPlaintiffShareChart : Model -> Dimensions -> List PlaintiffAttorneyWarrantCount -> Element Msg
viewPlaintiffShareChart model dimens counts =
    let
        ( other, top5Plaintiffs ) =
            List.partition ((==) "ALL OTHER" << .plaintiffAttorneyName) counts

        byCount =
            counts
                |> List.map (\r -> ( toFloat r.warrantCount, r.plaintiffAttorneyName ))
                |> Dict.fromList

        top5 =
            top5Plaintiffs
                |> List.Extra.indexedFoldl
                    (\i r acc ->
                        let
                            datum =
                                { name = r.plaintiffAttorneyName, count = toFloat r.warrantCount }
                        in
                        { acc
                            | first =
                                if i == 0 then
                                    datum

                                else
                                    acc.first
                            , second =
                                if i == 1 then
                                    datum

                                else
                                    acc.second
                            , third =
                                if i == 2 then
                                    datum

                                else
                                    acc.third
                            , fourth =
                                if i == 3 then
                                    datum

                                else
                                    acc.fourth
                            , fifth =
                                if i == 4 then
                                    datum

                                else
                                    acc.fifth
                            , other =
                                if r.plaintiffAttorneyName == "ALL OTHER" then
                                    datum

                                else
                                    acc.other
                        }
                    )
                    emptyStacks

        series =
            [ top5
            , { emptyStacks | other = { name = "ALL OTHER", count = Maybe.withDefault 0.0 <| Maybe.map (toFloat << .warrantCount) <| List.head other } }
            ]

        total =
            List.map (toFloat << .warrantCount) counts
                |> List.sum

        toPercent y =
            round (100 * y / total)
    in
    Element.html
        (C.chart
            [ CA.height (toFloat dimens.height)
            , CA.width (toFloat dimens.width)
            ]
            [ C.yLabels []
            , C.bars
                []
                [ C.stacked
                    [ C.bar (.count << .other)
                        []
                        |> C.named (Maybe.withDefault "Meh" <| Maybe.map (.name << .other) <| List.head series)
                    , C.bar (.count << .fifth) []
                        |> C.named (Maybe.withDefault "Meh" <| Maybe.map (.name << .fifth) <| List.head series)
                    , C.bar (.count << .fourth) []
                        |> C.named (Maybe.withDefault "Meh" <| Maybe.map (.name << .fourth) <| List.head series)
                    , C.bar (.count << .third) []
                        |> C.named (Maybe.withDefault "Meh" <| Maybe.map (.name << .third) <| List.head series)
                    , C.bar (.count << .second) []
                        |> C.named (Maybe.withDefault "Meh" <| Maybe.map (.name << .second) <| List.head series)
                    , C.bar (.count << .first) []
                        |> C.named (Maybe.withDefault "Meh" <| Maybe.map (.name << .first) <| List.head series)
                    ]
                ]
                series
            , C.eachBar <|
                \p bar ->
                    if CI.getY bar > 0 then
                        [ C.label [ CA.moveDown 25, CA.color "white" ] [ Svg.text (Maybe.withDefault "" <| Dict.get (CI.getY bar) byCount) ] (CI.getTop p bar)
                        , C.label [ CA.moveDown 45, CA.color "white" ] [ Svg.text (String.fromFloat (CI.getY bar) ++ " (" ++ (String.fromInt <| toPercent <| CI.getY bar) ++ "%)") ] (CI.getTop p bar)
                        ]

                    else
                        []
            , C.labelAt .max
                .max
                [ CA.moveLeft 8, CA.moveDown 5, CA.alignRight ]
                [ Svg.text "Plaintiff attorney listed on detainer warrants" ]
            , C.labelAt .min
                CA.middle
                [ CA.moveRight 20, CA.rotate 90, CA.moveUp 25 ]
                [ Svg.text "Detainer Warrants" ]
            ]
        )


viewPlaintiffAttorneyChart : Model -> Dimensions -> List PlaintiffAttorneyWarrantCount -> Element Msg
viewPlaintiffAttorneyChart model ({ width, height } as dimens) counts =
    let
        total =
            List.sum <| List.map .warrantCount counts
    in
    Element.column [ Element.spacing 10, Element.centerX, Element.width fill ]
        [ row [ Element.width fill ]
            [ Element.column
                [ Element.width (Element.shrink |> Element.minimum width)
                , Element.height (Element.px height)
                ]
                [ viewPlaintiffShareChart model dimens counts
                ]
            ]
        ]


subscriptions : Maybe PageUrl -> RouteParams -> Path -> Model -> Sub Msg
subscriptions pageUrl params path model =
    Sub.none
