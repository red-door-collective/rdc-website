module Page.Admin.DetainerWarrants.BulkUpload exposing (Data, Model, Msg, page)

import Browser.Navigation as Nav
import Csv.Decode exposing (FieldNames(..), field, pipeline, string)
import DataSource exposing (DataSource)
import Date
import DetainerWarrant exposing (AmountClaimedCategory(..), DetainerWarrant)
import Element exposing (Element, column, fill, height, maximum, paragraph, px, row, text, width)
import Element.Font as Font
import Element.Input as Input
import File exposing (File)
import File.Select as Select
import Head
import Head.Seo as Seo
import Logo
import Page exposing (Page, PageWithState, StaticPayload)
import Pages.PageUrl exposing (PageUrl)
import Pages.Url
import Path exposing (Path)
import Shared
import Task
import View exposing (View)


type alias Model =
    { csv : Maybe String
    }


type alias RouteParams =
    {}


init :
    Maybe PageUrl
    -> Shared.Model
    -> StaticPayload Data RouteParams
    -> ( Model, Cmd Msg )
init pageUrl sharedModel static =
    ( Model Nothing, Cmd.none )


type Msg
    = CsvRequested
    | CsvSelected File
    | CsvLoaded String


update :
    PageUrl
    -> Maybe Nav.Key
    -> Shared.Model
    -> StaticPayload Data RouteParams
    -> Msg
    -> Model
    -> ( Model, Cmd Msg )
update pageUrl navKey sharedModel static msg model =
    case msg of
        CsvRequested ->
            ( model
            , Select.file [ "text/csv" ] CsvSelected
            )

        CsvSelected file ->
            ( model
            , Task.perform CsvLoaded (File.toString file)
            )

        CsvLoaded content ->
            ( { model | csv = Just content }
            , Cmd.none
            )


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


type alias Data =
    ()


data : DataSource Data
data =
    DataSource.succeed ()


head :
    StaticPayload Data RouteParams
    -> List Head.Tag
head static =
    Seo.summary
        { canonicalUrlOverride = Nothing
        , siteName = "Red Door Collective"
        , image = Logo.smallImage
        , description = "Upload multiple detainer warrants from CaseLink"
        , locale = Just "en-us"
        , title = "RDC | Admin | Detainer Warrants | Bulk Upload"
        }
        |> Seo.website


viewWarrants : List DetainerWarrant -> Element Msg
viewWarrants warrants =
    let
        toCellConfig index =
            { striped = modBy 2 index == 0
            , hovered = Nothing
            , selected = Nothing
            , onMouseDown = Nothing
            , onMouseEnter = Nothing
            }

        cell =
            DetainerWarrant.viewTextRow toCellConfig
    in
    Element.indexedTable
        [ width (fill |> maximum 1400)
        , height (px 600)
        , Font.size 14
        , Element.scrollbarY
        ]
        { data = warrants
        , columns =
            [ { header = Element.none
              , view = DetainerWarrant.viewStatusIcon toCellConfig
              , width = px 40
              }
            , { header = DetainerWarrant.viewHeaderCell "Docket #"
              , view = DetainerWarrant.viewDocketId toCellConfig
              , width = Element.fill
              }
            , { header = DetainerWarrant.viewHeaderCell "File Date"
              , view = cell (Maybe.withDefault "" << Maybe.map Date.toIsoString << .fileDate)
              , width = Element.fill
              }
            , { header = DetainerWarrant.viewHeaderCell "Plaintiff"
              , view = cell (Maybe.withDefault "" << Maybe.map .name << .plaintiff)
              , width = fill
              }
            , { header = DetainerWarrant.viewHeaderCell "Plnt. Attorney"
              , view = cell (Maybe.withDefault "" << Maybe.map .name << .plaintiffAttorney)
              , width = fill
              }
            , { header = DetainerWarrant.viewHeaderCell "Defendant"
              , view = cell (Maybe.withDefault "" << Maybe.map .name << List.head << .defendants)
              , width = fill
              }
            ]
        }


decodeWarrants content =
    Csv.Decode.decodeCsv FieldNamesFromFirstRow
        (Csv.Decode.into
            (\docketId fileDate status plaintiff plaintiffAttorney defendants ->
                { docketId = docketId
                , fileDate = DetainerWarrant.dateFromString fileDate
                , status = Result.toMaybe <| DetainerWarrant.statusFromText status
                , plaintiff = Nothing
                , plaintiffAttorney = Nothing
                , defendants = []
                , presidingJudge = Nothing
                , courtDate = Nothing
                , courtroom = Nothing
                , amountClaimed = Nothing
                , amountClaimedCategory = NotApplicable
                , isCares = Nothing
                , isLegacy = Nothing
                , nonpayment = Nothing
                , judgements = []
                , notes = Nothing
                }
            )
            |> pipeline (field "Docket #" string)
            |> pipeline (field "File Date" string)
            |> pipeline (field "Status" string)
            |> pipeline (field "Plaintiff" string)
            |> pipeline (field "Pltf. Attorney" string)
            |> pipeline (field "Defendant" string)
        )
        content


view :
    Maybe PageUrl
    -> Shared.Model
    -> Model
    -> StaticPayload Data RouteParams
    -> View Msg
view maybeUrl sharedModel model static =
    { title = "RDC Admin Bulk Upload"
    , body =
        [ case model.csv of
            Nothing ->
                Input.button [] { onPress = Just CsvRequested, label = text "Load CSV" }

            Just content ->
                let
                    decoded =
                        decodeWarrants content
                in
                case decoded of
                    Ok warrants ->
                        column []
                            [ row [] [ viewWarrants warrants ] ]

                    Err _ ->
                        Element.text "Oops"
        ]
    }


subscriptions : Maybe PageUrl -> RouteParams -> Path -> Model -> Sub Msg
subscriptions pageUrl params path model =
    Sub.none
