module Page.Admin.DetainerWarrants.BulkUpload exposing (Data, Model, Msg, page)

import Browser.Navigation as Nav
import Csv.Decode exposing (FieldNames(..), field, pipeline, string)
import DataSource exposing (DataSource)
import Date exposing (Date)
import Date.Extra
import Defendant exposing (Defendant)
import Design
import DetainerWarrant exposing (AmountClaimedCategory(..), Attorney, DetainerWarrant, Status)
import Dict exposing (Dict)
import Element exposing (Element, centerX, column, fill, height, maximum, padding, paragraph, px, row, shrink, spacing, text, width)
import Element.Font as Font
import Element.Input as Input
import File exposing (File)
import File.Select as Select
import Head
import Head.Seo as Seo
import Http exposing (Error(..))
import Json.Encode
import Logo
import Page exposing (Page, PageWithState, StaticPayload)
import Pages.PageUrl exposing (PageUrl)
import Pages.Url
import Path exposing (Path)
import Plaintiff exposing (Plaintiff)
import Progress exposing (Tracking)
import Rest exposing (Cred)
import Rest.Endpoint as Endpoint
import Session exposing (Session)
import Set exposing (Set)
import Shared
import Task
import View exposing (View)


type alias DetainerWarrantStub =
    { docketId : String
    , fileDate : Maybe Date
    , status : Maybe Status
    , plaintiff : Maybe String
    , plaintiffAttorney : Maybe String
    , defendants : Maybe String
    }


type RemoteData data
    = NotFetched
    | Fetching
    | Success data
    | Failure Http.Error


type alias UploadState =
    { stubs : List DetainerWarrantStub
    , attorneys : Dict String (RemoteData Attorney)
    , defendants : Dict String (RemoteData Defendant)
    , plaintiffs : Dict String (RemoteData Plaintiff)
    , warrants : Dict String (RemoteData DetainerWarrant)
    , saveState : SaveState
    }


type alias UploadTracking =
    { plaintiffs : Tracking
    , attorneys : Tracking
    , defendants : Tracking
    , warrants : Tracking
    }


type SaveState
    = NotStarted
    | SavingWarrants UploadTracking
    | DoneSaving


type Model
    = ReadyForCsv { error : Maybe Csv.Decode.Error }
    | ReadyForBulkSave UploadState


type alias RouteParams =
    {}


init :
    Maybe PageUrl
    -> Shared.Model
    -> StaticPayload Data RouteParams
    -> ( Model, Cmd Msg )
init pageUrl sharedModel static =
    ( ReadyForCsv { error = Nothing }, Cmd.none )


type CsvUploadMsg
    = CsvRequested
    | CsvSelected File
    | CsvLoaded String


type BulkUploadMsg
    = SaveWarrants
    | InsertedAttorney String (Result Http.Error (Rest.Item Attorney))
    | InsertedPlaintiff String (Result Http.Error (Rest.Item Plaintiff))
    | InsertedDefendant String (Result Http.Error (Rest.Item Defendant))
    | InsertedWarrant String (Result Http.Error (Rest.Item DetainerWarrant))
    | GotAttorney String (Result Http.Error (Rest.Collection Attorney))
    | GotPlaintiff String (Result Http.Error (Rest.Collection Plaintiff))
    | GotDefendant String (Result Http.Error (Rest.Collection Defendant))


type Msg
    = CsvUpload CsvUploadMsg
    | BulkUpload BulkUploadMsg


initBulkUpload stubs =
    { stubs = stubs
    , attorneys = collectRelated .plaintiffAttorney stubs
    , plaintiffs = collectRelated .plaintiff stubs
    , defendants = collectRelated .defendants stubs
    , warrants = collectRelated (Just << .docketId) stubs
    , saveState = NotStarted
    }


updateBeforeCsvUpload : CsvUploadMsg -> { error : Maybe Csv.Decode.Error } -> ( Model, Cmd Msg )
updateBeforeCsvUpload msg model =
    case msg of
        CsvRequested ->
            ( ReadyForCsv model
            , Select.file [ "text/csv" ] (CsvUpload << CsvSelected)
            )

        CsvSelected file ->
            ( ReadyForCsv model
            , Task.perform (CsvUpload << CsvLoaded) (File.toString file)
            )

        CsvLoaded content ->
            case decodeWarrants content of
                Ok stubs ->
                    ( ReadyForBulkSave (initBulkUpload stubs)
                    , Cmd.none
                    )

                Err errMsg ->
                    ( ReadyForCsv { error = Just errMsg }
                    , Cmd.none
                    )


