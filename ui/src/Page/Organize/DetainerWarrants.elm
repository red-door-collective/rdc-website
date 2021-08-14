module Page.Organize.DetainerWarrants exposing (Model, Msg, init, subscriptions, toSession, update, view)

import Api exposing (Cred)
import Api.Endpoint as Endpoint exposing (Endpoint)
import Color
import Date
import DetainerWarrant exposing (DetainerWarrant, Status(..))
import Dict
import Element exposing (Element, centerX, column, fill, height, image, link, maximum, minimum, padding, paragraph, px, row, spacing, table, text, textColumn, width)
import Element.Background as Background
import Element.Border as Border
import Element.Events as Events
import Element.Font as Font
import Element.Input as Input
import FeatherIcons
import Html.Attributes
import Html.Events
import Http
import InfiniteScroll
import Json.Decode as Decode
import Loader
import Log
import Palette
import Rollbar exposing (Rollbar)
import Route
import Runtime exposing (Runtime)
import Session exposing (Session)
import Settings exposing (Settings)
import Url.Builder exposing (QueryParameter)
import User exposing (User)
import Widget
import Widget.Icon


type Cursor
    = NewSearch
    | After String
    | End


type alias Model =
    { session : Session
    , runtime : Runtime
    , warrants : List DetainerWarrant
    , searchFilters : SearchFilters
    , cursor : Cursor
    , selected : Maybe String
    , hovered : Maybe String
    , previousSearch : Maybe SearchFilters
    , infiniteScroll : InfiniteScroll.Model Msg
    }


type alias SearchFilters =
    { docketId : String
    , fileDate : String
    , courtDate : String
    , plaintiff : String
    , plaintiffAttorney : String
    , defendant : String
    , address : String
    }


type alias Search =
    { filters : SearchFilters
    , cursor : Cursor
    , previous : Maybe SearchFilters
    }


searchFiltersInit : SearchFilters
searchFiltersInit =
    { docketId = ""
    , fileDate = ""
    , courtDate = ""
    , plaintiff = ""
    , plaintiffAttorney = ""
    , defendant = ""
    , address = ""
    }


init : Runtime -> Session -> ( Model, Cmd Msg )
init runtime session =
    let
        maybeCred =
            Session.cred session

        searchFilters =
            searchFiltersInit

        search =
            { filters = searchFilters, cursor = NewSearch, previous = Nothing }
    in
    ( { session = session
      , runtime = runtime
      , warrants = []
      , searchFilters = searchFilters
      , cursor = search.cursor
      , previousSearch = search.previous
      , selected = Nothing
      , hovered = Nothing
      , infiniteScroll = InfiniteScroll.init (loadMore maybeCred search) |> InfiniteScroll.direction InfiniteScroll.Bottom
      }
    , searchWarrants maybeCred search
    )


searchWarrants : Maybe Cred -> Search -> Cmd Msg
searchWarrants maybeCred search =
    if search.filters.docketId /= "" then
        Api.get (Endpoint.detainerWarrant search.filters.docketId) maybeCred GotWarrant (Api.itemDecoder DetainerWarrant.decoder)

    else
        Api.get (Endpoint.detainerWarrantsSearch (queryArgsWithPagination search)) maybeCred GotWarrants Api.detainerWarrantApiDecoder


loadMore : Maybe Cred -> Search -> InfiniteScroll.Direction -> Cmd Msg
loadMore maybeCred search dir =
    case search.cursor of
        NewSearch ->
            Cmd.none

        After _ ->
            searchWarrants maybeCred search

        End ->
            Cmd.none


queryArgsWithPagination : Search -> List ( String, String )
queryArgsWithPagination search =
    let
        filters =
            search.filters

        queryArgs =
            toQueryArgs filters
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


