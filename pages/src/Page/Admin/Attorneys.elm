module Page.Admin.Attorneys exposing (Data, Model, Msg, page)

import Browser.Navigation as Nav
import Color
import DataSource exposing (DataSource)
import Element exposing (Element, centerX, column, fill, height, padding, paragraph, px, row, spacing, text, textColumn, width)
import Element.Font as Font
import FormatNumber
import FormatNumber.Locales exposing (Decimals(..), usLocale)
import Head
import Head.Seo as Seo
import Http
import InfiniteScroll
import Loader
import Log
import Logo
import Page exposing (StaticPayload)
import Pages.PageUrl exposing (PageUrl)
import Path exposing (Path)
import Plaintiff exposing (Plaintiff)
import QueryParams
import Rest exposing (Cred)
import Rest.Endpoint as Endpoint
import Rollbar exposing (Rollbar)
import Runtime
import Search exposing (Cursor(..), Search)
import Session exposing (Session)
import Shared
import Sprite
import UI.Button as Button exposing (Button)
import UI.Effects
import UI.Icon as Icon
import UI.Link as Link
import UI.RenderConfig exposing (RenderConfig)
import UI.Size
import UI.Tables.Stateful as Stateful exposing (Filters, Sorters, filtersEmpty, localSingleTextFilter, remoteSingleTextFilter, sortBy, sortersEmpty, unsortable)
import UI.Utils.TypeNumbers as T
import Url.Builder
import View exposing (View)


type alias Model =
    { attorneys : List Plaintiff
    , tableState : Stateful.State Msg Plaintiff T.Three
    , search : Search Search.Attorneys
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
            Maybe.withDefault Search.attorneysDefault <| Maybe.andThen (Maybe.map (Search.attorneysFromString << QueryParams.toString) << .query) pageUrl

        search =
            { filters = filters, cursor = NewSearch, previous = Just filters, totalMatches = Nothing }
    in
    ( { attorneys = []
      , search = search
      , tableState =
            Stateful.init
                |> Stateful.stateWithFilters (searchFilters search.filters)
                |> Stateful.stateWithSorters sortersInit
      , infiniteScroll = InfiniteScroll.init (loadMore domain maybeCred search) |> InfiniteScroll.direction InfiniteScroll.Bottom
      }
    , searchAttorneys domain maybeCred search
    )


searchFilters : Search.Attorneys -> Filters Msg Plaintiff T.Three
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


searchAttorneys : String -> Maybe Cred -> Search Search.Attorneys -> Cmd Msg
searchAttorneys domain maybeCred search =
    Rest.get (Endpoint.attorneysSearch domain (queryArgsWithPagination search)) maybeCred GotAttorneys (Rest.collectionDecoder Plaintiff.decoder)


loadMore : String -> Maybe Cred -> Search Search.Attorneys -> InfiniteScroll.Direction -> Cmd Msg
loadMore domain maybeCred search dir =
    case search.cursor of
        NewSearch ->
            Cmd.none

        After _ ->
            searchAttorneys domain maybeCred search

        End ->
            Cmd.none


queryArgsWithPagination : Search Search.Attorneys -> List ( String, String )
queryArgsWithPagination search =
    let
        filters =
            search.filters

        queryArgs =
            Search.attorneysArgs filters
    in
    if Just search.filters == search.previous then
        case search.cursor of
            NewSearch ->
                queryArgs

            After attorneysCursor ->
                ( "cursor", attorneysCursor ) :: queryArgs

            End ->
                queryArgs

    else
        queryArgs


type Msg
    = InputName (Maybe String)
    | InputAliases (Maybe String)
    | ForTable (Stateful.Msg Plaintiff)
    | GotAttorneys (Result Rest.HttpError (Rest.Collection Plaintiff))
    | NoOp


updateFiltersAndReload :
    String
    -> Session
    -> (Search.Attorneys -> Search.Attorneys)
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
                (\key -> Nav.replaceUrl key (Url.Builder.absolute [ "admin", "attorneys" ] (Endpoint.toQueryArgs <| Search.attorneysArgs updatedModel.search.filters)))
                (Session.navKey session)
        , searchAttorneys domain (Session.cred session) updatedModel.search
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

        GotAttorneys (Ok attorneysPage) ->
            let
                maybeCred =
                    Session.cred session

                search =
                    { filters = model.search.filters
                    , cursor = Maybe.withDefault End <| Maybe.map After attorneysPage.meta.afterCursor
                    , previous = Just model.search.filters
                    , totalMatches = Just attorneysPage.meta.totalMatches
                    }

                updatedModel =
                    { model | search = search }
            in
            if model.search.previous == Just model.search.filters then
                let
                    attorneys =
                        model.attorneys ++ attorneysPage.data
                in
                ( { updatedModel
                    | attorneys = attorneys
                    , infiniteScroll =
                        InfiniteScroll.stopLoading model.infiniteScroll
                            |> InfiniteScroll.loadMoreCmd (loadMore domain maybeCred search)
                    , tableState = Stateful.stateWithItems attorneys model.tableState
                  }
                , Cmd.none
                )

            else
                ( { updatedModel
                    | attorneys = attorneysPage.data
                    , infiniteScroll =
                        InfiniteScroll.stopLoading model.infiniteScroll
                            |> InfiniteScroll.loadMoreCmd (loadMore domain maybeCred search)
                    , tableState = Stateful.stateWithItems attorneysPage.data model.tableState
                  }
                , Cmd.none
                )

        GotAttorneys (Err httpError) ->
            ( model, logHttpError httpError )

        NoOp ->
            ( model, Cmd.none )


error : Rollbar -> String -> Cmd Msg
error rollbar report =
    Log.error rollbar (\_ -> NoOp) report


createNewPlaintiff : RenderConfig -> Element Msg
createNewPlaintiff cfg =
    row [ centerX ]
        [ Button.fromLabel "Create New Plaintiff"
            |> Button.redirect (Link.link <| "/admin/attorneys/edit") Button.primary
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
            [ text "No attorneys exist matching your search criteria:" ]
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
                Url.Builder.absolute
                    [ "admin"
                    , "attorneys"
                    , "edit"
                    ]
                    (Endpoint.toQueryArgs [ ( "id", String.fromInt plaintiff.id ) ])
            )
            Button.primary
        |> Button.withSize UI.Size.small


viewAttorneys : RenderConfig -> Model -> Element Msg
viewAttorneys cfg model =
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
                        paragraph [ Font.center ] [ text (FormatNumber.format { usLocale | decimals = Exact 0 } (toFloat total) ++ " attorneys matched your search.") ]

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
                    [ viewAttorneys cfg model
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
    "RDC | Admin | Attorneys"


head :
    StaticPayload Data RouteParams
    -> List Head.Tag
head static =
    Seo.summary
        { canonicalUrlOverride = Nothing
        , siteName = "Red Door Collective"
        , image = Logo.smallImage
        , description = "Manage attorneys"
        , locale = Nothing
        , title = title
        }
        |> Seo.website