updateDict : String -> Result Http.Error a -> Dict String (RemoteData a) -> Dict String (RemoteData a)
updateDict resourceId result resources =
    Dict.update resourceId
        (Maybe.map
            (\_ ->
                case result of
                    Ok updatedResource ->
                        Success updatedResource

                    Err errMsg ->
                        Failure errMsg
            )
        )
        resources


maybeUpdateDict : String -> Result Http.Error (Maybe a) -> Dict String (RemoteData a) -> Dict String (RemoteData a)
maybeUpdateDict resourceId result resources =
    case result of
        Ok good ->
            case good of
                Just something ->
                    updateDict resourceId (Result.Ok something) resources

                Nothing ->
                    resources

        Err errMsg ->
            updateDict resourceId (Result.Err errMsg) resources


increment result tracking =
    if isConflict result then
        { tracking | current = tracking.current }

    else
        case result of
            Ok _ ->
                { tracking | current = tracking.current + 1 }

            Err _ ->
                { tracking | errored = tracking.errored + 1 }


isConflict : Result Http.Error a -> Bool
isConflict result =
    case result of
        Ok _ ->
            False

        Err errMsg ->
            case errMsg of
                BadStatus status ->
                    status == 409

                _ ->
                    False


updateAfterCsvUpload : Session -> BulkUploadMsg -> UploadState -> ( Model, Cmd Msg )
updateAfterCsvUpload session msg state =
    let
        domain =
            "http://localhost:5000"
    in
    case msg of
        SaveWarrants ->
            saveWarrants domain session state

        InsertedAttorney name result ->
            let
                getOnConflict =
                    if isConflict result then
                        Rest.get (Endpoint.attorneysSearch domain [ ( "name", name ) ]) (Session.cred session) (GotAttorney name) (Rest.collectionDecoder DetainerWarrant.attorneyDecoder)

                    else
                        Cmd.none

                newState =
                    { state
                        | attorneys = updateDict name (Result.map .data result) state.attorneys
                        , saveState =
                            case state.saveState of
                                SavingWarrants uploadTracking ->
                                    SavingWarrants { uploadTracking | attorneys = increment result uploadTracking.attorneys }

                                _ ->
                                    state.saveState
                    }
            in
            Tuple.mapSecond (\cmd -> Cmd.batch [ cmd, Cmd.map BulkUpload getOnConflict ]) (saveWarrants domain session newState)

        InsertedPlaintiff name result ->
            let
                getOnConflict =
                    if isConflict result then
                        Rest.get (Endpoint.plaintiffsSearch domain [ ( "name", name ) ]) (Session.cred session) (GotPlaintiff name) (Rest.collectionDecoder Plaintiff.decoder)

                    else
                        Cmd.none

                newState =
                    { state
                        | plaintiffs = updateDict name (Result.map .data result) state.plaintiffs
                        , saveState =
                            case state.saveState of
                                SavingWarrants uploadTracking ->
                                    SavingWarrants { uploadTracking | plaintiffs = increment result uploadTracking.plaintiffs }

                                _ ->
                                    state.saveState
                    }
            in
            Tuple.mapSecond (\cmd -> Cmd.batch [ cmd, Cmd.map BulkUpload getOnConflict ]) (saveWarrants domain session newState)

        InsertedDefendant name result ->
            let
                getOnConflict =
                    if isConflict result then
                        Rest.get (Endpoint.defendantsSearch domain [ ( "name", name ) ]) (Session.cred session) (GotDefendant name) (Rest.collectionDecoder Defendant.decoder)

                    else
                        Cmd.none

                newState =
                    { state
                        | defendants = updateDict name (Result.map .data result) state.defendants
                        , saveState =
                            case state.saveState of
                                SavingWarrants uploadTracking ->
                                    SavingWarrants { uploadTracking | defendants = increment result uploadTracking.defendants }

                                _ ->
                                    state.saveState
                    }
            in
            Tuple.mapSecond (\cmd -> Cmd.batch [ cmd, Cmd.map BulkUpload getOnConflict ]) (saveWarrants domain session newState)

        InsertedWarrant docketId result ->
            saveWarrants domain
                session
                { state
                    | warrants = updateDict docketId (Result.map .data result) state.warrants
                    , saveState =
                        case state.saveState of
                            SavingWarrants uploadTracking ->
                                SavingWarrants { uploadTracking | warrants = increment result uploadTracking.warrants }

                            _ ->
                                state.saveState
                }

        GotAttorney name result ->
            saveWarrants domain
                session
                { state
                    | attorneys = maybeUpdateDict name (Result.map (List.head << .data) result) state.attorneys
                    , saveState =
                        case state.saveState of
                            SavingWarrants uploadTracking ->
                                SavingWarrants { uploadTracking | attorneys = increment result uploadTracking.attorneys }

                            _ ->
                                state.saveState
                }

        GotPlaintiff name result ->
            saveWarrants domain
                session
                { state
                    | plaintiffs = maybeUpdateDict name (Result.map (List.head << .data) result) state.plaintiffs
                    , saveState =
                        case state.saveState of
                            SavingWarrants uploadTracking ->
                                SavingWarrants { uploadTracking | plaintiffs = increment result uploadTracking.plaintiffs }

                            _ ->
                                state.saveState
                }

        GotDefendant name result ->
            saveWarrants domain
                session
                { state
                    | defendants = maybeUpdateDict name (Result.map (List.head << .data) result) state.defendants
                    , saveState =
                        case state.saveState of
                            SavingWarrants uploadTracking ->
                                SavingWarrants { uploadTracking | defendants = increment result uploadTracking.defendants }

                            _ ->
                                state.saveState
                }