toQueryArgs : SearchFilters -> List ( String, String )
toQueryArgs filters =
    (if filters.fileDate == "" then
        []

     else
        [ ( "file_date", filters.fileDate ) ]
    )
        ++ (if filters.courtDate == "" then
                []

            else
                [ ( "court_date", filters.courtDate ) ]
           )
        ++ (if filters.plaintiff == "" then
                []

            else
                [ ( "plaintiff", filters.plaintiff ) ]
           )
        ++ (if filters.plaintiffAttorney == "" then
                []

            else
                [ ( "plaintiff_attorney", filters.plaintiffAttorney ) ]
           )
        ++ (if filters.defendant == "" then
                []

            else
                [ ( "defendant_name", filters.defendant ) ]
           )
        ++ (if filters.address == "" then
                []

            else
                [ ( "address", filters.address ) ]
           )


type Msg
    = InputDocketId String
    | InputFileDate String
    | InputCourtDate String
    | InputPlaintiff String
    | InputPlaintiffAttorney String
    | InputDefendant String
    | InputAddress String
    | SelectWarrant String
    | HoverWarrant String
    | SearchWarrants
    | GotWarrant (Result Http.Error (Api.Item DetainerWarrant))
    | GotWarrants (Result Http.Error (Api.Collection DetainerWarrant))
    | ChangedSorting String
    | InfiniteScrollMsg InfiniteScroll.Msg
    | NoOp


updateFilters : (SearchFilters -> SearchFilters) -> Model -> ( Model, Cmd Msg )
updateFilters transform model =
    ( { model | searchFilters = transform model.searchFilters }, Cmd.none )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    let
        runtime =
            model.runtime

        rollbar =
            Log.reporting runtime.rollbarToken runtime.environment

        logHttpError =
            error rollbar << Log.httpErrorMessage
    in
    case msg of
        InputDocketId query ->
            updateFilters (\filters -> { filters | docketId = query }) model

        InputFileDate query ->
            updateFilters (\filters -> { filters | fileDate = query }) model

        InputCourtDate query ->
            updateFilters (\filters -> { filters | courtDate = query }) model

        InputPlaintiff query ->
            updateFilters (\filters -> { filters | plaintiff = query }) model

        InputPlaintiffAttorney query ->
            updateFilters (\filters -> { filters | plaintiffAttorney = query }) model

        InputDefendant query ->
            updateFilters (\filters -> { filters | defendant = query }) model

        InputAddress query ->
            updateFilters (\filters -> { filters | address = query }) model

        SelectWarrant docketId ->
            ( { model | selected = Just docketId }, Cmd.none )

        HoverWarrant docketId ->
            ( { model | hovered = Just docketId }, Cmd.none )

        SearchWarrants ->
            let
                maybeCred =
                    Session.cred model.session
            in
            ( model, searchWarrants maybeCred { filters = model.searchFilters, cursor = model.cursor, previous = model.previousSearch } )

        GotWarrant (Ok detainerWarrant) ->
            let
                maybeCred =
                    Session.cred model.session

                search =
                    { filters = model.searchFilters, cursor = End, previous = model.previousSearch }
            in
            ( { model
                | warrants = [ detainerWarrant.data ]
                , infiniteScroll =
                    InfiniteScroll.stopLoading model.infiniteScroll
                        |> InfiniteScroll.loadMoreCmd (loadMore maybeCred search)
                , cursor = search.cursor
              }
            , Cmd.none
            )

        GotWarrant (Err httpError) ->
            ( model, logHttpError httpError )

        GotWarrants (Ok detainerWarrantsPage) ->
            let
                maybeCred =
                    Session.cred model.session

                updatedModel =
                    { model
                        | cursor = Maybe.withDefault End <| Maybe.map After detainerWarrantsPage.meta.afterCursor
                        , previousSearch = Just model.searchFilters
                    }

                search =
                    { filters = model.searchFilters, cursor = updatedModel.cursor, previous = updatedModel.previousSearch }
            in
            if model.previousSearch == Just model.searchFilters then
                ( { updatedModel
                    | warrants = model.warrants ++ detainerWarrantsPage.data
                    , infiniteScroll =
                        InfiniteScroll.stopLoading model.infiniteScroll
                            |> InfiniteScroll.loadMoreCmd (loadMore maybeCred search)
                  }
                , Cmd.none
                )

            else
                ( { updatedModel
                    | warrants = detainerWarrantsPage.data
                    , infiniteScroll =
                        InfiniteScroll.stopLoading model.infiniteScroll
                            |> InfiniteScroll.loadMoreCmd (loadMore maybeCred search)
                  }
                , Cmd.none
                )

        GotWarrants (Err httpError) ->
            ( model, logHttpError httpError )

        ChangedSorting _ ->
            ( model, Cmd.none )

        InfiniteScrollMsg subMsg ->
            case model.cursor of
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


