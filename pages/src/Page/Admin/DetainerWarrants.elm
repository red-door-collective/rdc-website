module Page.Admin.DetainerWarrants exposing (Data, Model, Msg, page)

import Browser.Navigation as Nav
import Color
import DataSource exposing (DataSource)
import DetainerWarrant exposing (DetainerWarrant)
import Element exposing (Element, centerX, column, fill, height, padding, paddingXY, paragraph, px, row, spacing, text, textColumn, width)
import Element.Font as Font
import FormatNumber
import FormatNumber.Locales exposing (Decimals(..), usLocale)
import Head
import Head.Seo as Seo
import Html.Attributes as Attrs
import Http
import InfiniteScroll
import Iso8601
import Loader
import Log
import Logo
import Maybe
import Page exposing (StaticPayload)
import Pages.PageUrl exposing (PageUrl)
import Path exposing (Path)
import QueryParams
import Rest exposing (Cred)
import Rest.Endpoint as Endpoint
import Result
import Rollbar exposing (Rollbar)
import Runtime
import Search exposing (Cursor(..), Search)
import Session exposing (Session)
import Shared
import Sprite
import Time
import Time.Utils
import UI.Button as Button exposing (Button)
import UI.Effects
import UI.Icon as Icon
import UI.Link as Link
import UI.RenderConfig as RenderConfig exposing (RenderConfig)
import UI.Size
import UI.Tables.Stateful as Stateful exposing (Filters, Sorters, filtersEmpty, localSingleTextFilter, remoteRangeDateFilter, remoteSingleDateFilter, remoteSingleTextFilter, sortBy, sortersEmpty, unsortable)
import UI.TextField as TextField
import UI.Utils.DateInput exposing (DateInput, RangeDate)
import UI.Utils.TypeNumbers as T
import Url.Builder
import View exposing (View)