update :
    PageUrl
    -> Maybe Nav.Key
    -> Shared.Model
    -> StaticPayload Data RouteParams
    -> Msg
    -> Model
    -> ( Model, Cmd Msg )
update pageUrl navKey sharedModel static msg model =
    case ( msg, model ) of
        ( CsvUpload subMsg, ReadyForCsv subModel ) ->
            updateBeforeCsvUpload subMsg subModel

        ( BulkUpload subMsg, ReadyForBulkSave state ) ->
            updateAfterCsvUpload sharedModel.session subMsg state

        ( _, _ ) ->
            ( model, Cmd.none )


collectRelated :
    (DetainerWarrantStub -> Maybe String)
    -> List DetainerWarrantStub
    -> Dict String (RemoteData a)
collectRelated fn warrants =
    List.filterMap fn warrants
        |> Set.fromList
        |> Set.toList
        |> List.map (\id -> ( id, Fetching ))
        |> Dict.fromList


defaultDistrict =
    ( "district_id", Json.Encode.int 1 )


insertAttorney : String -> Maybe Cred -> String -> Cmd BulkUploadMsg
insertAttorney domain maybeCred name =
    let
        decoder =
            Rest.itemDecoder DetainerWarrant.attorneyDecoder

        body =
            Json.Encode.object
                [ ( "data"
                  , Json.Encode.object
                        [ ( "name", Json.Encode.string name )
                        , defaultDistrict
                        ]
                  )
                ]
                |> Http.jsonBody
    in
    Rest.post (Endpoint.attorneys domain []) maybeCred body (InsertedAttorney name) decoder


insertPlaintiff : String -> Maybe Cred -> String -> Cmd BulkUploadMsg
insertPlaintiff domain maybeCred name =
    let
        decoder =
            Rest.itemDecoder Plaintiff.decoder

        body =
            Json.Encode.object
                [ ( "data"
                  , Json.Encode.object
                        [ ( "name", Json.Encode.string name )
                        , defaultDistrict
                        ]
                  )
                ]
                |> Http.jsonBody
    in
    Rest.post (Endpoint.plaintiffs domain []) maybeCred body (InsertedPlaintiff name) decoder