onEnter : msg -> Element.Attribute msg
onEnter msg =
    Element.htmlAttribute
        (Html.Events.on "keyup"
            (Decode.field "key" Decode.string
                |> Decode.andThen
                    (\key ->
                        if key == "Enter" then
                            Decode.succeed msg

                        else
                            Decode.fail "Not the enter key"
                    )
            )
        )


type alias SearchField =
    { label : String
    , placeholder : String
    , onChange : String -> Msg
    , query : String
    }


searchField : SearchField -> Element Msg
searchField { label, placeholder, query, onChange } =
    Input.search
        [ Element.width (fill |> Element.maximum 400)
        , onEnter SearchWarrants
        ]
        { onChange = onChange
        , text = query
        , placeholder = Just (Input.placeholder [] (Element.text placeholder))
        , label = Input.labelHidden label
        }


searchFields : SearchFilters -> List SearchField
searchFields searchFilters =
    [ { label = "Search by docket number", placeholder = "Docket #", onChange = InputDocketId, query = searchFilters.docketId }
    , { label = "Search by file date", placeholder = "File Date", onChange = InputFileDate, query = searchFilters.fileDate }
    , { label = "Search by court date", placeholder = "Court Date", onChange = InputCourtDate, query = searchFilters.courtDate }
    , { label = "Search by plaintiff name", placeholder = "Plaintiff", onChange = InputPlaintiff, query = searchFilters.plaintiff }
    , { label = "Search by plaintiff attorney name", placeholder = "Plnt. Attorney", onChange = InputPlaintiffAttorney, query = searchFilters.plaintiffAttorney }
    , { label = "Search by defendant name", placeholder = "Defendant", onChange = InputDefendant, query = searchFilters.defendant }
    , { label = "Search by address", placeholder = "Address", onChange = InputAddress, query = searchFilters.address }
    ]


viewSearchBar : Model -> Element Msg
viewSearchBar model =
    Element.wrappedRow
        [ Element.width (fill |> maximum 1200)
        , Element.spacing 10
        , Element.padding 10
        , Element.centerY
        , Element.centerX
        ]
        (List.map searchField (searchFields model.searchFilters)
            ++ [ Input.button
                    [ Element.centerY
                    , Background.color Palette.redLight
                    , Element.focused [ Background.color Palette.red ]
                    , Element.height fill
                    , Font.color (Element.rgb 255 255 255)
                    , Element.padding 10
                    , Border.rounded 5
                    ]
                    { onPress = Just SearchWarrants, label = Element.text "Search" }
               ]
        )


createNewWarrant : Element Msg
createNewWarrant =
    row [ centerX ]
        [ link buttonLinkAttrs
            { url = Route.href (Route.DetainerWarrantCreation Nothing)
            , label = text "Enter New Detainer Warrant"
            }
        ]


view : Settings -> Model -> { title : String, content : Element Msg }
view settings model =
    { title = "Organize - Detainer Warrants"
    , content =
        row [ centerX, padding 10, Font.size 20, width (fill |> maximum 2000 |> minimum 400) ]
            [ column
                [ centerX
                , spacing 10
                , Element.inFront (loader model)
                ]
                [ createNewWarrant
                , viewSearchBar model
                , viewWarrants model
                ]
            ]
    }


