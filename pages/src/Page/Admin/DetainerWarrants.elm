module Page.Admin.DetainerWarrants exposing (Data, Model, Msg, page)

import Alert exposing (Alert)
import Browser.Navigation as Nav
import Calendar
import Clock
import Color
import DataSource exposing (DataSource)
import Date exposing (Date)
import DateTime
import DetainerWarrant exposing (DetainerWarrant)
import Element exposing (Element, alignTop, centerX, column, fill, height, maximum, padding, paddingXY, paragraph, px, row, spacing, text, textColumn, width)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import FormatNumber
import FormatNumber.Locales exposing (Decimals(..), usLocale)
import Head
import Head.Seo as Seo
import Html.Attributes as Attrs exposing (id)
import Http
import InfiniteScroll
import Iso8601
import Json.Decode
import Loader
import Log
import Logo
import Maybe
import Page exposing (StaticPayload)
import Pages.PageUrl exposing (PageUrl)
import Path exposing (Path)
import QueryParams
import RemoteData exposing (RemoteData(..))
import Rest exposing (Cred, HttpError)
import Rest.Endpoint as Endpoint
import Result
import Rollbar exposing (Rollbar)
import Runtime
import Search exposing (Cursor(..), Search, detainerWarrantsDefault)
import Session exposing (Session)
import Shared
import Sprite
import Svg.Attributes exposing (type_)
import Time exposing (Month(..), Posix)
import Time.Utils exposing (posixDecoder)
import UI.Alert as Alert
import UI.Button as Button exposing (Button)
import UI.DatePicker as DatePicker
import UI.Dialog as Dialog
import UI.Document as Document
import UI.Effects
import UI.Icon as Icon
import UI.Link as Link
import UI.Palette
import UI.RenderConfig as RenderConfig exposing (RenderConfig)
import UI.Size
import UI.Tables.Stateful as Stateful exposing (Filters, Sorters, filtersEmpty, localSingleTextFilter, remoteRangeDateFilter, remoteSelectFilter, remoteSingleDateFilter, remoteSingleTextFilter, sortBy, sortersEmpty, unsortable)
import UI.Text
import UI.TextField as TextField
import UI.Utils.DateInput exposing (DateInput, RangeDate)
import UI.Utils.Element exposing (renderIf)
import UI.Utils.TypeNumbers as T
import Url.Builder
import User exposing (User)
import View exposing (View)


type alias Model =
    { warrants : RemoteData HttpError (List DetainerWarrant)
    , selected : Maybe String
    , hovered : Maybe String
    , search : Search Search.DetainerWarrants
    , tableState : Stateful.State Msg DetainerWarrant T.Eight
    , infiniteScroll : InfiniteScroll.Model Msg
    , exportStatus : Maybe BackendTask
    , alert : Maybe Alert
    , showExportModal : Bool
    , exportStartDate : Maybe Calendar.Date
    , exportEndDate : Maybe Calendar.Date
    , exportStartDatePicker : DatePicker.Model
    , exportEndDatePicker : DatePicker.Model
    , documentModel : Document.Model
    }


init :
    Maybe PageUrl
    -> Shared.Model
    -> StaticPayload Data RouteParams
    -> ( Model, Cmd Msg )
init pageUrl sharedModel static =
    let
        maybeCred =
            Session.cred sharedModel.session

        domain =
            Runtime.domain static.sharedData.runtime.environment

        filters =
            Maybe.withDefault Search.detainerWarrantsDefault <| Maybe.andThen (Maybe.map (Search.dwFromString << QueryParams.toString) << .query) pageUrl

        search =
            { filters = filters, cursor = NewSearch, previous = Just filters, totalMatches = Nothing }
    in
    ( { warrants = NotAsked
      , search = search
      , selected = Nothing
      , hovered = Nothing
      , tableState =
            Stateful.init
                |> Stateful.stateWithFilters (searchFilters search.filters)
                |> Stateful.stateWithSorters sortersInit
      , infiniteScroll = InfiniteScroll.init (loadMore domain maybeCred search) |> InfiniteScroll.direction InfiniteScroll.Bottom
      , exportStatus = Nothing
      , alert = Nothing
      , showExportModal = False
      , exportStartDate = Nothing
      , exportEndDate = Nothing
      , exportStartDatePicker = DatePicker.init <| earliestDateThisYear <| Calendar.fromPosix static.sharedData.runtime.todayPosix
      , exportEndDatePicker = DatePicker.init <| Calendar.fromPosix static.sharedData.runtime.todayPosix
      , documentModel = Document.modelInit sharedModel.renderConfig
      }
    , searchWarrants domain maybeCred search
    )