insertDefendant : String -> Maybe Cred -> String -> Cmd BulkUploadMsg
insertDefendant domain maybeCred name =
    let
        decoder =
            Rest.itemDecoder Defendant.decoder

        body =
            Json.Encode.object
                [ ( "data"
                  , Json.Encode.object
                        [ ( "name", Json.Encode.string name )
                        , defaultDistrict
                        ]
                  )
                ]
                |> Http.jsonBody
    in
    Rest.post (Endpoint.defendants domain []) maybeCred body (InsertedDefendant name) decoder


nullable fieldName fn field =
    Maybe.withDefault [ ( fieldName, Json.Encode.null ) ] <| Maybe.map (\f -> [ ( fieldName, fn f ) ]) field


encodeRelated record =
    Json.Encode.object [ ( "id", Json.Encode.int record.id ) ]


insertWarrant : String -> Maybe Cred -> UploadState -> DetainerWarrantStub -> Cmd BulkUploadMsg
insertWarrant domain maybeCred state stub =
    let
        decoder =
            Rest.itemDecoder DetainerWarrant.decoder

        body =
            Json.Encode.object
                [ ( "data"
                  , Json.Encode.object
                        ([ ( "docket_id", Json.Encode.string stub.docketId )
                         , ( "defendants"
                           , Json.Encode.list encodeRelated
                                (Maybe.withDefault [] <|
                                    Maybe.andThen
                                        (\name ->
                                            Maybe.andThen
                                                (\remoteData ->
                                                    case remoteData of
                                                        Success defendant ->
                                                            Just [ { id = defendant.id } ]

                                                        _ ->
                                                            Nothing
                                                )
                                            <|
                                                Dict.get name state.defendants
                                        )
                                        stub.defendants
                                )
                           )
                         ]
                            ++ nullable "file_date" Json.Encode.string (Maybe.map Date.toIsoString stub.fileDate)
                            ++ nullable "plaintiff"
                                encodeRelated
                                (Maybe.andThen
                                    (\name ->
                                        Maybe.andThen
                                            (\remoteData ->
                                                case remoteData of
                                                    Success plaintiff ->
                                                        Just { id = plaintiff.id }

                                                    _ ->
                                                        Nothing
                                            )
                                        <|
                                            Dict.get name state.plaintiffs
                                    )
                                    stub.plaintiff
                                )
                            ++ nullable "plaintiff_attorney"
                                encodeRelated
                                (Maybe.andThen
                                    (\name ->
                                        Maybe.andThen
                                            (\remoteData ->
                                                case remoteData of
                                                    Success attorney ->
                                                        Just { id = attorney.id }

                                                    _ ->
                                                        Nothing
                                            )
                                        <|
                                            Dict.get name state.attorneys
                                    )
                                    stub.plaintiffAttorney
                                )
                        )
                  )
                ]
                |> Http.jsonBody
    in
    Rest.patch (Endpoint.detainerWarrant domain stub.docketId) maybeCred body (InsertedWarrant stub.docketId) decoder


saveWarrants : String -> Session -> UploadState -> ( Model, Cmd Msg )
saveWarrants domain session state =
    let
        maybeCred =
            Session.cred session
    in
    case state.saveState of
        NotStarted ->
            ( ReadyForBulkSave
                { state
                    | saveState =
                        SavingWarrants
                            { attorneys = { current = 0, total = Dict.size state.attorneys, errored = 0 }
                            , defendants = { current = 0, total = Dict.size state.defendants, errored = 0 }
                            , plaintiffs = { current = 0, total = Dict.size state.plaintiffs, errored = 0 }
                            , warrants = { current = 0, total = Dict.size state.warrants, errored = 0 }
                            }
                }
            , Cmd.map BulkUpload <|
                Cmd.batch
                    (List.concat
                        [ List.map (insertAttorney domain maybeCred) (Dict.keys state.attorneys)
                        , List.map (insertPlaintiff domain maybeCred) (Dict.keys state.plaintiffs)
                        , List.map (insertDefendant domain maybeCred) (Dict.keys state.defendants)
                        ]
                    )
            )

        SavingWarrants tracking ->
            let
                savingWarrants =
                    (tracking.attorneys.current
                        + tracking.plaintiffs.current
                        + tracking.defendants.current
                        + tracking.attorneys.errored
                        + tracking.plaintiffs.errored
                        + tracking.defendants.errored
                    )
                        >= (tracking.attorneys.total
                                + tracking.plaintiffs.total
                                + tracking.defendants.total
                           )
            in
            if savingWarrants && tracking.warrants.current == 0 then
                ( ReadyForBulkSave state
                , Cmd.map BulkUpload <| Cmd.batch (List.map (insertWarrant domain maybeCred state) state.stubs)
                )

            else if savingWarrants && tracking.warrants.current >= tracking.warrants.total then
                ( ReadyForBulkSave { state | saveState = DoneSaving }
                , Cmd.none
                )

            else
                ( ReadyForBulkSave state, Cmd.none )

        DoneSaving ->
            ( ReadyForBulkSave state, Cmd.none )


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


