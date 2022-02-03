module Page.Admin.Judgments.View exposing (Data, Model, Msg, page)

import Browser.Navigation as Nav
import DataSource exposing (DataSource)
import Dict
import Element exposing (Element, centerX, column, fill, height, maximum, minimum, padding, paragraph, px, row, spacing, text, width, wrappedRow)
import Element.Border as Border
import Element.Font as Font
import Field
import Head
import Head.Seo as Seo
import Http
import Judgment exposing (Conditions(..), Interest(..), Judgment)
import Log
import Logo
import Maybe
import Page exposing (StaticPayload)
import Pages.PageUrl exposing (PageUrl)
import Path exposing (Path)
import QueryParams
import Rest exposing (Cred)
import Rest.Endpoint as Endpoint
import Rollbar exposing (Rollbar)
import Runtime
import Session
import Shared
import Sprite
import Time.Utils
import UI.Button as Button
import UI.Icon as Icon
import UI.Link as Link
import UI.Palette as Palette
import UI.RenderConfig exposing (RenderConfig)
import UI.Size as Size
import Url.Builder
import View exposing (View)


type alias Model =
    { id : Maybe Int
    , judgment : Maybe Judgment
    , showHelp : Bool
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

        maybeCred =
            Session.cred session

        domain =
            Runtime.domain static.sharedData.runtime.environment

        maybeId =
            case pageUrl of
                Just url ->
                    url.query
                        |> Maybe.andThen (Dict.get "id" << QueryParams.toDict)
                        |> Maybe.andThen List.head
                        |> Maybe.andThen String.toInt

                Nothing ->
                    Nothing
    in
    ( { judgment = Nothing
      , id = maybeId
      , showHelp = False
      }
    , case maybeId of
        Just id ->
            getJudgment domain id maybeCred

        Nothing ->
            Cmd.none
    )


getJudgment : String -> Int -> Maybe Cred -> Cmd Msg
getJudgment domain id maybeCred =
    Rest.get (Endpoint.judgment domain id) maybeCred GotJudgment (Rest.itemDecoder Judgment.decoder)


type Msg
    = GotJudgment (Result Http.Error (Rest.Item Judgment))
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
        GotJudgment result ->
            case result of
                Ok judgmentPage ->
                    ( { model
                        | judgment = Just judgmentPage.data
                      }
                    , Cmd.none
                    )

                Err httpError ->
                    ( model, logHttpError httpError )

        NoOp ->
            ( model, Cmd.none )


error : Rollbar -> String -> Cmd Msg
error rollbar report =
    Log.error rollbar (\_ -> NoOp) report


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
                    [ column [ centerX, width (px 300) ]
                        [ paragraph [ Font.center, centerX, width Element.shrink ]
                            [ text "Hearing"
                            ]
                        ]
                    ]
                , row [ width fill ]
                    [ case model.judgment of
                        Just judgment ->
                            viewJudgment cfg model judgment

                        Nothing ->
                            Element.none
                    ]
                ]
            ]
        ]
    }


judgmentsLink : RenderConfig -> Element Msg
judgmentsLink cfg =
    Button.fromLabeledOnRightIcon (Icon.list "All judgments")
        |> Button.redirect
            (Link.link <|
                Url.Builder.absolute
                    [ "admin"
                    , "judgments"
                    ]
                    []
            )
            Button.primary
        |> Button.withSize Size.medium
        |> Button.renderElement cfg


warrantLink : RenderConfig -> Judgment -> Element Msg
warrantLink cfg judgment =
    Button.fromLabeledOnRightIcon (Icon.notes "Detainer Warrant")
        |> Button.redirect
            (Link.link <|
                Url.Builder.absolute
                    [ "admin"
                    , "detainer-warrants"
                    , "view"
                    ]
                    (Endpoint.toQueryArgs [ ( "docket-id", judgment.docketId ) ])
            )
            Button.primary
        |> Button.withSize Size.medium
        |> Button.renderElement cfg