searchWarrants : String -> Maybe Cred -> Search Search.DetainerWarrants -> Cmd Msg
searchWarrants domain maybeCred search =
    Rest.get (Endpoint.detainerWarrantsSearch domain (queryArgsWithPagination search)) maybeCred GotWarrants Rest.detainerWarrantApiDecoder


loadMore : String -> Maybe Cred -> Search Search.DetainerWarrants -> InfiniteScroll.Direction -> Cmd Msg
loadMore domain maybeCred search dir =
    case search.cursor of
        NewSearch ->
            Cmd.none

        After _ ->
            searchWarrants domain maybeCred search

        End ->
            Cmd.none


queryArgsWithPagination : Search Search.DetainerWarrants -> List ( String, String )
queryArgsWithPagination search =
    let
        filters =
            search.filters

        queryArgs =
            Search.detainerWarrantsArgs filters
    in
    if Just search.filters == search.previous then
        case search.cursor of
            NewSearch ->
                queryArgs

            After warrantsCursor ->
                ( "cursor", warrantsCursor ) :: queryArgs

            End ->
                queryArgs

    else
        queryArgs


type alias BackendTask =
    { id : String
    , startedAt : Posix
    }


decodeBackendTask : Json.Decode.Decoder BackendTask
decodeBackendTask =
    Json.Decode.map2 BackendTask
        (Json.Decode.field "id" Json.Decode.string)
        (Json.Decode.field "started_at" posixDecoder)


dateToPosix d =
    DateTime.fromDateAndTime d Clock.midnight
        |> DateTime.toPosix
        |> Time.posixToMillis
        |> String.fromInt


export : String -> Session -> Model -> Cmd Msg
export domain session model =
    let
        params =
            (case model.exportStartDate of
                Just startDate ->
                    [ ( "start", dateToPosix startDate ) ]

                Nothing ->
                    []
            )
                ++ (case model.exportEndDate of
                        Just endDate ->
                            [ ( "end", dateToPosix endDate ) ]

                        Nothing ->
                            []
                   )
    in
    Rest.get (Endpoint.export domain params) (Session.cred session) ExportStarted decodeBackendTask


type Msg
    = InputDocketId (Maybe String)
    | InputFileDate (Maybe RangeDate)
    | InputCourtDate (Maybe DateInput)
    | InputPlaintiff (Maybe String)
    | InputPlaintiffAttorney (Maybe String)
    | InputAddress (Maybe String)
    | SelectAuditStatus (Maybe Int)
    | ForTable (Stateful.Msg DetainerWarrant)
    | GotWarrants (Result HttpError (Rest.Collection DetainerWarrant))
    | InfiniteScrollMsg InfiniteScroll.Msg
    | InputFreeTextSearch String
    | OnFreeTextSearch
    | DocumentMsg Document.Msg
      -- Export
    | ToggleExportModal
    | SelectExportStartDate Calendar.Date
    | SelectExportEndDate Calendar.Date
    | ToStartDatePicker DatePicker.Msg
    | ToEndDatePicker DatePicker.Msg
    | Export
    | ExportStarted (Result Rest.HttpError BackendTask)
    | RemoveAlert Posix
    | NoOp


updateFilters :
    (Search.DetainerWarrants -> Search.DetainerWarrants)
    -> Model
    -> Model
updateFilters transform model =
    let
        search =
            model.search
    in
    { model | search = { search | filters = transform search.filters } }


updateFiltersAndReload :
    String
    -> Session
    -> (Search.DetainerWarrants -> Search.DetainerWarrants)
    -> Model
    -> ( Model, Cmd Msg )