viewWarrants : List DetainerWarrantStub -> Element Msg
viewWarrants warrants =
    let
        toCellConfig index =
            { toId = .docketId
            , status = .status
            , striped = modBy 2 index == 0
            , hovered = Nothing
            , selected = Nothing
            , maxWidth = Just 300
            , onMouseDown = Nothing
            , onMouseEnter = Nothing
            }

        cell =
            DetainerWarrant.viewTextRow toCellConfig
    in
    Element.indexedTable
        [ width fill
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
              , view = cell (Maybe.withDefault "" << .plaintiff)
              , width = fill
              }
            , { header = DetainerWarrant.viewHeaderCell "Plnt. Attorney"
              , view = cell (Maybe.withDefault "" << .plaintiffAttorney)
              , width = fill
              }
            , { header = DetainerWarrant.viewHeaderCell "Defendant"
              , view = cell (Maybe.withDefault "" << .defendants)
              , width = fill
              }
            ]
        }


decodeWarrants : String -> Result Csv.Decode.Error (List DetainerWarrantStub)
decodeWarrants content =
    Csv.Decode.decodeCsv FieldNamesFromFirstRow
        (Csv.Decode.into
            (\docketId fileDate status plaintiff plaintiffAttorney defendants ->
                { docketId = docketId
                , fileDate = Date.Extra.fromUSCalString fileDate
                , status = Result.toMaybe <| DetainerWarrant.statusFromText status
                , plaintiff =
                    if String.isEmpty plaintiff then
                        Nothing

                    else
                        Just plaintiff
                , plaintiffAttorney =
                    if String.isEmpty plaintiffAttorney then
                        Nothing

                    else
                        Just plaintiffAttorney
                , defendants =
                    if String.isEmpty defendants then
                        Nothing

                    else
                        Just defendants
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
        [ column [ width fill, spacing 10, padding 10 ]
            [ row [ width fill ]
                [ case model of
                    ReadyForCsv { error } ->
                        case error of
                            Just errMsg ->
                                Element.text (Csv.Decode.errorToString errMsg)

                            Nothing ->
                                Design.button [ centerX ] { onPress = Just (CsvUpload CsvRequested), label = text "Load CSV" }

                    ReadyForBulkSave state ->
                        column [ width fill ]
                            [ row [ width fill ]
                                [ case state.saveState of
                                    NotStarted ->
                                        Design.button [ centerX ]
                                            { onPress = Just (BulkUpload SaveWarrants)
                                            , label = text "Save Warrants"
                                            }

                                    SavingWarrants tracking ->
                                        let
                                            totalTracking =
                                                { current = tracking.attorneys.current + tracking.defendants.current + tracking.plaintiffs.current + tracking.warrants.current
                                                , total = tracking.attorneys.total + tracking.defendants.total + tracking.plaintiffs.total + tracking.warrants.total
                                                , errored = tracking.attorneys.errored + tracking.defendants.errored + tracking.plaintiffs.errored + tracking.warrants.errored
                                                }
                                        in
                                        Element.el [ centerX, width shrink, height shrink ]
                                            (Element.html (Progress.bar { width = 400, height = 30, tracking = totalTracking }))

                                    DoneSaving ->
                                        paragraph [ centerX ] [ text "Finished!" ]
                                ]
                            , row [ width fill ]
                                [ viewWarrants state.stubs
                                ]
                            ]
                ]
            ]
        ]
    }


subscriptions : Maybe PageUrl -> RouteParams -> Path -> Model -> Sub Msg
subscriptions pageUrl params path model =
    Sub.none
