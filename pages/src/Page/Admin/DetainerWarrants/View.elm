module Page.Admin.DetainerWarrants.View exposing (Data, Model, Msg, page)

import Browser.Navigation as Nav
import DataSource exposing (DataSource)
import DetainerWarrant exposing (DetainerWarrant)
import Dict
import Element exposing (Element, centerX, column, el, fill, height, inFront, maximum, minimum, padding, paddingEach, paragraph, px, row, spacing, text, width)
import Element.Border as Border
import Element.Font as Font
import Field
import Head
import Head.Seo as Seo
import Hearing exposing (Hearing)
import Html
import Html.Attributes
import Http
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
import Session
import Shared
import Sprite
import Time.Utils
import UI.Button as Button exposing (Button)
import UI.Icon as Icon
import UI.Link as Link
import UI.Palette as Palette
import UI.RenderConfig exposing (RenderConfig)
import UI.Size
import UI.Tables.Stateless as Stateless
import Url
import Url.Builder
import User exposing (User)
import View exposing (View)


type alias Model =
    { warrant : Maybe DetainerWarrant
    , cursor : Maybe String
    , nextWarrant : Maybe DetainerWarrant
    , docketId : Maybe String
    , showHelp : Bool
    , showDocument : Maybe Bool
    }


init :
    Maybe PageUrl
    -> Shared.Model
    -> StaticPayload Data RouteParams
    -> ( Model, Cmd Msg )
init pageUrl sharedModel static =
    let
        domain =
            Runtime.domain static.sharedData.runtime.environment

        maybeCred =
            Session.cred sharedModel.session

        docketId =
            case pageUrl of
                Just url ->
                    url.query
                        |> Maybe.andThen (Dict.get "docket-id" << QueryParams.toDict)
                        |> Maybe.andThen List.head

                Nothing ->
                    Nothing
    in
    ( { warrant = Nothing
      , cursor = Nothing
      , nextWarrant = Nothing
      , docketId = docketId
      , showHelp = False
      , showDocument = Nothing
      }
    , Cmd.batch
        [ case docketId of
            Just id ->
                getWarrant domain id maybeCred

            _ ->
                Cmd.none
        ]
    )


getWarrant : String -> String -> Maybe Cred -> Cmd Msg
getWarrant domain id maybeCred =
    Rest.get (Endpoint.detainerWarrant domain id) maybeCred GotDetainerWarrant (Rest.itemDecoder DetainerWarrant.decoder)


type Msg
    = GotDetainerWarrant (Result Rest.HttpError (Rest.Item DetainerWarrant))
    | ToggleHelp
    | ToggleOpenDocument
    | NoOp


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

        logHttpError =
            error rollbar << Log.httpErrorMessage
    in
    case msg of
        GotDetainerWarrant result ->
            case result of
                Ok warrantPage ->
                    ( { model
                        | warrant = Just warrantPage.data
                        , cursor = Just warrantPage.meta.cursor
                        , showDocument =
                            if warrantPage.data.document == Nothing then
                                Nothing

                            else
                                Just False
                      }
                    , Cmd.none
                    )

                Err httpError ->
                    ( model, logHttpError httpError )

        ToggleHelp ->
            ( { model
                | showHelp = not model.showHelp
              }
            , Cmd.none
            )

        ToggleOpenDocument ->
            ( case model.warrant of
                Just warrant ->
                    case warrant.document of
                        Just _ ->
                            { model | showDocument = Maybe.map not model.showDocument }

                        Nothing ->
                            model

                Nothing ->
                    model
            , Cmd.none
            )

        NoOp ->
            ( model, Cmd.none )


error : Rollbar -> String -> Cmd Msg
error rollbar report =
    Log.error rollbar (\_ -> NoOp) report


viewEditJudgmentButton : User -> Hearing -> Button Msg
viewEditJudgmentButton profile hearing =
    let
        ( path, icon ) =
            if User.canViewDefendantInformation profile then
                ( "edit", Icon.edit "Go to edit judgment" )

            else
                ( "view", Icon.eye "View judgment" )

        judgmentId =
            Maybe.withDefault "0" <| Maybe.map (String.fromInt << .id) hearing.judgment
    in
    Button.fromIcon icon
        |> Button.redirect
            (Link.link <|
                Url.Builder.absolute
                    [ "admin"
                    , "judgments"
                    , path
                    ]
                    (Endpoint.toQueryArgs [ ( "id", judgmentId ) ])
            )
            Button.primary
        |> Button.withDisabledIf (hearing.judgment == Nothing)
        |> Button.withSize UI.Size.small


viewHearings : RenderConfig -> User -> Model -> DetainerWarrant -> Element Msg
viewHearings cfg profile model warrant =
    column [ centerX, spacing 20, width (fill |> maximum 600), padding 10 ]
        [ Stateless.table
            { columns = Hearing.tableColumns
            , toRow = Hearing.toTableRow (viewEditJudgmentButton profile)
            }
            |> Stateless.withWidth (Element.fill |> Element.maximum 600)
            |> Stateless.withItems warrant.hearings
            |> Stateless.renderElement cfg
        ]


formGroup : List (Element Msg) -> Element Msg
formGroup group =
    row
        [ spacing 10
        , width fill
        ]
        group


tileAttrs =
    [ spacing 20
    , padding 20
    , width fill
    , Border.rounded 3
    , Palette.toBorderColor Palette.gray400
    , Border.width 1
    , Border.shadow { offset = ( 0, 10 ), size = 1, blur = 30, color = Palette.toElementColor Palette.gray400 }
    ]


tile : List (Element Msg) -> Element Msg
tile groups =
    column tileAttrs groups


boolToText bool =
    if bool then
        "true"

    else
        "false"


unknown =
    "Unknown"


