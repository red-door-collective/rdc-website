module Page.Admin.Defendants exposing (Data, Model, Msg, page)

import Browser.Navigation as Nav
import Color
import DataSource exposing (DataSource)
import Defendant exposing (Defendant)
import Element exposing (Element, centerX, column, el, fill, height, padding, paragraph, px, row, spacing, text, textColumn, width)
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
import QueryParams
import RemoteData exposing (RemoteData(..))
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
import User
import View exposing (View)


type alias Model =
    { defendants : List Defendant
    , tableState : Stateful.State Msg Defendant T.Four
    , search : Search Search.Defendants
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
            Maybe.withDefault Search.defendantsDefault <| Maybe.andThen (Maybe.map (Search.defendantsFromString << QueryParams.toString) << .query) pageUrl

        search =
            { filters = filters, cursor = NewSearch, previous = Just filters, totalMatches = Nothing }
    in
    ( { defendants = []
      , search = search
      , tableState =
            Stateful.init
                |> Stateful.stateWithFilters (searchFilters search.filters)
                |> Stateful.stateWithSorters sortersInit
      , infiniteScroll = InfiniteScroll.init (loadMore domain maybeCred search) |> InfiniteScroll.direction InfiniteScroll.Bottom
      }
    , case sharedModel.profile of
        NotAsked ->
            Cmd.none

        Loading ->
            Cmd.none

        Success profile ->
            if User.canViewDefendantInformation profile then
                searchDefendants domain maybeCred search

            else
                Cmd.none

        Failure _ ->
            Cmd.none
    )


searchFilters : Search.Defendants -> Filters Msg Defendant T.Four
searchFilters filters =
    filtersEmpty
        |> remoteSingleTextFilter filters.firstName InputFirstName
        |> remoteSingleTextFilter filters.lastName InputLastName
        |> localSingleTextFilter Nothing .name
        |> localSingleTextFilter Nothing .name


sortersInit : Sorters Defendant T.Four
sortersInit =
    sortersEmpty
        |> sortBy .firstName
        |> sortBy .lastName
        |> unsortable
        |> unsortable


searchDefendants : String -> Maybe Cred -> Search Search.Defendants -> Cmd Msg
searchDefendants domain maybeCred search =
    Rest.get (Endpoint.defendantsSearch domain (queryArgsWithPagination search)) maybeCred GotDefendants (Rest.collectionDecoder Defendant.decoder)


loadMore : String -> Maybe Cred -> Search Search.Defendants -> InfiniteScroll.Direction -> Cmd Msg
loadMore domain maybeCred search dir =
    case search.cursor of
        NewSearch ->
            Cmd.none

        After _ ->
            searchDefendants domain maybeCred search

        End ->
            Cmd.none


queryArgsWithPagination : Search Search.Defendants -> List ( String, String )
queryArgsWithPagination search =
    let
        filters =
            search.filters

        queryArgs =
            Search.defendantsArgs filters
    in
    if Just search.filters == search.previous then
        case search.cursor of
            NewSearch ->
                queryArgs

            After defendantsCursor ->
                ( "cursor", defendantsCursor ) :: queryArgs

            End ->
                queryArgs

    else
        queryArgs


type Msg
    = InputFirstName (Maybe String)
    | InputLastName (Maybe String)
    | ForTable (Stateful.Msg Defendant)
    | GotDefendants (Result Http.Error (Rest.Collection Defendant))
    | NoOp


updateFiltersAndReload :
    String
    -> Session
    -> (Search.Defendants -> Search.Defendants)
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
                (\key -> Nav.replaceUrl key (Url.Builder.absolute [ "admin", "defendants" ] (Endpoint.toQueryArgs <| Search.defendantsArgs updatedModel.search.filters)))
                (Session.navKey session)
        , searchDefendants domain (Session.cred session) updatedModel.search
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
        InputFirstName query ->
            updateFiltersAndReload domain session (\filters -> { filters | firstName = query }) model

        InputLastName query ->
            updateFiltersAndReload domain session (\filters -> { filters | lastName = query }) model

        ForTable subMsg ->
            let
                ( newTableState, newCmd ) =
                    Stateful.update subMsg model.tableState
            in
            ( { model | tableState = newTableState }, UI.Effects.perform newCmd )

        GotDefendants (Ok defendantsPage) ->
            let
                maybeCred =
                    Session.cred session

                search =
                    { filters = model.search.filters
                    , cursor = Maybe.withDefault End <| Maybe.map After defendantsPage.meta.afterCursor
                    , previous = Just model.search.filters
                    , totalMatches = Just defendantsPage.meta.totalMatches
                    }

                updatedModel =
                    { model | search = search }
            in
            if model.search.previous == Just model.search.filters then
                let
                    defendants =
                        model.defendants ++ defendantsPage.data
                in
                ( { updatedModel
                    | defendants = defendants
                    , infiniteScroll =
                        InfiniteScroll.stopLoading model.infiniteScroll
                            |> InfiniteScroll.loadMoreCmd (loadMore domain maybeCred search)
                    , tableState = Stateful.stateWithItems defendants model.tableState
                  }
                , Cmd.none
                )

            else
                ( { updatedModel
                    | defendants = defendantsPage.data
                    , infiniteScroll =
                        InfiniteScroll.stopLoading model.infiniteScroll
                            |> InfiniteScroll.loadMoreCmd (loadMore domain maybeCred search)
                    , tableState = Stateful.stateWithItems defendantsPage.data model.tableState
                  }
                , Cmd.none
                )

        GotDefendants (Err httpError) ->
            ( model, logHttpError httpError )

        NoOp ->
            ( model, Cmd.none )


error : Rollbar -> String -> Cmd Msg
error rollbar report =
    Log.error rollbar (\_ -> NoOp) report


createNewDefendant : RenderConfig -> Element Msg
createNewDefendant cfg =
    row [ centerX ]
        [ Button.fromLabel "Create New Defendant"
            |> Button.redirect (Link.link <| "/admin/defendants/edit") Button.primary
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
        [ ifNonEmpty "first name is " identity filters.firstName
        , ifNonEmpty "last name is " identity filters.lastName
        ]


viewEmptyResults filters =
    textColumn [ centerX, spacing 10 ]
        ([ paragraph [ Font.center, centerX, Font.size 24 ]
            [ text "No defendants exist matching your search criteria:" ]
         , paragraph [ centerX, Font.italic, Font.center ]
            [ text "where..." ]
         ]
            ++ (List.intersperse (paragraph [ centerX, Font.center ] [ text "&" ]) <| viewFilter filters)
        )


viewEditButton : Defendant -> Button Msg
viewEditButton defendant =
    Button.fromIcon (Icon.edit "Go to edit page")
        |> Button.redirect
            (Link.link <|
                Url.Builder.absolute
                    [ "admin"
                    , "defendants"
                    , "edit"
                    ]
                    (Endpoint.toQueryArgs [ ( "id", String.fromInt defendant.id ) ])
            )
            Button.primary
        |> Button.withSize UI.Size.small


viewDefendants : RenderConfig -> Model -> Element Msg
viewDefendants cfg model =
    Stateful.table
        { toExternalMsg = ForTable
        , columns = Defendant.tableColumns
        , toRow = Defendant.toTableRow viewEditButton
        , state = model.tableState
        }
        |> Stateful.withResponsive
            { toDetails = Defendant.toTableDetails viewEditButton
            , toCover = Defendant.toTableCover
            }
        |> Stateful.withWidth fill
        |> Stateful.renderElement cfg


viewDesktop cfg model =
    column
        [ centerX
        , spacing 10
        , padding 10
        ]
        [ createNewDefendant cfg
        , row [ width fill ]
            [ case model.search.totalMatches of
                Just total ->
                    if total > 1 then
                        paragraph [ Font.center ] [ text (FormatNumber.format { usLocale | decimals = Exact 0 } (toFloat total) ++ " defendants matched your search.") ]

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
                    [ viewDefendants cfg model
                    ]
            ]
        ]


notFound =
    { title = "Not Found"
    , body = [ el [ centerX, padding 20 ] (text "Page not found") ]
    }


loading =
    { title = "Loading"
    , body = [ el [ centerX, padding 20 ] (text "Loading") ]
    }


errorScreen =
    { title = "Error"
    , body = [ el [ centerX, padding 20 ] (text "Something went wrong.") ]
    }


view :
    Maybe PageUrl
    -> Shared.Model
    -> Model
    -> StaticPayload Data RouteParams
    -> View Msg
view maybeUrl sharedModel model static =
    case sharedModel.profile of
        NotAsked ->
            notFound

        Loading ->
            loading

        Success profile ->
            if User.canViewDefendantInformation profile then
                { title = title
                , body =
                    [ Element.el [ width (px 0), height (px 0) ] (Element.html Sprite.all)
                    , viewDesktop sharedModel.renderConfig model
                    ]
                }

            else
                { title = "Not Found"
                , body = [ el [ centerX, padding 20 ] (text "Page not found") ]
                }

        Failure err ->
            errorScreen


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
    "RDC | Admin | Defendants"


head :
    StaticPayload Data RouteParams
    -> List Head.Tag
head static =
    Seo.summary
        { canonicalUrlOverride = Nothing
        , siteName = "Red Door Collective"
        , image = Logo.smallImage
        , description = "Manage defendants"
        , locale = Nothing
        , title = title
        }
        |> Seo.website