updateFiltersAndReload domain session transform model =
    let
        updatedModel =
            updateFilters transform model
    in
    ( updatedModel
    , Cmd.batch
        [ Maybe.withDefault Cmd.none <|
            Maybe.map
                (\key ->
                    Nav.replaceUrl key <|
                        Url.Builder.absolute
                            [ "admin", "detainer-warrants" ]
                            (Endpoint.toQueryArgs <| Search.detainerWarrantsFilterArgs updatedModel.search.filters)
                )
                (Session.navKey session)
        , searchWarrants domain (Session.cred session) updatedModel.search
        ]
    )


fromFormattedToPosix date =
    let
        day =
            String.left 2 date

        month =
            String.slice 3 5 date

        year =
            String.right 4 date

        isoFormat =
            String.join "-" [ year, month, day ]
    in
    Result.toMaybe <| Iso8601.toTime isoFormat


update :
    PageUrl
    -> Maybe Nav.Key
    -> Shared.Model
    -> StaticPayload Data RouteParams
    -> Msg
    -> Model
    -> ( Model, Cmd Msg )
update pageUrl navKey sharedModel static msg model =
    case Session.profile sharedModel.session of
        Just profile ->
            updatePage profile sharedModel static msg model

        _ ->
            ( model, Cmd.none )


