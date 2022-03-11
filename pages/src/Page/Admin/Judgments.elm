module Page.Admin.Judgments exposing (Data, Model, Msg, page)

import Browser.Navigation as Nav
import Color
import DataSource exposing (DataSource)
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
import Judgment exposing (Judgment)
import Loader
import Log
import Logo
import Maybe
import Page exposing (StaticPayload)
import Pages.PageUrl exposing (PageUrl)
import Path exposing (Path)
import QueryParams
import RemoteData exposing (RemoteData(..))
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
import UI.Tables.Stateful as Stateful exposing (Filters, Sorters, filtersEmpty, localSingleTextFilter, remoteSingleDateFilter, remoteSingleTextFilter, sortBy, sortersEmpty, unsortable)
import UI.Utils.DateInput exposing (DateInput)
import UI.Utils.TypeNumbers as T
import Url.Builder
import User exposing (User)
import View exposing (View)


type alias Model =
    { judgments : List Judgment
    , tableState : Stateful.State Msg Judgment T.Six
    , search : Search Search.Judgments
    , infiniteScroll : InfiniteScroll.Model Msg
    }


init :
    Maybe PageUrl
    -> Shared.Model
    -> StaticPayload Data RouteParams
    -> ( Model, Cmd Msg )
init pageUrl sharedModel static =
    let
        session =
            sharedModel.session

        domain =
            Runtime.domain static.sharedData.runtime.environment

        maybeCred =
            Session.cred session

        filters =
            Maybe.withDefault Search.judgmentsDefault <| Maybe.andThen (Maybe.map (Search.judgmentsFromString << QueryParams.toString) << .query) pageUrl

        search =
            { filters = filters, cursor = NewSearch, previous = Just filters, totalMatches = Nothing }
    in
    ( { judgments = []
      , search = search
      , tableState =
            Stateful.init
                |> Stateful.stateWithFilters (searchFilters search.filters)
                |> Stateful.stateWithSorters sortersInit
      , infiniteScroll = InfiniteScroll.init (loadMore domain maybeCred search) |> InfiniteScroll.direction InfiniteScroll.Bottom
      }
    , searchJudgments domain maybeCred search
    )


searchJudgments : String -> Maybe Cred -> Search Search.Judgments -> Cmd Msg
searchJudgments domain maybeCred search =
    Rest.get (Endpoint.judgmentsSearch domain (queryArgsWithPagination search)) maybeCred GotJudgments (Rest.collectionDecoder Judgment.decoder)


queryArgsWithPagination : Search Search.Judgments -> List ( String, String )
queryArgsWithPagination search =
    let
        filters =
            search.filters

        queryArgs =
            Search.judgmentsArgs filters
    in
    if Just search.filters == search.previous then
        case search.cursor of
            NewSearch ->
                queryArgs

            After judgmentsCursor ->
                ( "cursor", judgmentsCursor ) :: queryArgs

            End ->
                queryArgs

    else
        queryArgs


type Msg
    = InputDocketId (Maybe String)
    | InputFileDate (Maybe DateInput)
    | InputCourtDate (Maybe DateInput)
    | InputPlaintiff (Maybe String)
    | InputPlaintiffAttorney (Maybe String)
    | ForTable (Stateful.Msg Judgment)
    | GotJudgments (Result Rest.HttpError (Rest.Collection Judgment))
    | InfiniteScrollMsg InfiniteScroll.Msg
    | NoOp


updateFilters :
    (Search.Judgments -> Search.Judgments)
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
    -> (Search.Judgments -> Search.Judgments)
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
                            [ "admin", "judgments" ]
                            (Endpoint.toQueryArgs <| Search.judgmentsFilterArgs updatedModel.search.filters)
                )
                (Session.navKey session)
        , searchJudgments domain (Session.cred session) updatedModel.search
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


loadMore : String -> Maybe Cred -> Search Search.Judgments -> InfiniteScroll.Direction -> Cmd Msg
loadMore domain maybeCred search dir =
    case search.cursor of
        NewSearch ->
            Cmd.none

        After _ ->
            searchJudgments domain maybeCred search

        End ->
            Cmd.none


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
            updateFiltersAndReload domain session (\filters -> { filters | fileDate = Maybe.andThen (fromFormattedToPosix << UI.Utils.DateInput.toDD_MM_YYYY "-") query }) model

        InputCourtDate query ->
            updateFiltersAndReload domain session (\filters -> { filters | courtDate = Maybe.andThen (fromFormattedToPosix << UI.Utils.DateInput.toDD_MM_YYYY "-") query }) model

        InputPlaintiff query ->
            updateFiltersAndReload domain session (\filters -> { filters | plaintiff = query }) model

        InputPlaintiffAttorney query ->
            updateFiltersAndReload domain session (\filters -> { filters | plaintiffAttorney = query }) model

        ForTable subMsg ->
            let
                ( newTableState, newCmd ) =
                    Stateful.update subMsg model.tableState
            in
            ( { model | tableState = newTableState }, UI.Effects.perform newCmd )

        GotJudgments (Ok judgmentsPage) ->
            let
                maybeCred =
                    Session.cred sharedModel.session

                queryFilters =
                    Maybe.withDefault Search.judgmentsDefault <| Maybe.map Search.judgmentsFromString sharedModel.queryParams

                search =
                    { filters = queryFilters
                    , cursor = Maybe.withDefault End <| Maybe.map After judgmentsPage.meta.afterCursor
                    , previous = Just queryFilters
                    , totalMatches = Just judgmentsPage.meta.totalMatches
                    }

                updatedModel =
                    { model | search = search }
            in
            if updatedModel.search.previous == Just updatedModel.search.filters then
                ( let
                    judgments =
                        model.judgments ++ judgmentsPage.data
                  in
                  { updatedModel
                    | judgments = judgments
                    , infiniteScroll =
                        InfiniteScroll.stopLoading model.infiniteScroll
                            |> InfiniteScroll.loadMoreCmd (loadMore domain maybeCred search)
                    , tableState = Stateful.stateWithItems judgments model.tableState
                  }
                , Cmd.none
                )

            else
                ( { updatedModel
                    | judgments = judgmentsPage.data
                    , infiniteScroll =
                        InfiniteScroll.stopLoading model.infiniteScroll
                            |> InfiniteScroll.loadMoreCmd (loadMore domain maybeCred search)
                    , tableState = Stateful.stateWithItems judgmentsPage.data model.tableState
                  }
                , Cmd.none
                )

        GotJudgments (Err httpError) ->
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
        , ifNonEmpty "file date is " Time.Utils.toIsoString filters.fileDate
        , ifNonEmpty "court date is " Time.Utils.toIsoString filters.courtDate
        , ifNonEmpty "plaintiff contains " identity filters.plaintiff
        , ifNonEmpty "plaintiff attorney contains " identity filters.plaintiffAttorney
        ]