viewJudgment : RenderConfig -> Model -> Judgment -> Element Msg
viewJudgment cfg model judgment =
    let
        viewField =
            Field.view model.showHelp
    in
    column
        [ width fill
        , spacing 10
        , padding 20
        , Border.width 1
        , Palette.toBorderColor Palette.gray300
        , Border.innerGlow (Palette.toElementColor Palette.gray300) 1
        , Border.rounded 5
        ]
        [ row [ centerX, padding 10, spacing 10 ] [ judgmentsLink cfg, warrantLink cfg judgment ]
        , row
            [ spacing 5
            ]
            [ viewField
                { label = Just "Court date"
                , tooltip = Just ""
                , children = [ text <| Time.Utils.toIsoString judgment.hearing.courtDate ]
                }
            , viewField
                { label = Just "Courtroom"
                , tooltip = Just ""
                , children = [ text <| Maybe.withDefault "" <| Maybe.map .name judgment.hearing.courtroom ]
                }
            ]
        , wrappedRow [ spacing 5, width fill ]
            [ viewField
                { label = Just "Plaintiff"
                , tooltip = Just ""
                , children = [ text <| Maybe.withDefault "" <| Maybe.map .name judgment.plaintiff ]
                }
            , viewField
                { label = Just "Plaintiff Attorney"
                , tooltip = Just ""
                , children = [ text <| Maybe.withDefault "" <| Maybe.map .name judgment.plaintiffAttorney ]
                }
            , viewField
                { label = Just "Judge"
                , tooltip = Just ""
                , children = [ text <| Maybe.withDefault "" <| Maybe.map .name judgment.judge ]
                }
            ]
        , column
            [ spacing 5
            , Border.width 1
            , Border.rounded 5
            , width fill
            , padding 20
            , Palette.toBorderColor Palette.gray300
            , Border.innerGlow (Palette.toElementColor Palette.gray300) 1
            ]
            [ row [ spacing 5, width fill ]
                [ paragraph [ Font.center, centerX ] [ text "Judgment" ] ]
            , row [ spacing 5, width fill ]
                [ viewField
                    { tooltip = Just "The ruling from the court that will determine if fees or repossession are enforced."
                    , label = Just "Granted to"
                    , children =
                        [ text <| Maybe.withDefault "" <| Maybe.map Judgment.conditionsText judgment.conditions
                        ]
                    }
                ]
            , row [ spacing 5, width fill ]
                (case judgment.conditions of
                    Just (PlaintiffConditions conditions) ->
                        [ viewField
                            { tooltip = Just "Fees the plaintiff has been awarded."
                            , label = Just "Fees awarded"
                            , children =
                                [ text <| Maybe.withDefault "" <| Maybe.map String.fromFloat conditions.awardsFees
                                ]
                            }
                        , viewField
                            { tooltip = Just "Has the Plaintiff claimed the residence?"
                            , label = Just "Possession awarded"
                            , children =
                                [ text <|
                                    if conditions.awardsPossession == Just True then
                                        "true"

                                    else if conditions.awardsPossession == Just False then
                                        "false"

                                    else
                                        "-"
                                ]
                            }
                        ]

                    Just (DefendantConditions conditions) ->
                        [ viewField
                            { tooltip = Just "Why is the case being dismissed?"
                            , label = Just "Basis for dismissal"
                            , children =
                                [ text <| Judgment.dismissalBasisPrint conditions.basis
                                ]
                            }
                        , viewField
                            { tooltip = Just "Whether or not the dismissal is made with prejudice."
                            , label = Just "Dismissal is with prejudice"
                            , children =
                                [ text <|
                                    if conditions.withPrejudice then
                                        "true"

                                    else
                                        "false"
                                ]
                            }
                        ]

                    Nothing ->
                        [ Element.none ]
                )
            , case judgment.conditions of
                Just (PlaintiffConditions conditions) ->
                    if conditions.awardsFees /= Nothing then
                        row [ spacing 5, width fill ]
                            [ viewField
                                { tooltip = Just ""
                                , label = Just "Interest"
                                , children =
                                    [ text <|
                                        case conditions.interest of
                                            Just (WithRate rate) ->
                                                String.fromFloat rate

                                            Just FollowsSite ->
                                                "Follows site"

                                            Nothing ->
                                                ""
                                    ]
                                }
                            ]

                    else
                        Element.none

                Just (DefendantConditions _) ->
                    Element.none

                Nothing ->
                    Element.none
            , case judgment.notes of
                Just notes ->
                    viewField
                        { label = Just "Notes"
                        , tooltip = Just ""
                        , children = [ text notes ]
                        }

                Nothing ->
                    Element.none
            ]
        ]


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
    "RDC | Admin | Judgments | View"


head :
    StaticPayload Data RouteParams
    -> List Head.Tag
head static =
    Seo.summary
        { canonicalUrlOverride = Nothing
        , siteName = "Red Door Collective"
        , image = Logo.smallImage
        , description = "View judgment details"
        , locale = Just "en-us"
        , title = title
        }
        |> Seo.website