updatePage profile sharedModel static msg model =
    let
        rollbar =
            Log.reporting static.sharedData.runtime

        domain =
            Runtime.domain static.sharedData.runtime.environment

        logHttpError =
            error rollbar << Log.httpErrorMessage

        session =
            sharedModel.session
    in
    case msg of
        InputDocketId query ->
            updateFiltersAndReload domain session (\filters -> { filters | docketId = query }) model

        InputFileDate query ->
            updateFiltersAndReload domain
                session
                (\filters ->
                    { filters
                        | fileDateStart = Maybe.andThen (fromFormattedToPosix << UI.Utils.DateInput.toDD_MM_YYYY "-" << .from) query
                        , fileDateEnd = Maybe.andThen (fromFormattedToPosix << UI.Utils.DateInput.toDD_MM_YYYY "-" << .to) query
                    }
                )
                model

        InputCourtDate query ->
            updateFiltersAndReload domain session (\filters -> { filters | courtDate = Maybe.andThen (fromFormattedToPosix << UI.Utils.DateInput.toDD_MM_YYYY "-") query }) model

        InputPlaintiff query ->
            updateFiltersAndReload domain session (\filters -> { filters | plaintiff = query }) model

        InputPlaintiffAttorney query ->
            updateFiltersAndReload domain session (\filters -> { filters | plaintiffAttorney = query }) model

        InputAddress query ->
            updateFiltersAndReload domain session (\filters -> { filters | address = query }) model

        SelectAuditStatus maybeIndex ->
            updateFiltersAndReload domain
                session
                (\filters ->
                    { filters
                        | auditStatus =
                            case maybeIndex of
                                Just index ->
                                    DetainerWarrant.auditStatusOptions
                                        |> List.drop index
                                        |> List.head
                                        |> Maybe.andThen (Maybe.map DetainerWarrant.auditStatusText)

                                Nothing ->
                                    Nothing
                    }
                )
                model

        ForTable subMsg ->
            let
                ( newTableState, newCmd ) =
                    Stateful.update subMsg model.tableState
            in
            ( { model | tableState = newTableState }, UI.Effects.perform newCmd )

        GotWarrants (Ok detainerWarrantsPage) ->
            let
                maybeCred =
                    Session.cred sharedModel.session

                queryFilters =
                    Maybe.withDefault Search.detainerWarrantsDefault <| Maybe.map Search.dwFromString sharedModel.queryParams

                search =
                    { filters = queryFilters
                    , cursor = Maybe.withDefault End <| Maybe.map After detainerWarrantsPage.meta.afterCursor
                    , previous = Just queryFilters
                    , totalMatches = Just detainerWarrantsPage.meta.totalMatches
                    }

                updatedModel =
                    { model | search = search }
            in
            if updatedModel.search.previous == Just updatedModel.search.filters then
                ( let
                    warrants =
                        case model.warrants of
                            NotAsked ->
                                Success detainerWarrantsPage.data

                            Loading ->
                                Success detainerWarrantsPage.data

                            Success existing ->
                                Success <| existing ++ detainerWarrantsPage.data

                            Failure err ->
                                Success <| detainerWarrantsPage.data
                  in
                  { updatedModel
                    | warrants = warrants
                    , infiniteScroll =
                        InfiniteScroll.stopLoading model.infiniteScroll
                            |> InfiniteScroll.loadMoreCmd (loadMore domain maybeCred search)
                    , tableState = Stateful.stateWithItems (RemoteData.withDefault [] warrants) model.tableState
                  }
                , Cmd.none
                )

            else
                ( { updatedModel
                    | warrants = Success detainerWarrantsPage.data
                    , infiniteScroll =
                        InfiniteScroll.stopLoading model.infiniteScroll
                            |> InfiniteScroll.loadMoreCmd (loadMore domain maybeCred search)
                    , tableState = Stateful.stateWithItems detainerWarrantsPage.data model.tableState
                  }
                , Cmd.none
                )

        GotWarrants (Err httpError) ->
            ( model, logHttpError httpError )

        InfiniteScrollMsg subMsg ->
            case model.search.cursor of
                End ->
                    ( model, Cmd.none )

                _ ->
                    let
                        ( infiniteScroll, cmd ) =
                            InfiniteScroll.update InfiniteScrollMsg subMsg model.infiniteScroll
                    in
                    ( { model | infiniteScroll = infiniteScroll }, cmd )

        InputFreeTextSearch query ->
            ( updateFilters (\filters -> { filters | freeText = Just query }) model, Cmd.none )

        OnFreeTextSearch ->
            updateFiltersAndReload domain session identity model

        DocumentMsg subMsg ->
            ( model, Cmd.none )

        ToggleExportModal ->
            ( { model | showExportModal = not model.showExportModal }, Cmd.none )

        SelectExportStartDate date ->
            ( { model | exportStartDate = Just date }, Cmd.none )

        SelectExportEndDate date ->
            ( { model | exportEndDate = Just date }, Cmd.none )

        ToStartDatePicker subMsg ->
            let
                ( picker, effects ) =
                    DatePicker.update subMsg model.exportStartDatePicker
            in
            ( { model | exportStartDatePicker = picker }, UI.Effects.perform effects )

        ToEndDatePicker subMsg ->
            let
                ( picker, effects ) =
                    DatePicker.update subMsg model.exportEndDatePicker
            in
            ( { model | exportEndDatePicker = picker }, UI.Effects.perform effects )

        Export ->
            ( { model | showExportModal = False }, export domain session model )

        ExportStarted (Ok backendTask) ->
            ( { model
                | exportStatus = Just backendTask
                , alert =
                    Just
                        (Alert.sticky <|
                            "An email with all eviction data will soon be sent to "
                                ++ profile.email
                        )
              }
            , Cmd.none
            )

        ExportStarted (Err err) ->
            ( model, Cmd.none )

        RemoveAlert _ ->
            ( { model | alert = Nothing }, Cmd.none )

        NoOp ->
            ( model, Cmd.none )


error : Rollbar -> String -> Cmd Msg
error rollbar report =
    Log.error rollbar (\_ -> NoOp) report


createNewWarrantButton cfg =
    Button.fromLabel "Create detainer warrant"
        |> Button.redirect (Link.link <| "/admin/detainer-warrants/edit") Button.primary
        |> Button.renderElement cfg


exportButton : RenderConfig -> Element Msg
exportButton cfg =
    Button.fromLabeledOnRightIcon (Icon.download "Download warrants")
        |> Button.cmd ToggleExportModal Button.primary
        |> Button.renderElement cfg