viewEmptyResults filters =
    textColumn [ centerX, spacing 10 ]
        ([ paragraph [ Font.center, centerX, Font.size 24 ]
            [ text "No judgments exist matching your search criteria:" ]
         , paragraph [ centerX, Font.italic, Font.center ]
            [ text "where..." ]
         ]
            ++ (List.intersperse (paragraph [ centerX, Font.center ] [ text "&" ]) <| viewFilter filters)
        )


insufficentPermissions =
    [ paragraph [ Font.center ] [ text "You do not have permissions to view judgment data." ] ]


viewDesktop : RenderConfig -> User -> Model -> Element Msg
viewDesktop cfg profile model =
    column
        [ spacing 10
        , padding 10
        , width fill
        ]
        (if User.canViewCourtData profile then
            [ row [ width fill ]
                (case model.search.totalMatches of
                    Just total ->
                        if total > 1 then
                            [ paragraph [ Font.center ] [ text (FormatNumber.format { usLocale | decimals = Exact 0 } (toFloat total) ++ " judgments matched your search.") ] ]

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
                        [ viewJudgments cfg profile model ]
                ]
            ]

         else
            insufficentPermissions
        )


viewMobile : RenderConfig -> User -> Model -> Element Msg
viewMobile cfg profile model =
    column
        [ spacing 10
        , paddingXY 0 10
        , width fill
        ]
        (if User.canViewCourtData profile then
            [ row [ width fill ]
                (case model.search.totalMatches of
                    Just total ->
                        if total > 1 then
                            [ paragraph [ Font.center ] [ text (FormatNumber.format { usLocale | decimals = Exact 0 } (toFloat total) ++ " judgments matched your search.") ] ]

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
                        [ viewJudgments cfg profile model ]
                ]
            ]

         else
            insufficentPermissions
        )


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
        case Session.profile sharedModel.session of
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

            Nothing ->
                []
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


viewEditButton : User -> Judgment -> Button Msg
viewEditButton profile judgment =
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
                    , "judgments"
                    , path
                    ]
                    (Endpoint.toQueryArgs [ ( "id", String.fromInt judgment.id ) ])
            )
            Button.primary
        |> Button.withSize UI.Size.small


searchFilters : Search.Judgments -> Filters Msg Judgment T.Six
searchFilters filters =
    filtersEmpty
        |> remoteSingleTextFilter filters.docketId InputDocketId
        |> remoteSingleDateFilter Time.utc filters.fileDate InputFileDate
        |> remoteSingleDateFilter Time.utc filters.courtDate InputCourtDate
        |> remoteSingleTextFilter filters.plaintiff InputPlaintiff
        |> remoteSingleTextFilter filters.plaintiffAttorney InputPlaintiffAttorney
        |> localSingleTextFilter Nothing .docketId


sortersInit : Sorters Judgment T.Six
sortersInit =
    sortersEmpty
        |> sortBy .docketId
        |> sortBy (Maybe.withDefault "" << Maybe.map Time.Utils.toIsoString << .fileDate)
        |> sortBy (Time.Utils.toIsoString << .courtDate << .hearing)
        |> sortBy (Maybe.withDefault "" << Maybe.map .name << .plaintiff)
        |> sortBy (Maybe.withDefault "" << Maybe.map .name << .plaintiffAttorney)
        |> unsortable


viewJudgments : RenderConfig -> User -> Model -> Element Msg
viewJudgments cfg profile model =
    Stateful.table
        { toExternalMsg = ForTable
        , columns = Judgment.tableColumns
        , toRow = Judgment.toTableRow (viewEditButton profile)
        , state = model.tableState
        }
        |> Stateful.withResponsive
            { toDetails = Judgment.toTableDetails (viewEditButton profile)
            , toCover = Judgment.toTableCover
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
    "RDC | Admin | Judgments"


head :
    StaticPayload Data RouteParams
    -> List Head.Tag
head static =
    Seo.summary
        { canonicalUrlOverride = Nothing
        , siteName = "Red Door Collective"
        , image = Logo.smallImage
        , description = "Manage judgments"
        , locale = Nothing
        , title = title
        }
        |> Seo.website