viewForm : RenderConfig -> User -> Model -> DetainerWarrant -> Element Msg
viewForm cfg profile model warrant =
    let
        viewField =
            Field.view model.showHelp
    in
    column
        [ centerX, spacing 30 ]
        [ column
            (tileAttrs
                ++ (case warrant.document of
                        Just _ ->
                            [ inFront
                                (row [ Element.alignRight, padding 20 ]
                                    [ Button.fromIcon (Icon.legacyReport "Open PDF")
                                        |> Button.cmd ToggleOpenDocument Button.primary
                                        |> Button.renderElement cfg
                                    ]
                                )
                            ]

                        Nothing ->
                            []
                   )
            )
            [ paragraph [ Font.center, centerX ] [ text "Court" ]
            , if model.showDocument == Just True then
                case warrant.document of
                    Just pleading ->
                        row [ width fill ]
                            [ Element.html <|
                                Html.embed
                                    [ Html.Attributes.width 800
                                    , Html.Attributes.height 600
                                    , Html.Attributes.src (Url.toString pleading.url)
                                    ]
                                    []
                            ]

                    Nothing ->
                        Element.none

              else
                Element.none
            , formGroup
                [ viewField
                    { label = Just "Docket ID"
                    , tooltip = Just DetainerWarrant.description.docketId
                    , children = [ text warrant.docketId ]
                    }
                , viewField
                    { label = Just "File date"
                    , tooltip = Just DetainerWarrant.description.fileDate
                    , children = [ text <| Maybe.withDefault "" <| Maybe.map Time.Utils.toIsoString warrant.fileDate ]
                    }
                , viewField
                    { label = Just "Status"
                    , tooltip = Just DetainerWarrant.description.status
                    , children = [ text <| Maybe.withDefault "-" <| Maybe.map DetainerWarrant.statusHumanReadable warrant.status ]
                    }
                ]
            , viewField
                { label = Just "Address"
                , tooltip = Just DetainerWarrant.description.address
                , children = [ text <| Maybe.withDefault unknown warrant.address ]
                }
            , formGroup
                [ viewField
                    { label = Just "Plaintiff"
                    , tooltip = Just DetainerWarrant.description.plaintiff
                    , children = [ text <| Maybe.withDefault unknown <| Maybe.map .name warrant.plaintiff ]
                    }
                ]
            , formGroup
                [ viewField
                    { label = Just "Plaintiff attorney"
                    , tooltip = Just DetainerWarrant.description.plaintiffAttorney
                    , children = [ text <| Maybe.withDefault unknown <| Maybe.map .name warrant.plaintiffAttorney ]
                    }
                ]
            ]
        , tile
            [ paragraph [ Font.center, centerX ] [ text "Claims" ]
            , formGroup
                [ viewField
                    { label = Just "Amount claimed"
                    , tooltip = Just DetainerWarrant.description.amountClaimed
                    , children = [ text <| Maybe.withDefault unknown <| Maybe.map String.fromFloat warrant.amountClaimed ]
                    }
                ]
            , formGroup
                [ viewField
                    { label = Just "Claims Possession"
                    , tooltip = Just DetainerWarrant.description.claimsPossession
                    , children = [ text <| Maybe.withDefault unknown <| Maybe.map boolToText warrant.claimsPossession ]
                    }
                , viewField
                    { label = Just "Is cares"
                    , tooltip = Just DetainerWarrant.description.cares
                    , children = [ text <| Maybe.withDefault unknown <| Maybe.map boolToText warrant.isCares ]
                    }
                , viewField
                    { label = Just "Is legacy"
                    , tooltip = Just DetainerWarrant.description.legacy
                    , children = [ text <| Maybe.withDefault unknown <| Maybe.map boolToText warrant.isLegacy ]
                    }
                , viewField
                    { label = Just "Is Nonpayment"
                    , tooltip = Just DetainerWarrant.description.nonpayment
                    , children = [ text <| Maybe.withDefault unknown <| Maybe.map boolToText warrant.nonpayment ]
                    }
                ]
            ]
        , tile
            [ paragraph [ Font.center, centerX ] [ text "Hearings" ]
            , viewHearings cfg profile model warrant
            ]
        , case warrant.notes of
            Just notes ->
                tile
                    [ viewField
                        { label = Just "Notes"
                        , tooltip = Just DetainerWarrant.description.notes
                        , children = [ text <| notes ]
                        }
                    ]

            Nothing ->
                Element.none
        ]


title =
    "RDC | Admin | Detainer Warrants | View"


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
        , row
            [ centerX
            , padding 20
            , Font.size 20
            , width (fill |> maximum 1200 |> minimum 400)
            ]
            [ column [ centerX, spacing 10 ]
                [ row
                    [ width fill
                    ]
                    [ column [ centerX, width fill ]
                        [ row
                            [ width fill
                            , Element.inFront
                                (el
                                    [ paddingEach { top = 0, bottom = 5, left = 0, right = 0 }
                                    , Element.alignRight
                                    ]
                                    (Button.fromLabel "Help"
                                        |> Button.cmd ToggleHelp Button.primary
                                        |> Button.withSize UI.Size.small
                                        |> Button.renderElement cfg
                                    )
                                )
                            ]
                            [ paragraph [ Font.center, centerX, width Element.shrink ]
                                [ text "Detainer Warrant"
                                ]
                            ]
                        ]
                    ]
                , row [ width fill ]
                    [ case ( Session.profile sharedModel.session, model.warrant ) of
                        ( Just profile, Just warrant ) ->
                            viewForm cfg profile model warrant

                        _ ->
                            Element.none
                    ]
                ]
            ]
        ]
    }


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
        , description = "View detainer warrant details"
        , locale = Just "en-us"
        , title = title
        }
        |> Seo.website


type alias Data =
    ()
