module Page.Admin.Judges exposing (Data, Model, Msg, page)

import Browser.Navigation as Nav
import Color
import DataSource exposing (DataSource)
import Element exposing (Element, centerX, column, fill, height, padding, paragraph, px, row, spacing, text, textColumn, width)
import Element.Font as Font
import FormatNumber
import FormatNumber.Locales exposing (Decimals(..), usLocale)
import Head
import Head.Seo as Seo
import Html.Attributes as Attrs
import InfiniteScroll
import Judge exposing (Judge)
import Loader
import Log
import Logo
import Page exposing (StaticPayload)
import Pages.PageUrl exposing (PageUrl)
import Path exposing (Path)
import Plaintiff
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
import UI.RenderConfig as RenderConfig exposing (RenderConfig)
import UI.Size
import UI.Tables.Stateful as Stateful exposing (Filters, Sorters, filtersEmpty, localSingleTextFilter, remoteSingleTextFilter, sortBy, sortersEmpty, unsortable)
import UI.Utils.Element exposing (renderIf)
import UI.Utils.TypeNumbers as T
import Url.Builder
import User
import View exposing (View)


type alias Model =
    { judges : List Judge
    , tableState : Stateful.State Msg Judge T.Three
    , search : Search Search.Judges
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
            Maybe.withDefault Search.judgesDefault <| Maybe.andThen (Maybe.map (Search.judgesFromString << QueryParams.toString) << .query) pageUrl

        search =
            { filters = filters, cursor = NewSearch, previous = Just filters, totalMatches = Nothing }
    in
    ( { judges = []
      , search = search
      , tableState =
            Stateful.init
                |> Stateful.stateWithFilters (searchFilters search.filters)
                |> Stateful.stateWithSorters sortersInit
      , infiniteScroll = InfiniteScroll.init (loadMore domain maybeCred search) |> InfiniteScroll.direction InfiniteScroll.Bottom
      }
    , searchJudges domain maybeCred search
    )


searchFilters : Search.Judges -> Filters Msg Judge T.Three
searchFilters filters =
    filtersEmpty
        |> remoteSingleTextFilter filters.name InputName
        |> remoteSingleTextFilter filters.aliases InputAliases
        |> localSingleTextFilter Nothing .name


sortersInit : Sorters Judge T.Three
sortersInit =
    sortersEmpty
        |> sortBy .name
        |> sortBy (String.join ", " << .aliases)
        |> unsortable


searchJudges : String -> Maybe Cred -> Search Search.Judges -> Cmd Msg
searchJudges domain maybeCred search =
    Rest.get (Endpoint.judgesSearch domain (queryArgsWithPagination search)) maybeCred GotJudges (Rest.collectionDecoder Judge.decoder)


loadMore : String -> Maybe Cred -> Search Search.Judges -> InfiniteScroll.Direction -> Cmd Msg
loadMore domain maybeCred search dir =
    case search.cursor of
        NewSearch ->
            Cmd.none

        After _ ->
            searchJudges domain maybeCred search

        End ->
            Cmd.none


queryArgsWithPagination : Search Search.Judges -> List ( String, String )
queryArgsWithPagination search =
    let
        filters =
            search.filters

        queryArgs =
            Search.judgesArgs filters
    in
    if Just search.filters == search.previous then
        case search.cursor of
            NewSearch ->
                queryArgs

            After judgesCursor ->
                ( "cursor", judgesCursor ) :: queryArgs

            End ->
                queryArgs

    else
        queryArgs


type Msg
    = InputName (Maybe String)
    | InputAliases (Maybe String)
    | ForTable (Stateful.Msg Judge)
    | GotJudges (Result Rest.HttpError (Rest.Collection Judge))
    | NoOp


updateFiltersAndReload :
    String
    -> Session
    -> (Search.Judges -> Search.Judges)
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
                (\key -> Nav.replaceUrl key (Url.Builder.absolute [ "admin", "judges" ] (Endpoint.toQueryArgs <| Search.judgesArgs updatedModel.search.filters)))
                (Session.navKey session)
        , searchJudges domain (Session.cred session) updatedModel.search
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

        GotJudges (Ok judgesPage) ->
            let
                maybeCred =
                    Session.cred session

                search =
                    { filters = model.search.filters
                    , cursor = Maybe.withDefault End <| Maybe.map After judgesPage.meta.afterCursor
                    , previous = Just model.search.filters
                    , totalMatches = Just judgesPage.meta.totalMatches
                    }

                updatedModel =
                    { model | search = search }
            in
            if model.search.previous == Just model.search.filters then
                let
                    judges =
                        model.judges ++ judgesPage.data
                in
                ( { updatedModel
                    | judges = judges
                    , infiniteScroll =
                        InfiniteScroll.stopLoading model.infiniteScroll
                            |> InfiniteScroll.loadMoreCmd (loadMore domain maybeCred search)
                    , tableState = Stateful.stateWithItems judges model.tableState
                  }
                , Cmd.none
                )

            else
                ( { updatedModel
                    | judges = judgesPage.data
                    , infiniteScroll =
                        InfiniteScroll.stopLoading model.infiniteScroll
                            |> InfiniteScroll.loadMoreCmd (loadMore domain maybeCred search)
                    , tableState = Stateful.stateWithItems judgesPage.data model.tableState
                  }
                , Cmd.none
                )

        GotJudges (Err httpError) ->
            ( model, logHttpError httpError )

        NoOp ->
            ( model, Cmd.none )


error : Rollbar -> String -> Cmd Msg
error rollbar report =
    Log.error rollbar (\_ -> NoOp) report


createNewJudge : RenderConfig -> Element Msg
createNewJudge cfg =
    row [ centerX ]
        [ Button.fromLabel "Create New Judge"
            |> Button.redirect (Link.link <| "/admin/judges/edit") Button.primary
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
            [ text "No judges exist matching your search criteria:" ]
         , paragraph [ centerX, Font.italic, Font.center ]
            [ text "where..." ]
         ]
            ++ (List.intersperse (paragraph [ centerX, Font.center ] [ text "&" ]) <| viewFilter filters)
        )