viewFilter filters =
    let
        ifNonEmpty prefix fn filter =
            case filter of
                Just value ->
                    [ paragraph [ centerX, Font.center ] [ text (prefix ++ "\"" ++ fn value ++ "\"") ] ]

                Nothing ->
                    []
    in
    List.concat
        [ ifNonEmpty "docket number contains " identity filters.docketId
        , ifNonEmpty "file date is after" Time.Utils.toIsoString filters.fileDateStart
        , ifNonEmpty "court date is " Time.Utils.toIsoString filters.courtDate
        , ifNonEmpty "plaintiff contains " identity filters.plaintiff
        , ifNonEmpty "plaintiff attorney contains " identity filters.plaintiffAttorney
        , ifNonEmpty "address contains " identity filters.address
        ]


viewEmptyResults filters =
    textColumn [ centerX, spacing 10 ]
        ([ paragraph [ Font.center, centerX, Font.size 24 ]
            [ text "No detainer warrants exist matching your search criteria:" ]
         , paragraph [ centerX, Font.italic, Font.center ]
            [ text "where..." ]
         ]
            ++ (List.intersperse (paragraph [ centerX, Font.center ] [ text "&" ]) <| viewFilter filters)
        )


freeTextSearch : RenderConfig -> Search.DetainerWarrants -> Element Msg
freeTextSearch cfg filters =
    TextField.search InputFreeTextSearch
        "Search"
        (Maybe.withDefault "" filters.freeText)
        |> TextField.withIcon
            (Icon.search "Search")
        |> TextField.setLabelVisible False
        |> TextField.withPlaceholder "Search"
        |> TextField.withOnEnterPressed OnFreeTextSearch
        |> TextField.renderElement cfg


viewActions cfg profile =
    Element.row [ centerX, spacing 10 ]
        [ renderIf (User.canViewDefendantInformation profile) (createNewWarrantButton cfg)
        , renderIf (User.canViewCourtData profile) (exportButton cfg)
        ]


insufficentPermissions =
    [ paragraph [ Font.center ] [ text "You do not have permissions to view detainer warrant data." ] ]


earliestDate =
    Calendar.fromRawParts { day = 1, month = Jan, year = 2003 }


earliestDateThisYear d =
    d
        |> Calendar.setDay 1
        |> Maybe.andThen (Calendar.setMonth Jan)
        |> Maybe.withDefault d


viewExportForm cfg today model =
    column [ width fill, padding 20, spacing 20 ]
        [ row [ width (fill |> maximum 600) ]
            [ paragraph [] [ text "You may use the datepickers below to filter the dataset you'd like to download." ]
            ]
        , row [ width fill, spacing 20 ]
            [ column [ alignTop, width (fill |> maximum 280), spacing 10, Font.center ]
                [ UI.Text.renderElement cfg <| UI.Text.heading5 "Start date"
                , DatePicker.singleDatePicker
                    { toExternalMsg = ToStartDatePicker
                    , onSelectMsg = SelectExportStartDate
                    }
                    model.exportStartDatePicker
                    model.exportStartDate
                    |> DatePicker.withTodaysMark today
                    |> DatePicker.withRangeLimits earliestDate (Just today)
                    |> DatePicker.renderElement cfg
                , UI.Text.renderElement cfg <| UI.Text.caption "If you do not provide a start date, you will receive all detainer warrants we have going back up to 20 years or more."
                ]
            , Element.el
                [ width (px 5)
                , height fill
                , Border.rounded 5
                , UI.Palette.gray500
                    |> UI.Palette.toBackgroundColor
                ]
                Element.none
            , column [ alignTop, width (fill |> maximum 280), spacing 10, Font.center ]
                [ UI.Text.renderElement cfg <| UI.Text.heading5 "End date"
                , DatePicker.singleDatePicker
                    { toExternalMsg = ToEndDatePicker
                    , onSelectMsg = SelectExportEndDate
                    }
                    model.exportEndDatePicker
                    model.exportEndDate
                    |> DatePicker.withTodaysMark today
                    |> DatePicker.withRangeLimits earliestDate (Just today)
                    |> DatePicker.renderElement cfg
                , UI.Text.renderElement cfg <| UI.Text.caption "If you do not set an end date, you'll receive detainer warrants up until today."
                ]
            ]
        ]