type alias Model =
    { warrants : List DetainerWarrant
    , selected : Maybe String
    , hovered : Maybe String
    , search : Search Search.DetainerWarrants
    , tableState : Stateful.State Msg DetainerWarrant T.Eight
    , infiniteScroll : InfiniteScroll.Model Msg
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
    ( { warrants = []
      , search = search
      , selected = Nothing
      , hovered = Nothing
      , tableState =
            Stateful.init
                |> Stateful.stateWithFilters (searchFilters search.filters)
                |> Stateful.stateWithSorters sortersInit
      , infiniteScroll = InfiniteScroll.init (loadMore domain maybeCred search) |> InfiniteScroll.direction InfiniteScroll.Bottom
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


exportToSpreadsheet : String -> Session -> Cmd Msg
exportToSpreadsheet domain session =
    Rest.throwaway (Endpoint.detainerWarrantsExport domain) (Session.cred session) ExportStarted


type Msg
    = InputDocketId (Maybe String)
    | InputFileDate (Maybe RangeDate)
    | InputCourtDate (Maybe DateInput)
    | InputPlaintiff (Maybe String)
    | InputPlaintiffAttorney (Maybe String)
    | InputDefendant (Maybe String)
    | InputAddress (Maybe String)
    | ForTable (Stateful.Msg DetainerWarrant)
    | GotWarrants (Result Http.Error (Rest.Collection DetainerWarrant))
    | InfiniteScrollMsg InfiniteScroll.Msg
    | InputFreeTextSearch String
    | OnFreeTextSearch
    | ExportToSpreadsheet
    | ExportStarted (Result Http.Error ())
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

        InputDefendant query ->
            updateFiltersAndReload domain session (\filters -> { filters | defendant = query }) model

        InputAddress query ->
            updateFiltersAndReload domain session (\filters -> { filters | address = query }) model

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
                        model.warrants ++ detainerWarrantsPage.data
                  in
                  { updatedModel
                    | warrants = warrants
                    , infiniteScroll =
                        InfiniteScroll.stopLoading model.infiniteScroll
                            |> InfiniteScroll.loadMoreCmd (loadMore domain maybeCred search)
                    , tableState = Stateful.stateWithItems warrants model.tableState
                  }
                , Cmd.none
                )

            else
                ( { updatedModel
                    | warrants = detainerWarrantsPage.data
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

        ExportToSpreadsheet ->
            ( model, exportToSpreadsheet domain session )

        ExportStarted _ ->
            ( model, Cmd.none )

        NoOp ->
            ( model, Cmd.none )


error : Rollbar -> String -> Cmd Msg
error rollbar report =
    Log.error rollbar (\_ -> NoOp) report


createNewWarrantButton cfg =
    Button.fromLabel "Enter New Detainer Warrant"
        |> Button.redirect (Link.link <| "/admin/detainer-warrants/edit") Button.primary
        |> Button.renderElement cfg


uploadCsvButton cfg =
    Button.fromLabel "Upload via CaseLink CSV"
        |> Button.redirect (Link.link <| "/admin/detainer-warrants/bulk-upload") Button.primary
        |> Button.renderElement cfg


exportButton cfg =
    Button.fromLabel "Export to spreadsheet"
        |> Button.cmd ExportToSpreadsheet Button.primary
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
        , ifNonEmpty "defendant contains " identity filters.defendant
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


viewDesktop : RenderConfig -> Model -> Element Msg
viewDesktop cfg model =
    column
        [ spacing 10
        , padding 10
        , width fill
        ]
        [ Element.row [ centerX, spacing 10 ]
            [ createNewWarrantButton cfg
            , uploadCsvButton cfg
            , exportButton cfg
            ]
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
                    [ viewWarrants cfg model ]
            ]
        ]


viewMobile : RenderConfig -> Model -> Element Msg
viewMobile cfg model =
    column
        [ spacing 10
        , paddingXY 0 10
        , width fill
        ]
        [ row [ centerX, spacing 10 ]
            [ Button.fromIcon (Icon.add "Enter New Detainer Warrant")
                |> Button.redirect (Link.link <| "/admin/detainer-warrants/edit") Button.primary
                |> Button.renderElement cfg
            , Button.fromIcon (Icon.download "Upload via CaseLink CSV")
                |> Button.redirect (Link.link <| "/admin/detainer-warrants/bulk-upload") Button.primary
                |> Button.renderElement cfg
            ]
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
                    [ viewWarrants cfg model ]
            ]
        ]


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
    in
    { title = title
    , body =
        [ Element.el [ width (px 0), height (px 0) ] (Element.html Sprite.all)
        , Element.el [ width fill, Element.htmlAttribute (Attrs.class "responsive-mobile") ]
            (if RenderConfig.isPortrait cfg then
                viewMobile cfg model

             else
                viewDesktop (RenderConfig.init { width = 800, height = 375 } RenderConfig.localeEnglish) model
            )
        , Element.el [ width fill, Element.htmlAttribute (Attrs.class "responsive-desktop") ]
            (viewDesktop cfg model)
        ]
    }


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


viewEditButton : DetainerWarrant -> Button Msg
viewEditButton warrant =
    Button.fromIcon (Icon.edit "Go to edit page")
        |> Button.redirect
            (Link.link <|
                Url.Builder.absolute
                    [ "admin"
                    , "detainer-warrants"
                    , "edit"
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
        |> remoteSingleTextFilter filters.defendant InputDefendant
        |> remoteSingleTextFilter filters.address InputAddress
        |> localSingleTextFilter Nothing .docketId


sortersInit : Sorters DetainerWarrant T.Eight
sortersInit =
    sortersEmpty
        |> sortBy .docketId
        |> sortBy (Maybe.withDefault "" << Maybe.map Time.Utils.toIsoString << .fileDate)
        |> sortBy (Maybe.withDefault "" << Maybe.map Time.Utils.toIsoString << DetainerWarrant.mostRecentCourtDate)
        |> sortBy (Maybe.withDefault "" << Maybe.map .name << .plaintiff)
        |> sortBy (Maybe.withDefault "" << Maybe.map .name << .plaintiffAttorney)
        |> sortBy (Maybe.withDefault "" << Maybe.map .name << List.head << .defendants)
        |> sortBy (Maybe.withDefault "" << .address)
        |> unsortable


viewWarrants : RenderConfig -> Model -> Element Msg
viewWarrants cfg model =
    Stateful.table
        { toExternalMsg = ForTable
        , columns = DetainerWarrant.tableColumns
        , toRow = DetainerWarrant.toTableRow viewEditButton
        , state = model.tableState
        }
        |> Stateful.withResponsive
            { toDetails = DetainerWarrant.toTableDetails viewEditButton
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