loader : Model -> Element Msg
loader { infiniteScroll } =
    if InfiniteScroll.isLoading infiniteScroll then
        row
            [ width fill
            , Element.alignBottom
            ]
            [ Element.el [ centerX, width Element.shrink, height Element.shrink ] (Element.html (Loader.horizontal Color.red)) ]

    else
        Element.none


ascIcon =
    FeatherIcons.chevronUp
        |> Widget.Icon.elmFeather FeatherIcons.toHtml


sortIconStyle =
    { size = 20, color = Color.white }


descIcon =
    FeatherIcons.chevronDown
        |> Widget.Icon.elmFeather FeatherIcons.toHtml


noSortIcon =
    FeatherIcons.chevronDown
        |> Widget.Icon.elmFeather FeatherIcons.toHtml


tableStyle =
    { elementTable = []
    , content =
        { header = buttonStyle
        , ascIcon = ascIcon
        , descIcon = descIcon
        , defaultIcon = noSortIcon
        }
    }


buttonStyle =
    { elementButton =
        [ width (px 40), height (px 40), Background.color Palette.sred, centerX, Font.center ]
    , ifDisabled = []
    , ifActive = []
    , otherwise = []
    , content =
        { elementRow = [ centerX, Font.center ]
        , content =
            { text = { contentText = [] }
            , icon = { ifDisabled = sortIconStyle, ifActive = sortIconStyle, otherwise = sortIconStyle }
            }
        }
    }


buttonLinkAttrs : List (Element.Attribute Msg)
buttonLinkAttrs =
    [ Background.color Palette.white
    , Font.color Palette.red
    , Border.rounded 3
    , Border.color Palette.sred
    , Border.width 1
    , padding 10
    , Font.size 16
    , Element.mouseOver [ Background.color Palette.redLightest ]
    , Element.focused [ Background.color Palette.redLightest ]
    ]


viewEditButton : Maybe String -> Int -> DetainerWarrant -> Element Msg
viewEditButton hovered index warrant =
    row
        (tableCellAttrs (modBy 2 index == 0) hovered warrant)
        [ link
            (buttonLinkAttrs ++ [ Events.onFocus (SelectWarrant warrant.docketId) ])
            { url = Route.href (Route.DetainerWarrantCreation (Just warrant.docketId)), label = text "Edit" }
        ]


tableCellAttrs : Bool -> Maybe String -> DetainerWarrant -> List (Element.Attribute Msg)
tableCellAttrs striped hovered warrant =
    [ Element.width (Element.shrink |> maximum 200)
    , height (px 60)
    , Element.clipX
    , Element.padding 10
    , Border.solid
    , Border.color Palette.grayLight
    , Border.widthEach { bottom = 1, left = 0, right = 0, top = 0 }
    , Events.onMouseDown (SelectWarrant warrant.docketId)
    , Events.onMouseEnter (HoverWarrant warrant.docketId)
    ]
        ++ (if hovered == Just warrant.docketId then
                [ Background.color Palette.redLightest ]

            else if striped then
                [ Background.color Palette.grayBack ]

            else
                []
           )


viewHeaderCell text =
    Element.row
        [ Element.width (Element.shrink |> maximum 200)
        , Element.padding 10
        , Font.semiBold
        , Border.solid
        , Border.color Palette.grayLight
        , Border.widthEach { bottom = 1, left = 0, right = 0, top = 0 }
        ]
        [ Element.text text ]


viewTextRow : Maybe String -> (DetainerWarrant -> String) -> Int -> DetainerWarrant -> Element Msg
viewTextRow hovered toText index warrant =
    Element.row (tableCellAttrs (modBy 2 index == 0) hovered warrant)
        [ Element.text (toText warrant) ]