viewExportDialog cfg today model =
    if model.showExportModal then
        Dialog.dialog "Download detainer warrants" (Icon.filter "Filter")
            |> Dialog.withBody (viewExportForm cfg today model)
            |> Dialog.withButtons
                [ Button.fromLabel "Download" |> Button.cmd Export Button.primary ]
            |> Just

    else
        Nothing


viewDesktop : RenderConfig -> User -> Model -> Element Msg
viewDesktop cfg profile model =
    column
        [ spacing 10
        , padding 10
        , width fill
        ]
        ((case model.alert of
            Just alert ->
                Alert.success
                    (Alert.text alert)
                    |> Alert.withGenericIcon
                    |> Alert.renderElement cfg

            Nothing ->
                Element.none
         )
            :: (if User.canViewCourtData profile then
                    [ viewActions cfg profile
                    , row [ centerX ] [ freeTextSearch cfg model.search.filters ]
                    , row [ width fill ]
                        (case model.search.totalMatches of
                            Just total ->
                                if total > 1 then
                                    [ paragraph [ Font.center ] [ text (FormatNumber.format { usLocale | decimals = Exact 0 } (toFloat total) ++ " detainer warrants matched your search.") ] ]

                                else
                                    []

                            Nothing ->
                                []
                        )
                    , row [ width fill ]
                        [ if model.search.totalMatches == Just 0 then
                            Maybe.withDefault Element.none <| Maybe.map viewEmptyResults model.search.previous

                          else
                            column
                                [ centerX
                                , Element.inFront (loader model)
                                , height (px 800)
                                , Element.scrollbarY
                                ]
                                [ viewWarrants cfg profile model ]
                        ]
                    ]

                else
                    insufficentPermissions
               )
        )


viewMobile : RenderConfig -> User -> Model -> Element Msg
viewMobile cfg profile model =
    column
        [ spacing 10
        , paddingXY 0 10
        , width fill
        ]
        (if User.canViewCourtData profile then
            [ viewActions cfg profile
            , row [ centerX ] [ freeTextSearch cfg model.search.filters ]
            , row [ width fill ]
                (case model.search.totalMatches of
                    Just total ->
                        if total > 1 then
                            [ paragraph [ Font.center ] [ text (FormatNumber.format { usLocale | decimals = Exact 0 } (toFloat total) ++ " detainer warrants matched your search.") ] ]

                        else
                            []

                    Nothing ->
                        []
                )
            , row [ width fill ]
                [ if model.search.totalMatches == Just 0 then
                    Maybe.withDefault Element.none <| Maybe.map viewEmptyResults model.search.previous

                  else
                    column
                        [ width fill
                        , Element.inFront (loader model)
                        , height (px 1000)
                        , Element.htmlAttribute (InfiniteScroll.infiniteScroll InfiniteScrollMsg)
                        ]
                        [ viewWarrants cfg profile model ]
                ]
            ]

         else
            insufficentPermissions
        )


type PageMsg
    = NoChanges


view :
    Maybe PageUrl
    -> Shared.Model
    -> Model
    -> StaticPayload Data RouteParams
    -> View Msg
view maybeUrl sharedModel model static =
    let
        cfg =
            sharedModel.renderConfig

        doc =
            Document.document DocumentMsg
                model.documentModel
                (\_ ->
                    Document.page title
                        (Document.bodySingle (viewBody cfg sharedModel model))
                        |> Document.pageWithDialog (viewExportDialog cfg (Calendar.fromPosix static.sharedData.runtime.todayPosix) model)
                )
                |> Document.toBrowserDocument cfg NoChanges
    in
    { title = doc.title
    , body = List.map Element.html doc.body
    }


viewBody cfg sharedModel model =
    Element.column [ width fill ] <|
        case Session.profile sharedModel.session of
            Nothing ->
                []

            Just profile ->
                [ Element.el [ width (px 0), height (px 0) ] (Element.html Sprite.all)
                , Element.el [ width fill, Element.htmlAttribute (Attrs.class "responsive-mobile") ]
                    (if RenderConfig.isPortrait cfg then
                        viewMobile cfg profile model

                     else
                        viewDesktop (RenderConfig.init { width = 800, height = 375 } RenderConfig.localeEnglish) profile model
                    )
                , Element.el [ width fill, Element.htmlAttribute (Attrs.class "responsive-desktop") ]
                    (viewDesktop cfg profile model)
                ]


