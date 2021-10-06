module Page.Admin.Plaintiffs exposing (Data, Model, Msg, page)

import Browser.Navigation as Nav
import Color
import DataSource exposing (DataSource)
import Date exposing (Date)
import DatePicker exposing (ChangeEvent(..))
import Element exposing (Element, centerX, column, fill, height, image, link, maximum, minimum, padding, paragraph, px, row, spacing, table, text, textColumn, width)
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
import Html.Attributes
import Html.Events
import Http exposing (Error(..))
import InfiniteScroll
import Json.Decode as Decode
import Loader
import Log
import Logo
import Maybe.Extra
import Page exposing (Page, PageWithState, StaticPayload)
import Pages.PageUrl exposing (PageUrl)
import Pages.Url
import Path exposing (Path)
import Plaintiff exposing (Plaintiff)
import QueryParams
import Rest exposing (Cred)
import Rest.Endpoint as Endpoint exposing (Endpoint)
import Rollbar exposing (Rollbar)
import Route
import Runtime exposing (Runtime)
import Search exposing (Cursor(..), Search)
import Session exposing (Session)
import Settings exposing (Settings)
import Shared
import Sprite
import UI.Button as Button exposing (Button)
import UI.Effects
import UI.Icon as Icon
import UI.Link as Link
import UI.Palette as Palette
import UI.RenderConfig as RenderConfig exposing (Locale, RenderConfig)
import UI.Size
import UI.Tables.Stateful as Stateful exposing (Filters, Sorters, detailHidden, detailShown, detailsEmpty, filtersEmpty, localSingleTextFilter, remoteSingleDateFilter, remoteSingleTextFilter, sortBy, sortersEmpty, unsortable)
import UI.Text as Text
import UI.TextField as TextField
import UI.Utils.TypeNumbers as T
import Url.Builder exposing (QueryParameter)
import User exposing (User)
import View exposing (View)
import Widget
import Widget.Icon