viewDocketId : Maybe String -> Maybe String -> Int -> DetainerWarrant -> Element Msg
viewDocketId hovered selected index warrant =
    let
        striped =
            modBy 2 index == 0

        attrs =
            [ width (Element.shrink |> maximum 200)
            , height (px 60)
            , Border.widthEach { bottom = 0, top = 0, right = 0, left = 4 }
            , Border.color Palette.transparent
            ]
    in
    row
        (attrs
            ++ (if selected == Just warrant.docketId then
                    [ Border.color Palette.sred
                    ]

                else
                    []
               )
            ++ (if hovered == Just warrant.docketId then
                    [ Background.color Palette.redLightest
                    ]

                else if striped then
                    [ Background.color Palette.grayBack ]

                else
                    []
               )
        )
        [ column
            [ width fill
            , height (px 60)
            , padding 10
            , Border.solid
            , Border.color Palette.grayLight
            , Border.widthEach { bottom = 1, left = 0, right = 0, top = 0 }
            ]
            [ Element.el [ Element.centerY ] (text warrant.docketId)
            ]
        ]


viewStatusIcon : Maybe String -> Int -> DetainerWarrant -> Element Msg
viewStatusIcon hovered index warrant =
    let
        icon ( letter, fontColor, backgroundColor ) =
            Element.el
                [ width (px 20)
                , height (px 20)
                , centerX
                , Border.width 1
                , Border.rounded 2
                , Font.color fontColor
                , Background.color backgroundColor
                ]
                (Element.el [ centerX, Element.centerY ]
                    (text <| letter)
                )
    in
    Element.row (tableCellAttrs (modBy 2 index == 0) hovered warrant)
        [ case warrant.status of
            Just Pending ->
                icon ( "P", Palette.gold, Palette.white )

            Just Closed ->
                icon ( "C", Palette.purple, Palette.white )

            Nothing ->
                Element.none
        ]


viewWarrants : Model -> Element Msg
viewWarrants model =
    let
        cell =
            viewTextRow model.hovered
    in
    Element.indexedTable
        [ width (fill |> maximum 1400)
        , height (px 600)
        , Font.size 14
        , Element.scrollbarY
        , Element.htmlAttribute (InfiniteScroll.infiniteScroll InfiniteScrollMsg)
        ]
        { data = model.warrants
        , columns =
            [ { header = Element.none -- viewHeaderCell "Status"
              , view = viewStatusIcon model.hovered
              , width = px 40
              }
            , { header = viewHeaderCell "Docket #"
              , view = viewDocketId model.hovered model.selected
              , width = Element.fill
              }
            , { header = viewHeaderCell "File Date"
              , view = cell (Maybe.withDefault "" << Maybe.map Date.toIsoString << .fileDate)
              , width = Element.fill
              }
            , { header = viewHeaderCell "Plaintiff"
              , view = cell (Maybe.withDefault "" << Maybe.map .name << .plaintiff)
              , width = fill
              }
            , { header = viewHeaderCell "Plnt. Attorney"
              , view = cell (Maybe.withDefault "" << Maybe.map .name << .plaintiffAttorney)
              , width = fill
              }
            , { header = viewHeaderCell "Amount Claimed"
              , view = cell (Maybe.withDefault "" << Maybe.map (String.append "$" << String.fromFloat) << .amountClaimed)
              , width = fill
              }
            , { header = viewHeaderCell "Address"
              , view = cell (Maybe.withDefault "" << Maybe.map .address << List.head << .defendants)
              , width = fill
              }
            , { header = viewHeaderCell "Defendant"
              , view = cell (Maybe.withDefault "" << Maybe.map .name << List.head << .defendants)
              , width = fill
              }
            , { header = viewHeaderCell "Edit"
              , view = viewEditButton model.hovered
              , width = fill
              }
            ]
        }


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- EXPORT


toSession : Model -> Session
toSession model =
    model.session