loader : Model -> Element Msg
loader { infiniteScroll, search } =
    if InfiniteScroll.isLoading infiniteScroll || search.totalMatches == Nothing then
        row
            [ width fill
            , Element.alignBottom
            ]
            [ Element.el [ centerX, width Element.shrink, height Element.shrink ] (Element.html (Loader.horizontal Color.red)) ]

    else
        Element.none


viewEditButton : User -> DetainerWarrant -> Button Msg
viewEditButton profile warrant =
    let
        ( path, icon ) =
            if User.canViewDefendantInformation profile then
                ( "edit", Icon.edit "Go to edit page" )

            else
                ( "view", Icon.eye "View" )
    in
    Button.fromIcon icon
        |> Button.redirect
            (Link.link <|
                Url.Builder.absolute
                    [ "admin"
                    , "detainer-warrants"
                    , path
                    ]
                    (Endpoint.toQueryArgs [ ( "docket-id", warrant.docketId ) ])
            )
            Button.primary
        |> Button.withSize UI.Size.small


searchFilters : Search.DetainerWarrants -> Filters Msg DetainerWarrant T.Eight
searchFilters filters =
    filtersEmpty
        |> remoteSingleTextFilter filters.docketId InputDocketId
        |> remoteRangeDateFilter Time.utc filters.fileDateStart filters.fileDateEnd InputFileDate
        |> remoteSingleDateFilter Time.utc filters.courtDate InputCourtDate
        |> remoteSingleTextFilter filters.plaintiff InputPlaintiff
        |> remoteSingleTextFilter filters.plaintiffAttorney InputPlaintiffAttorney
        |> remoteSingleTextFilter filters.address InputAddress
        |> remoteSelectFilter (List.map (Maybe.withDefault "Not Audited" << Maybe.map DetainerWarrant.auditStatusName) DetainerWarrant.auditStatusOptions) Nothing SelectAuditStatus
        |> localSingleTextFilter Nothing .docketId


sortersInit : Sorters DetainerWarrant T.Eight
sortersInit =
    sortersEmpty
        |> sortBy .docketId
        |> sortBy (Maybe.withDefault "" << Maybe.map Time.Utils.toIsoString << .fileDate)
        |> sortBy (Maybe.withDefault "" << Maybe.map Time.Utils.toIsoString << DetainerWarrant.mostRecentCourtDate)
        |> sortBy (Maybe.withDefault "" << Maybe.map .name << .plaintiff)
        |> sortBy (Maybe.withDefault "" << Maybe.map .name << .plaintiffAttorney)
        |> sortBy (Maybe.withDefault "" << .address)
        |> unsortable
        |> unsortable


viewWarrants : RenderConfig -> User -> Model -> Element Msg
viewWarrants cfg profile model =
    Stateful.table
        { toExternalMsg = ForTable
        , columns = DetainerWarrant.tableColumns
        , toRow = DetainerWarrant.toTableRow cfg (viewEditButton profile)
        , state = model.tableState
        }
        |> Stateful.withResponsive
            { toDetails = DetainerWarrant.toTableDetails (viewEditButton profile)
            , toCover = DetainerWarrant.toTableCover
            }
        |> Stateful.withWidth fill
        |> Stateful.renderElement cfg


subscriptions : Maybe PageUrl -> RouteParams -> Path -> Model -> Sub Msg
subscriptions pageUrl params path model =
    Sub.none


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


type alias Data =
    ()


data : DataSource Data
data =
    DataSource.succeed ()


title =
    "RDC | Admin | Detainer Warrants"


head :
    StaticPayload Data RouteParams
    -> List Head.Tag
head static =
    Seo.summary
        { canonicalUrlOverride = Nothing
        , siteName = "Red Door Collective"
        , image = Logo.smallImage
        , description = "Manage detainer warrants"
        , locale = Nothing
        , title = title
        }
        |> Seo.website
