module Page.Admin.DetainerWarrants exposing (Data, Model, Msg, page)

import Browser.Navigation as Nav
import Color
import DataSource exposing (DataSource)
import Date exposing (Date)
import DatePicker exposing (ChangeEvent(..))
import DetainerWarrant exposing (DatePickerState, DetainerWarrant, Status(..), TableCellConfig, tableCellAttrs, viewDocketId, viewHeaderCell, viewTextRow)
import Element exposing (Element, centerX, column, fill, height, image, link, maximum, minimum, padding, paddingXY, paragraph, px, row, spacing, table, text, textColumn, width)
import Element.Background as Background
import Element.Border as Border
import Element.Events as Events
import Element.Font as Font
import Element.Input as Input
import FeatherIcons
import FormatNumber
import FormatNumber.Locales exposing (Decimals(..), usLocale)
import Head
import Head.Seo as Seo
import Html
import Html.Attributes as Attrs
import Html.Events
import Http exposing (Error(..))
import InfiniteScroll
import Iso8601
import Json.Decode as Decode
import Loader
import Log
import Logo
import Maybe.Extra
import Page exposing (Page, PageWithState, StaticPayload)
import Pages.PageUrl exposing (PageUrl)
import Pages.Url
import Palette
import Path exposing (Path)
import QueryParams
import Rest exposing (Cred)
import Rest.Endpoint as Endpoint exposing (Endpoint)
import Result
import Rollbar exposing (Rollbar)
import Route
import Runtime exposing (Runtime)
import Search exposing (Cursor(..), Search)
import Session exposing (Session)
import Settings exposing (Settings)
import Shared
import Sprite
import Svg
import Svg.Attributes
import Time
import UI.Button as Button exposing (Button)
import UI.Effects
import UI.Icon
import UI.Link as Link
import UI.Palette as Palette
import UI.RenderConfig as RenderConfig exposing (Locale, RenderConfig)
import UI.Size
import UI.Tables.Stateful as Stateful exposing (Filters, Sorters, detailHidden, detailShown, detailsEmpty, filtersEmpty, localSingleTextFilter, remoteSingleDateFilter, remoteSingleTextFilter, sortBy, sortersEmpty, unsortable)
import UI.Text as Text
import UI.TextField as TextField
import UI.Utils.Focus as Focus
import UI.Utils.TypeNumbers as T exposing (Increase)
import Url.Builder exposing (QueryParameter)
import User exposing (User)
import View exposing (View)


type alias Model =
    { warrants : List DetainerWarrant
    , selected : Maybe String
    , hovered : Maybe String
    , search : Search Search.DetainerWarrants
    , tableState :
        Stateful.State Msg DetainerWarrant T.Eight
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


type Msg
    = InputDocketId (Maybe String)
    | InputFileDate (Maybe String)
    | InputCourtDate (Maybe String)
    | InputPlaintiff (Maybe String)
    | InputPlaintiffAttorney (Maybe String)
    | InputDefendant (Maybe String)
    | InputAddress (Maybe String)
    | SelectWarrant String
    | HoverWarrant String
    | ForTable (Stateful.Msg DetainerWarrant)
    | GotWarrants (Result Http.Error (Rest.Collection DetainerWarrant))
    | InfiniteScrollMsg InfiniteScroll.Msg
    | NoOp


updateFilters :
    String
    -> Session
    -> (Search.DetainerWarrants -> Search.DetainerWarrants)
    -> Model
    -> ( Model, Cmd Msg )
updateFilters domain session transform model =
    let
        search =
            model.search

        updatedModel =
            { model | search = { search | filters = transform search.filters } }
    in
    ( updatedModel
    , Cmd.batch
        [ Maybe.withDefault Cmd.none <|
            Maybe.map
                (\key ->
                    Nav.replaceUrl key <|
                        Url.Builder.absolute
                            [ "admin", "detainer-warrants" ]
                            (Endpoint.toQueryArgs <| Search.detainerWarrantsArgs updatedModel.search.filters)
                )
                (Session.navKey session)
        , searchWarrants domain (Session.cred session) updatedModel.search
        ]
    )


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
            updateFilters domain session (\filters -> { filters | docketId = query }) model

        InputFileDate query ->
            updateFilters domain session (\filters -> { filters | fileDate = Maybe.andThen (Result.toMaybe << Date.fromIsoString) query }) model

        InputCourtDate query ->
            updateFilters domain session (\filters -> { filters | courtDate = Maybe.andThen (Result.toMaybe << Date.fromIsoString) query }) model

        InputPlaintiff query ->
            updateFilters domain session (\filters -> { filters | plaintiff = query }) model

        InputPlaintiffAttorney query ->
            updateFilters domain session (\filters -> { filters | plaintiffAttorney = query }) model

        InputDefendant query ->
            updateFilters domain session (\filters -> { filters | defendant = query }) model

        InputAddress query ->
            updateFilters domain session (\filters -> { filters | address = query }) model

        SelectWarrant docketId ->
            ( { model | selected = Just docketId }, Cmd.none )

        HoverWarrant docketId ->
            ( { model | hovered = Just docketId }, Cmd.none )

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
        , ifNonEmpty "file date is " Date.toIsoString filters.fileDate
        , ifNonEmpty "court date is " Date.toIsoString filters.courtDate
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
            ]
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