viewEditButton : Judge -> Button Msg
viewEditButton judge =
    Button.fromIcon (Icon.edit "Go to edit page")
        |> Button.redirect
            (Link.link <|
                Url.Builder.absolute
                    [ "admin"
                    , "judges"
                    , "edit"
                    ]
                    (Endpoint.toQueryArgs [ ( "id", String.fromInt judge.id ) ])
            )
            Button.primary
        |> Button.withSize UI.Size.small


viewJudges : RenderConfig -> Model -> Element Msg
viewJudges cfg model =
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


viewActions cfg profile =
    renderIf (User.canViewDefendantInformation profile) (createNewJudge cfg)


viewMobile cfg profile model =
    column
        [ centerX
        , spacing 10
        , padding 10
        ]
        [ viewActions cfg profile
        , row [ width fill ]
            [ case model.search.totalMatches of
                Just total ->
                    if total > 1 then
                        paragraph [ Font.center ] [ text (FormatNumber.format { usLocale | decimals = Exact 0 } (toFloat total) ++ " judges matched your search.") ]

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
                    [ viewJudges cfg model
                    ]
            ]
        ]


viewDesktop cfg profile model =
    column
        [ centerX
        , spacing 10
        , padding 10
        ]
        [ viewActions cfg profile
        , row [ width fill ]
            [ case model.search.totalMatches of
                Just total ->
                    if total > 1 then
                        paragraph [ Font.center ] [ text (FormatNumber.format { usLocale | decimals = Exact 0 } (toFloat total) ++ " judges matched your search.") ]

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
                    [ viewJudges cfg model
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
        let
            cfg =
                sharedModel.renderConfig
        in
        case sharedModel.profile of
            Just NotAsked ->
                [ text "Refresh the page." ]

            Just Loading ->
                [ text "Loading" ]

            Just (Success profile) ->
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

            Just (Failure _) ->
                [ text "Something went wrong." ]

            Nothing ->
                [ text "Page Not Found" ]
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
    "RDC | Admin | Judges"


head :
    StaticPayload Data RouteParams
    -> List Head.Tag
head static =
    Seo.summary
        { canonicalUrlOverride = Nothing
        , siteName = "Red Door Collective"
        , image = Logo.smallImage
        , description = "Manage judges"
        , locale = Nothing
        , title = title
        }
        |> Seo.website