type alias Model =
    { plaintiffs : List Plaintiff
    , tableState : Stateful.State Msg Plaintiff T.Three
    , search : Search Search.Plaintiffs
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
            Maybe.withDefault Search.plaintiffsDefault <| Maybe.andThen (Maybe.map (Search.plaintiffsFromString << QueryParams.toString) << .query) pageUrl

        search =
            { filters = filters, cursor = NewSearch, previous = Just filters, totalMatches = Nothing }
    in
    ( { plaintiffs = []
      , search = search
      , tableState =
            Stateful.init
                |> Stateful.stateWithFilters (searchFilters search.filters)
                |> Stateful.stateWithSorters sortersInit
      , infiniteScroll = InfiniteScroll.init (loadMore domain maybeCred search) |> InfiniteScroll.direction InfiniteScroll.Bottom
      }
    , searchPlaintiffs domain maybeCred search
    )


searchFilters : Search.Plaintiffs -> Filters Msg Plaintiff T.Three
searchFilters filters =
    filtersEmpty
        |> remoteSingleTextFilter filters.name InputName
        |> remoteSingleTextFilter filters.aliases InputAliases
        |> localSingleTextFilter Nothing .name


sortersInit : Sorters Plaintiff T.Three
sortersInit =
    sortersEmpty
        |> sortBy .name
        |> sortBy (String.join ", " << .aliases)
        |> unsortable


searchPlaintiffs : String -> Maybe Cred -> Search Search.Plaintiffs -> Cmd Msg
searchPlaintiffs domain maybeCred search =
    Rest.get (Endpoint.plaintiffsSearch domain (queryArgsWithPagination search)) maybeCred GotPlaintiffs (Rest.collectionDecoder Plaintiff.decoder)


loadMore : String -> Maybe Cred -> Search Search.Plaintiffs -> InfiniteScroll.Direction -> Cmd Msg
loadMore domain maybeCred search dir =
    case search.cursor of
        NewSearch ->
            Cmd.none

        After _ ->
            searchPlaintiffs domain maybeCred search

        End ->
            Cmd.none


queryArgsWithPagination : Search Search.Plaintiffs -> List ( String, String )
queryArgsWithPagination search =
    let
        filters =
            search.filters

        queryArgs =
            Search.plaintiffsArgs filters
    in
    if Just search.filters == search.previous then
        case search.cursor of
            NewSearch ->
                queryArgs

            After plaintiffsCursor ->
                ( "cursor", plaintiffsCursor ) :: queryArgs

            End ->
                queryArgs

    else
        queryArgs


type Msg
    = InputName (Maybe String)
    | InputAliases (Maybe String)
    | ForTable (Stateful.Msg Plaintiff)
    | GotPlaintiffs (Result Http.Error (Rest.Collection Plaintiff))
    | InfiniteScrollMsg InfiniteScroll.Msg
    | NoOp


updateFiltersAndReload :
    String
    -> Session
    -> (Search.Plaintiffs -> Search.Plaintiffs)
    -> Model
    -> ( Model, Cmd Msg )
updateFiltersAndReload domain session transform model =
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
                (\key -> Nav.replaceUrl key (Url.Builder.absolute [ "admin", "plaintiffs" ] (Endpoint.toQueryArgs <| Search.plaintiffsArgs updatedModel.search.filters)))
                (Session.navKey session)
        , searchPlaintiffs domain (Session.cred session) updatedModel.search
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

        session =
            sharedModel.session

        domain =
            Runtime.domain static.sharedData.runtime.environment

        logHttpError =
            error rollbar << Log.httpErrorMessage
    in
    case msg of
        InputName query ->
            updateFiltersAndReload domain session (\filters -> { filters | name = query }) model

        InputAliases query ->
            updateFiltersAndReload domain session (\filters -> { filters | aliases = query }) model

        ForTable subMsg ->
            let
                ( newTableState, newCmd ) =
                    Stateful.update subMsg model.tableState
            in
            ( { model | tableState = newTableState }, UI.Effects.perform newCmd )

        GotPlaintiffs (Ok plaintiffsPage) ->
            let
                maybeCred =
                    Session.cred session

                search =
                    { filters = model.search.filters
                    , cursor = Maybe.withDefault End <| Maybe.map After plaintiffsPage.meta.afterCursor
                    , previous = Just model.search.filters
                    , totalMatches = Just plaintiffsPage.meta.totalMatches
                    }

                updatedModel =
                    { model | search = search }
            in
            if model.search.previous == Just model.search.filters then
                let
                    plaintiffs =
                        model.plaintiffs ++ plaintiffsPage.data
                in
                ( { updatedModel
                    | plaintiffs = plaintiffs
                    , infiniteScroll =
                        InfiniteScroll.stopLoading model.infiniteScroll
                            |> InfiniteScroll.loadMoreCmd (loadMore domain maybeCred search)
                    , tableState = Stateful.stateWithItems plaintiffs model.tableState
                  }
                , Cmd.none
                )

            else
                ( { updatedModel
                    | plaintiffs = plaintiffsPage.data
                    , infiniteScroll =
                        InfiniteScroll.stopLoading model.infiniteScroll
                            |> InfiniteScroll.loadMoreCmd (loadMore domain maybeCred search)
                    , tableState = Stateful.stateWithItems plaintiffsPage.data model.tableState
                  }
                , Cmd.none
                )

        GotPlaintiffs (Err httpError) ->
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


createNewPlaintiff : RenderConfig -> Element Msg
createNewPlaintiff cfg =
    row [ centerX ]
        [ Button.fromLabel "Create New Plaintiff"
            |> Button.redirect (Link.link <| "/admin/plaintiffs/edit") Button.primary
            |> Button.renderElement cfg
        ]


viewFilter filters =
    let
        ifNonEmpty prefix fn filter =
            case filter of
                Just value ->
                    [ paragraph [ centerX, Font.center ] [ text (prefix ++ fn value) ] ]

                Nothing ->
                    []
    in
    List.concat
        [ ifNonEmpty "name is " identity filters.name
        ]


viewEmptyResults filters =
    textColumn [ centerX, spacing 10 ]
        ([ paragraph [ Font.center, centerX, Font.size 24 ]
            [ text "No plaintiffs exist matching your search criteria:" ]
         , paragraph [ centerX, Font.italic, Font.center ]
            [ text "where..." ]
         ]
            ++ (List.intersperse (paragraph [ centerX, Font.center ] [ text "&" ]) <| viewFilter filters)
        )


viewEditButton : Plaintiff -> Button Msg
viewEditButton plaintiff =
    Button.fromIcon (Icon.edit "Go to edit page")
        |> Button.redirect
            (Link.link <|
                Url.Builder.relative
                    [ "plaintiffs"
                    , "edit"
                    ]
                    (Endpoint.toQueryArgs [ ( "id", String.fromInt plaintiff.id ) ])
            )
            Button.primary
        |> Button.withSize UI.Size.small


viewPlaintiffs : RenderConfig -> Model -> Element Msg
viewPlaintiffs cfg model =
    Stateful.table
        { toExternalMsg = ForTable
        , columns = Plaintiff.tableColumns
        , toRow = Plaintiff.toTableRow viewEditButton
        , state = model.tableState
        }
        |> Stateful.withResponsive
            { toDetails = Plaintiff.toTableDetails viewEditButton
            , toCover = Plaintiff.toTableCover
            }
        |> Stateful.withWidth fill
        |> Stateful.renderElement cfg


viewDesktop cfg model =
    column
        [ centerX
        , spacing 10
        , padding 10
        ]
        [ createNewPlaintiff cfg
        , row [ width fill ]
            [ case model.search.totalMatches of
                Just total ->
                    if total > 1 then
                        paragraph [ Font.center ] [ text (FormatNumber.format { usLocale | decimals = Exact 0 } (toFloat total) ++ " plaintiffs matched your search.") ]

                    else
                        Element.none

                Nothing ->
                    Element.none
            ]
        , row [ width fill ]
            [ if model.search.totalMatches == Just 0 then
                Maybe.withDefault Element.none <| Maybe.map viewEmptyResults model.search.previous

              else
                column
                    [ centerX
                    , Element.inFront (loader model)
                    , height (px 800)
                    , width fill
                    , Element.scrollbarY
                    ]
                    [ viewPlaintiffs cfg model
                    ]
            ]
        ]


view :
    Maybe PageUrl
    -> Shared.Model
    -> Model
    -> StaticPayload Data RouteParams
    -> View Msg
view maybeUrl sharedModel model static =
    { title = title
    , body =
        [ Element.el [ width (px 0), height (px 0) ] (Element.html Sprite.all)
        , viewDesktop sharedModel.renderConfig model
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
    "RDC | Admin | Plaintiffs"


head :
    StaticPayload Data RouteParams
    -> List Head.Tag
head static =
    Seo.summary
        { canonicalUrlOverride = Nothing
        , siteName = "Red Door Collective"
        , image = Logo.smallImage
        , description = "Manage plaintiffs"
        , locale = Nothing
        , title = title
        }
        |> Seo.website