viewMobile cfg model =
    column
        [ spacing 10
        , paddingXY 0 10
        , width fill
        ]
        [ row [ centerX, spacing 10 ]
            [ Button.fromIcon (UI.Icon.add "Enter New Detainer Warrant")
                |> Button.redirect (Link.link <| "/admin/detainer-warrants/edit") Button.primary
                |> Button.renderElement cfg
            , Button.fromIcon (UI.Icon.download "Upload via CaseLink CSV")
                |> Button.redirect (Link.link <| "/admin/detainer-warrants/bulk-upload") Button.primary
                |> Button.renderElement cfg
            ]
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


viewEditButton : RenderConfig -> DetainerWarrant -> Button Msg
viewEditButton cfg warrant =
    Button.fromIcon (UI.Icon.edit "Go to edit page")
        |> Button.redirect
            (Link.link <|
                Url.Builder.relative
                    [ "detainer-warrants"
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
        |> remoteSingleTextFilter (Maybe.map Date.toIsoString filters.fileDate) InputFileDate
        |> remoteSingleTextFilter (Maybe.map Date.toIsoString filters.courtDate) InputCourtDate
        |> remoteSingleTextFilter filters.plaintiff InputPlaintiff
        |> remoteSingleTextFilter filters.plaintiffAttorney InputPlaintiffAttorney
        |> remoteSingleTextFilter filters.defendant InputDefendant
        |> remoteSingleTextFilter filters.address InputAddress
        |> localSingleTextFilter Nothing .docketId


sortersInit : Sorters DetainerWarrant T.Eight
sortersInit =
    sortersEmpty
        |> sortBy .docketId
        |> sortBy (Maybe.withDefault "" << Maybe.map Date.toIsoString << .fileDate)
        |> sortBy (Maybe.withDefault "" << Maybe.map Date.toIsoString << .courtDate)
        |> sortBy (Maybe.withDefault "" << Maybe.map .name << .plaintiff)
        |> sortBy (Maybe.withDefault "" << Maybe.map .name << .plaintiffAttorney)
        |> sortBy (Maybe.withDefault "" << Maybe.map .name << List.head << .defendants)
        |> sortBy (Maybe.withDefault "" << Maybe.map .address << List.head << .defendants)
        |> unsortable


viewWarrants : RenderConfig -> Model -> Element Msg
viewWarrants cfg model =
    Stateful.table
        { toExternalMsg = ForTable
        , columns = DetainerWarrant.tableColumns
        , toRow = DetainerWarrant.toTableRow (viewEditButton cfg)
        , state = model.tableState
        }
        |> Stateful.withResponsive
            { toDetails = DetainerWarrant.toTableDetails (viewEditButton cfg)
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
