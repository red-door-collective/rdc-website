module Page.Admin.Judgments.Edit exposing (Data, Model, Msg, page)

import Attorney exposing (Attorney, AttorneyForm)
import Browser.Events exposing (onMouseDown)
import Browser.Navigation as Nav
import Courtroom exposing (Courtroom)
import DataSource exposing (DataSource)
import Date exposing (Date)
import Date.Extra
import Dict
import Element exposing (Element, centerX, column, el, fill, height, inFront, maximum, minimum, padding, paddingEach, paddingXY, paragraph, px, row, spacing, spacingXY, text, textColumn, width, wrappedRow)
import Element.Border as Border
import Element.Font as Font
import Element.Input as Input
import Head
import Head.Seo as Seo
import Html
import Html.Attributes
import Http
import Json.Decode as Decode
import Json.Encode as Encode
import Judge exposing (Judge)
import Judgment exposing (ConditionOption(..), Conditions(..), DismissalBasis(..), Interest(..), Judgment, JudgmentEdit, JudgmentForm)
import List.Extra as List
import Log
import Logo
import Mask
import Page exposing (StaticPayload)
import Pages.PageUrl exposing (PageUrl)
import Path exposing (Path)
import Plaintiff exposing (Plaintiff, PlaintiffForm)
import QueryParams
import Rest exposing (Cred)
import Rest.Endpoint as Endpoint
import Rollbar exposing (Rollbar)
import Runtime
import SearchBox
import Session exposing (Session)
import Shared
import Sprite
import UI.Button as Button
import UI.Checkbox as Checkbox
import UI.Dropdown as Dropdown
import UI.Effects as Effects
import UI.Icon as Icon
import UI.Palette as Palette
import UI.RenderConfig exposing (RenderConfig)
import UI.TextField as TextField
import Url
import Url.Builder
import View exposing (View)


type alias FormOptions =
    { tooltip : Maybe Tooltip
    , today : Date
    , problems : List Problem
    , originalJudgment : Judgment
    , courtrooms : List Courtroom
    , attorneys : List Attorney
    , plaintiffs : List Plaintiff
    , judges : List Judge
    , showHelp : Bool
    , showDocument : Maybe Bool
    , renderConfig : RenderConfig
    }


type Problem
    = InvalidEntry ValidatedField String


type Tooltip
    = FileDateDetail
    | CourtroomInfo
    | Summary
    | FeesAwardedInfo
    | PossessionAwardedInfo
    | FeesHaveInterestInfo
    | InterestRateFollowsSiteInfo
    | InterestRateInfo
    | DismissalBasisInfo
    | WithPrejudiceInfo
    | NotesDetail
    | PresidingJudgeInfo
    | PlaintiffAttorneyInfo
    | PlaintiffInfo


type SaveState
    = SavingJudgment
    | Done


type alias Model =
    { id : Maybe Int
    , judgment : Maybe Judgment
    , courtrooms : List Courtroom
    , attorneys : List Attorney
    , plaintiffs : List Plaintiff
    , judges : List Judge
    , tooltip : Maybe Tooltip
    , problems : List Problem
    , form : FormStatus
    , saveState : SaveState
    , newFormOnSuccess : Bool
    , showHelp : Bool
    , showDocument : Maybe Bool
    }


boxAttrs =
    [ Palette.toBorderColor Palette.gray300
    , Palette.toBackgroundColor Palette.gray200
    , Palette.toFontColor Palette.genericBlack
    , Font.semiBold
    , paddingXY 18 16
    , Border.rounded 8
    , Font.size 14
    , Font.family [ Font.typeface "Fira Sans", Font.sansSerif ]
    , Element.focused
        [ Border.color <| Palette.toElementColor Palette.blue300
        ]
    ]


searchBox attrs =
    SearchBox.input
        (boxAttrs
            ++ [ width fill ]
            ++ attrs
        )


firstAliasMatch query person =
    List.find (insensitiveMatch query) person.aliases


withAliasBadge str =
    str ++ " [Alias]"


judgmentFormInit : Date -> Judgment -> JudgmentForm
judgmentFormInit today judgment =
    let
        default =
            { id = Just judgment.id
            , awardsFees = ""
            , awardsPossession = False
            , hasInterest = False
            , interestFollowsSite = True
            , interestRate = ""
            , dismissalBasis = NonSuitByPlaintiff
            , withPrejudice = False
            , enteredBy = judgment.enteredBy
            , condition = Nothing
            , conditionsDropdown = Dropdown.init "judgment-dropdown"
            , dismissalBasisDropdown = Dropdown.init "judgment-dropdown-dismissal-basis"
            , plaintiff =
                { text =
                    Maybe.withDefault "" <|
                        Maybe.map .name judgment.plaintiff
                , person = judgment.plaintiff
                , searchBox = SearchBox.init
                }
            , plaintiffAttorney =
                { text =
                    Maybe.withDefault "" <|
                        Maybe.map .name judgment.plaintiffAttorney
                , person = judgment.plaintiffAttorney
                , searchBox = SearchBox.init
                }
            , judge =
                { text =
                    Maybe.withDefault "" <|
                        Maybe.map .name judgment.judge
                , person = judgment.judge
                , searchBox = SearchBox.init
                }
            , notes = Maybe.withDefault "" judgment.notes
            }
    in
    case judgment.conditions of
        Just (PlaintiffConditions owed) ->
            { default
                | condition = Just PlaintiffOption
                , awardsFees = Maybe.withDefault "" <| Maybe.map String.fromFloat owed.awardsFees
                , awardsPossession = Maybe.withDefault False owed.awardsPossession
                , hasInterest = owed.interest /= Nothing
                , interestRate =
                    case owed.interest of
                        Just (WithRate rate) ->
                            String.fromFloat rate

                        _ ->
                            ""
                , interestFollowsSite =
                    case owed.interest of
                        Just FollowsSite ->
                            True

                        _ ->
                            False
            }

        Just (DefendantConditions dismissal) ->
            { default
                | condition = Just DefendantOption
                , dismissalBasis = dismissal.basis
                , withPrejudice = dismissal.withPrejudice
            }

        Nothing ->
            default


type FormStatus
    = Initializing Int
    | Ready JudgmentForm
    | NotFound


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
      , courtrooms = []
      , attorneys = []
      , plaintiffs = []
      , judges = []
      , id = maybeId
      , tooltip = Nothing
      , problems = []
      , form =
            case maybeId of
                Just id ->
                    Initializing id

                Nothing ->
                    NotFound
      , saveState = Done
      , showHelp = False
      , showDocument = Nothing
      , newFormOnSuccess = False
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
    | GotPlaintiffs (Result Http.Error (Rest.Collection Plaintiff))
    | GotAttorneys (Result Http.Error (Rest.Collection Attorney))
    | GotJudges (Result Http.Error (Rest.Collection Attorney))
    | CloseTooltip
    | PickedConditions (Maybe (Maybe ConditionOption))
    | ConditionsDropdownMsg (Dropdown.Msg (Maybe ConditionOption))
    | ChangedFeesAwarded String
    | ConfirmedFeesAwarded
    | TogglePossession Bool
    | ToggleInterest Bool
    | ChangedInterestRate String
    | ConfirmedInterestRate
    | ToggleInterestFollowSite Bool
    | DismissalBasisDropdownMsg (Dropdown.Msg DismissalBasis)
    | PickedDismissalBasis (Maybe DismissalBasis)
    | ToggledWithPrejudice Bool
    | ChangedPlaintiffSearchBox (SearchBox.ChangeEvent Plaintiff)
    | ChangedAttorneySearchBox (SearchBox.ChangeEvent Attorney)
    | ChangedJudgeSearchBox (SearchBox.ChangeEvent Judge)
    | ChangedNotes String
    | ToggleOpenDocument
    | SubmitForm
    | SubmitAndAddAnother
    | UpdatedJudgment (Result Http.Error (Rest.Item Judgment))
    | NoOp


basicDropdown { config, itemToStr, selected, items } =
    Dropdown.basic config
        |> Dropdown.withItems items
        |> Dropdown.withSelected selected
        |> Dropdown.withItemToText itemToStr
        |> Dropdown.withMaximumListHeight 200


dismissalBasisDropdown judgment =
    basicDropdown
        { config =
            { dropdownMsg = DismissalBasisDropdownMsg
            , onSelectMsg = PickedDismissalBasis
            , state = judgment.dismissalBasisDropdown
            }
        , selected = Just judgment.dismissalBasis
        , itemToStr = Judgment.dismissalBasisOption
        , items = Judgment.dismissalBasisOptions
        }


conditionsDropdown judgment =
    basicDropdown
        { config =
            { dropdownMsg = ConditionsDropdownMsg
            , onSelectMsg = PickedConditions
            , state = judgment.conditionsDropdown
            }
        , selected = Just judgment.condition
        , itemToStr = Maybe.withDefault "N/A" << Maybe.map Judgment.conditionText
        , items = Judgment.conditionsOptions
        }


updateFormOnly : (JudgmentForm -> JudgmentForm) -> Model -> Model
updateFormOnly transform model =
    { model
        | form =
            case model.form of
                NotFound ->
                    model.form

                Initializing _ ->
                    model.form

                Ready oldForm ->
                    Ready (transform oldForm)
    }


updateFormNarrow : (JudgmentForm -> ( JudgmentForm, Cmd Msg )) -> Model -> ( Model, Cmd Msg )
updateFormNarrow transform model =
    let
        ( newForm, cmd ) =
            case model.form of
                NotFound ->
                    ( model.form, Cmd.none )

                Initializing _ ->
                    ( model.form, Cmd.none )

                Ready oldForm ->
                    let
                        ( updatedForm, dropdownCmd ) =
                            transform oldForm
                    in
                    ( Ready updatedForm, dropdownCmd )
    in
    ( { model
        | form = newForm
      }
    , cmd
    )


updateForm : (JudgmentForm -> JudgmentForm) -> Model -> ( Model, Cmd Msg )
updateForm transform model =
    ( { model
        | form =
            case model.form of
                NotFound ->
                    model.form

                Initializing _ ->
                    model.form

                Ready oldForm ->
                    Ready (transform oldForm)
      }
    , Cmd.none
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
        today =
            static.sharedData.runtime.today

        session =
            sharedModel.session

        maybeCred =
            Session.cred session

        cfg =
            sharedModel.renderConfig

        rollbar =
            Log.reporting static.sharedData.runtime

        domain =
            Runtime.domain static.sharedData.runtime.environment

        logHttpError =
            error rollbar << Log.httpErrorMessage
    in
    case msg of
        GotJudgment result ->
            case result of
                Ok judgmentPage ->
                    ( { model
                        | judgment = Just judgmentPage.data
                        , form = Ready (judgmentFormInit today judgmentPage.data)
                        , showDocument =
                            if judgmentPage.data.document == Nothing then
                                Nothing

                            else
                                Just False
                      }
                    , Cmd.none
                    )

                Err httpError ->
                    ( model, logHttpError httpError )

        GotPlaintiffs (Ok plaintiffsPage) ->
            ( { model | plaintiffs = plaintiffsPage.data }, Cmd.none )

        GotPlaintiffs (Err httpError) ->
            ( model, logHttpError httpError )

        GotAttorneys (Ok attorneysPage) ->
            ( { model | attorneys = attorneysPage.data }, Cmd.none )

        GotAttorneys (Err httpError) ->
            ( model, logHttpError httpError )

        GotJudges (Ok judgesPage) ->
            ( { model | judges = judgesPage.data }, Cmd.none )

        GotJudges (Err httpError) ->
            ( model, logHttpError httpError )

        CloseTooltip ->
            ( { model | tooltip = Nothing }, Cmd.none )

        ConditionsDropdownMsg subMsg ->
            updateFormNarrow
                (\form ->
                    let
                        ( newState, newCmd ) =
                            Dropdown.update cfg subMsg (conditionsDropdown form)
                    in
                    ( { form | conditionsDropdown = newState }, Effects.perform newCmd )
                )
                model

        PickedConditions option ->
            updateForm
                (\form -> { form | condition = Maybe.andThen identity option })
                model

        ChangedFeesAwarded money ->
            updateForm
                (\judgment -> { judgment | awardsFees = String.replace "$" "" money })
                model

        ConfirmedFeesAwarded ->
            let
                extract money =
                    String.toFloat (String.replace "," "" money)

                options =
                    Mask.defaultDecimalOptions
            in
            updateForm
                (\form ->
                    { form
                        | awardsFees =
                            case extract form.awardsFees of
                                Just moneyFloat ->
                                    Mask.floatDecimal options moneyFloat

                                Nothing ->
                                    form.awardsFees
                    }
                )
                model

        DismissalBasisDropdownMsg subMsg ->
            updateFormNarrow
                (\form ->
                    let
                        ( newState, newCmd ) =
                            Dropdown.update cfg subMsg (dismissalBasisDropdown form)
                    in
                    ( { form | dismissalBasisDropdown = newState }, Effects.perform newCmd )
                )
                model

        PickedDismissalBasis option ->
            updateForm
                (\form -> { form | dismissalBasis = Maybe.withDefault FailureToProsecute option })
                model

        TogglePossession checked ->
            updateForm
                (\judgment -> { judgment | awardsPossession = checked })
                model

        ToggleInterest checked ->
            updateForm
                (\judgment -> { judgment | hasInterest = checked })
                model

        ChangedInterestRate interestRate ->
            updateForm
                (\judgment -> { judgment | interestRate = String.replace "%" "" interestRate })
                model

        ConfirmedInterestRate ->
            updateForm
                (\judgment -> { judgment | interestRate = String.replace "%" "" judgment.interestRate ++ "%" })
                model

        ToggleInterestFollowSite checked ->
            updateForm
                (\judgment -> { judgment | interestFollowsSite = checked })
                model

        ToggledWithPrejudice checked ->
            updateForm
                (\form -> { form | withPrejudice = checked })
                model

        ChangedPlaintiffSearchBox changeEvent ->
            case changeEvent of
                SearchBox.SelectionChanged person ->
                    updateForm
                        (\form ->
                            let
                                plaintiff =
                                    form.plaintiff

                                updatedPlaintiff =
                                    { plaintiff | person = Just person }
                            in
                            { form | plaintiff = updatedPlaintiff }
                        )
                        model

                SearchBox.TextChanged text ->
                    ( updateFormOnly
                        (\form ->
                            let
                                plaintiff =
                                    form.plaintiff

                                updatedPlaintiff =
                                    { plaintiff
                                        | person = Nothing
                                        , text = text
                                        , searchBox = SearchBox.reset plaintiff.searchBox
                                    }
                            in
                            { form | plaintiff = updatedPlaintiff }
                        )
                        model
                    , Rest.get (Endpoint.plaintiffs domain [ ( "free_text", text ) ]) maybeCred GotPlaintiffs (Rest.collectionDecoder Plaintiff.decoder)
                    )

                SearchBox.SearchBoxChanged subMsg ->
                    updateForm
                        (\form ->
                            let
                                plaintiff =
                                    form.plaintiff

                                updatedPlaintiff =
                                    { plaintiff
                                        | searchBox = SearchBox.update subMsg plaintiff.searchBox
                                    }
                            in
                            { form | plaintiff = updatedPlaintiff }
                        )
                        model

        ChangedAttorneySearchBox changeEvent ->
            case changeEvent of
                SearchBox.SelectionChanged person ->
                    updateForm
                        (\form ->
                            let
                                plaintiffAttorney =
                                    form.plaintiffAttorney

                                updatedPlaintiff =
                                    { plaintiffAttorney | person = Just person }
                            in
                            { form | plaintiffAttorney = updatedPlaintiff }
                        )
                        model

                SearchBox.TextChanged text ->
                    ( updateFormOnly
                        (\form ->
                            let
                                plaintiffAttorney =
                                    form.plaintiffAttorney

                                updatedAttorney =
                                    { plaintiffAttorney
                                        | person = Nothing
                                        , text = text
                                        , searchBox = SearchBox.reset plaintiffAttorney.searchBox
                                    }
                            in
                            { form | plaintiffAttorney = updatedAttorney }
                        )
                        model
                    , Rest.get (Endpoint.attorneys domain [ ( "free_text", text ) ]) maybeCred GotAttorneys (Rest.collectionDecoder Attorney.decoder)
                    )

                SearchBox.SearchBoxChanged subMsg ->
                    updateForm
                        (\form ->
                            let
                                plaintiffAttorney =
                                    form.plaintiffAttorney

                                updatedAttorney =
                                    { plaintiffAttorney
                                        | searchBox = SearchBox.update subMsg plaintiffAttorney.searchBox
                                    }
                            in
                            { form | plaintiffAttorney = updatedAttorney }
                        )
                        model

        ChangedJudgeSearchBox changeEvent ->
            case changeEvent of
                SearchBox.SelectionChanged person ->
                    updateForm
                        (\form ->
                            let
                                judge =
                                    form.judge

                                updatedJudge =
                                    { judge | person = Just person }
                            in
                            { form | judge = updatedJudge }
                        )
                        model

                SearchBox.TextChanged text ->
                    ( updateFormOnly
                        (\form ->
                            let
                                judge =
                                    form.judge

                                updatedJudge =
                                    { judge
                                        | person = Nothing
                                        , text = text
                                        , searchBox = SearchBox.reset judge.searchBox
                                    }
                            in
                            { form | judge = updatedJudge }
                        )
                        model
                    , Rest.get (Endpoint.judges domain [ ( "free_text", text ) ]) maybeCred GotJudges (Rest.collectionDecoder Judge.decoder)
                    )

                SearchBox.SearchBoxChanged subMsg ->
                    updateForm
                        (\form ->
                            let
                                judge =
                                    form.judge

                                updatedJudge =
                                    { judge
                                        | searchBox = SearchBox.update subMsg judge.searchBox
                                    }
                            in
                            { form | judge = updatedJudge }
                        )
                        model

        ChangedNotes notes ->
            updateForm (\form -> { form | notes = notes }) model

        ToggleOpenDocument ->
            ( case model.judgment of
                Just judgment ->
                    case judgment.document of
                        Just _ ->
                            { model | showDocument = Maybe.map not model.showDocument }

                        Nothing ->
                            model

                Nothing ->
                    model
            , Cmd.none
            )

        SubmitForm ->
            submitForm today domain session model

        SubmitAndAddAnother ->
            submitFormAndAddAnother today domain session model

        UpdatedJudgment (Ok judgmentItem) ->
            nextStepSave
                today
                session
                { model
                    | judgment = Just judgmentItem.data
                }

        UpdatedJudgment (Err httpError) ->
            ( model, logHttpError httpError )

        NoOp ->
            ( model, Cmd.none )


error : Rollbar -> String -> Cmd Msg
error rollbar report =
    Log.error rollbar (\_ -> NoOp) report


submitFormAndAddAnother : Date -> String -> Session -> Model -> ( Model, Cmd Msg )
submitFormAndAddAnother today domain session model =
    Tuple.mapFirst (\m -> { m | newFormOnSuccess = True }) (submitForm today domain session model)


submitForm : Date -> String -> Session -> Model -> ( Model, Cmd Msg )
submitForm today domain session model =
    let
        maybeCred =
            Session.cred session
    in
    case ( validate model.form, model.judgment ) of
        ( Ok (Trimmed validForm), Just _ ) ->
            let
                judgmentData =
                    Judgment.editFromForm today validForm
            in
            ( { model
                | newFormOnSuccess = False
                , problems = []
                , saveState = SavingJudgment
              }
            , updateJudgment domain maybeCred judgmentData
            )

        ( Err problems, _ ) ->
            ( { model | newFormOnSuccess = False, problems = problems }
            , Cmd.none
            )

        _ ->
            ( model, Cmd.none )


nextStepSave : Date -> Session -> Model -> ( Model, Cmd Msg )
nextStepSave today session model =
    case ( validate model.form, model.judgment ) of
        ( Ok (Trimmed _), Just judgment ) ->
            case model.saveState of
                SavingJudgment ->
                    ( { model | saveState = Done }
                    , Cmd.none
                    )

                Done ->
                    ( model
                    , if model.newFormOnSuccess then
                        Maybe.withDefault Cmd.none <|
                            Maybe.map (\key -> Nav.replaceUrl key (Url.Builder.relative [] [])) (Session.navKey session)

                      else
                        Maybe.withDefault Cmd.none <|
                            Maybe.map (\key -> Nav.replaceUrl key (Url.Builder.relative [ String.fromInt judgment.id ] [])) (Session.navKey session)
                    )

        _ ->
            ( model, Cmd.none )


type alias Field =
    { tooltip : Maybe Tooltip
    , description : String
    , children : List (Element Msg)
    }


withTooltip : Bool -> String -> List (Element Msg)
withTooltip showHelp str =
    if showHelp then
        [ viewTooltip str ]

    else
        []


viewField : Bool -> Field -> Element Msg
viewField showHelp field =
    let
        tooltip =
            case field.tooltip of
                Just _ ->
                    withTooltip showHelp field.description

                Nothing ->
                    []
    in
    column
        [ width fill
        , height fill
        , spacingXY 5 5
        , paddingXY 0 10
        ]
        (field.children ++ tooltip)


viewNotes : FormOptions -> JudgmentForm -> Element Msg
viewNotes options form =
    column [ width fill ]
        [ viewField options.showHelp
            { tooltip = Just NotesDetail
            , description = "Any additional notes you have about this particular judgment go here!"
            , children =
                [ TextField.multilineText ChangedNotes
                    "Notes"
                    form.notes
                    |> TextField.withPlaceholder "Add any notes from the judgment sheet or any comments you think is noteworthy."
                    |> TextField.setLabelVisible True
                    |> TextField.withWidth TextField.widthFull
                    |> TextField.renderElement options.renderConfig
                ]
            }
        ]


submitAndAddAnother : RenderConfig -> Element Msg
submitAndAddAnother cfg =
    Button.fromLabeledOnRightIcon (Icon.add "Save and add another")
        |> Button.cmd SubmitAndAddAnother Button.clear
        |> Button.renderElement cfg


submitButton : RenderConfig -> Element Msg
submitButton cfg =
    Button.fromLabeledOnRightIcon (Icon.check "Save")
        |> Button.cmd SubmitForm Button.primary
        |> Button.renderElement cfg


viewForm : FormOptions -> FormStatus -> Element Msg
viewForm options formStatus =
    case formStatus of
        NotFound ->
            column [] [ text "Page not found" ]

        Initializing id ->
            column [] [ text ("Fetching judgment " ++ String.fromInt id) ]

        Ready form ->
            column [ centerX, spacing 30, width (fill |> maximum 1200) ]
                [ viewJudgment options form
                , row [ Element.alignRight, spacing 10 ]
                    [ submitAndAddAnother options.renderConfig
                    , submitButton options.renderConfig
                    ]
                ]


formOptions : RenderConfig -> Date -> Judgment -> Model -> FormOptions
formOptions cfg today judgment model =
    { tooltip = model.tooltip
    , today = today
    , problems = model.problems
    , originalJudgment = judgment
    , courtrooms = model.courtrooms
    , plaintiffs = model.plaintiffs
    , attorneys = model.attorneys
    , judges = model.judges
    , showHelp = False
    , showDocument = model.showDocument
    , renderConfig = cfg
    }


viewProblem : Problem -> Element Msg
viewProblem problem =
    paragraph []
        [ case problem of
            InvalidEntry _ _ ->
                Element.none
        ]


viewProblems : List Problem -> Element Msg
viewProblems problems =
    row [] [ column [] (List.map viewProblem problems) ]


labelAttrs =
    [ Palette.toFontColor Palette.gray700, Font.size 12 ]


defaultLabel str =
    Input.labelAbove labelAttrs (text str)


insensitiveMatch a b =
    String.contains (String.toLower a) (String.toLower b)


matchesQuery query person =
    List.any (insensitiveMatch query) (person.name :: person.aliases)


matchesName query person =
    insensitiveMatch query person.name


viewTooltip : String -> Element Msg
viewTooltip str =
    textColumn
        [ width (fill |> maximum 280)
        , padding 10
        , Palette.toBackgroundColor Palette.blue600
        , Palette.toFontColor Palette.genericWhite
        , Border.rounded 3
        , Font.size 14
        , Border.shadow
            { offset = ( 0, 3 ), blur = 6, size = 0, color = Element.rgba 0 0 0 0.32 }
        ]
        [ paragraph [] [ text str ] ]


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

        today =
            static.sharedData.runtime.today
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
                , viewProblems model.problems
                , row [ width fill ]
                    [ case model.judgment of
                        Just judgment ->
                            viewForm (formOptions cfg today judgment model) model.form

                        Nothing ->
                            Element.none
                    ]
                ]
            ]
        ]
    }


withChanges hasChanged attrs =
    attrs
        ++ (if hasChanged then
                [ Palette.toBorderColor Palette.yellow300 ]

            else
                []
           )


viewCourtDate options =
    viewField options.showHelp
        { tooltip = Just FileDateDetail
        , description = "The date this judgment was determined."
        , children =
            [ column [ spacing 5, width fill ]
                [ el labelAttrs (text "Courtroom")
                , el [] (text (Date.format "MMMM ddd, yyyy t" <| Date.Extra.fromPosix options.originalJudgment.hearing.courtDate))
                ]
            ]
        }


viewCourtroom : FormOptions -> Element Msg
viewCourtroom options =
    column [ width fill ]
        [ viewField options.showHelp
            { tooltip = Just CourtroomInfo
            , description = "The court room where eviction proceedings will occur."
            , children =
                [ column [ spacing 5, width fill ]
                    [ el labelAttrs (text "Courtroom")
                    , el [] (text <| Maybe.withDefault "-" <| Maybe.map .name options.originalJudgment.hearing.courtroom)
                    ]
                ]
            }
        ]


viewPlaintiffSearch : (SearchBox.ChangeEvent Plaintiff -> Msg) -> FormOptions -> PlaintiffForm -> Element Msg
viewPlaintiffSearch onChange options form =
    let
        hasChanges =
            False
    in
    row [ width fill ]
        [ viewField options.showHelp
            { tooltip = Just PlaintiffInfo
            , description = "The plaintiff is typically the landlord seeking money or possession from the defendant (tenant)."
            , children =
                [ searchBox (withChanges hasChanges [])
                    { onChange = onChange
                    , text = form.text
                    , selected = form.person
                    , options = Just ({ id = -1, name = form.text, aliases = [] } :: options.plaintiffs)
                    , label = defaultLabel "Plaintiff"
                    , placeholder = Just <| Input.placeholder [] (text "Search for plaintiff")
                    , toLabel =
                        \person ->
                            if List.isEmpty person.aliases then
                                person.name

                            else if matchesName form.text person then
                                person.name

                            else
                                Maybe.withDefault person.name <| Maybe.map withAliasBadge <| firstAliasMatch form.text person
                    , filter = matchesQuery
                    , state = form.searchBox
                    }
                ]
            }
        ]


viewAttorneySearch : (SearchBox.ChangeEvent Attorney -> Msg) -> FormOptions -> AttorneyForm -> Element Msg
viewAttorneySearch onChange options form =
    let
        hasChanges =
            False
    in
    column [ width fill ]
        [ viewField options.showHelp
            { tooltip = Just PlaintiffAttorneyInfo
            , description = "The plaintiff attorney is the legal representation for the plaintiff in this eviction process."
            , children =
                [ searchBox (withChanges hasChanges [])
                    { onChange = onChange
                    , text = form.text
                    , selected = form.person
                    , options = Just ({ id = -1, name = form.text, aliases = [] } :: options.attorneys)
                    , label = defaultLabel "Plaintiff Attorney"
                    , placeholder = Just <| Input.placeholder [] (text "Search for plaintiff attorney")
                    , toLabel =
                        \person ->
                            if List.isEmpty person.aliases then
                                person.name

                            else if matchesName form.text person then
                                person.name

                            else
                                Maybe.withDefault person.name <| Maybe.map withAliasBadge <| firstAliasMatch form.text person
                    , filter = matchesQuery
                    , state = form.searchBox
                    }
                ]
            }
        ]


viewJudgeSearch : FormOptions -> JudgmentForm -> Element Msg
viewJudgeSearch options form =
    let
        hasChanges =
            False

        -- (Maybe.withDefault False <|
        --     Maybe.map ((/=) form.judge.person << .judge) options.originalJudgment
        -- )
        --     || (options.originalJudgment == Nothing && form.presidingJudge.text /= "")
    in
    column [ width fill ]
        [ viewField options.showHelp
            { tooltip = Just PresidingJudgeInfo
            , description = "The judge that will be presiding over the court case."
            , children =
                [ searchBox (withChanges hasChanges [])
                    { onChange = ChangedJudgeSearchBox
                    , text = form.judge.text
                    , selected = form.judge.person
                    , options = Just ({ id = -1, name = form.judge.text, aliases = [] } :: options.judges)
                    , label = defaultLabel "Presiding judge"
                    , placeholder = Just <| Input.placeholder [] (text "Search for judge")
                    , toLabel =
                        \person ->
                            if List.isEmpty person.aliases then
                                person.name

                            else if matchesName form.judge.text person then
                                person.name

                            else
                                Maybe.withDefault person.name <| Maybe.map withAliasBadge <| firstAliasMatch form.judge.text person
                    , filter = matchesQuery
                    , state = form.judge.searchBox
                    }
                ]
            }
        ]


viewJudgmentPossession : FormOptions -> JudgmentForm -> Element Msg
viewJudgmentPossession options form =
    viewField options.showHelp
        { tooltip = Just PossessionAwardedInfo
        , description = "Has the Plaintiff claimed the residence?"
        , children =
            [ el
                [ width (fill |> minimum 200)
                , paddingEach { top = 17, bottom = 0, left = 0, right = 0 }
                ]
                (Checkbox.checkbox
                    "Possession awarded"
                    TogglePossession
                    form.awardsPossession
                    |> Checkbox.renderElement options.renderConfig
                )
            ]
        }


viewJudgmentInterest : FormOptions -> JudgmentForm -> Element Msg
viewJudgmentInterest options form =
    column []
        [ row [ spacing 5 ]
            [ viewField options.showHelp
                { tooltip = Just FeesHaveInterestInfo
                , description = "Do the fees claimed have interest?"
                , children =
                    [ el
                        [ width (fill |> minimum 200)

                        -- , paddingEach { top = 17, bottom = 0, left = 0, right = 0 }
                        ]
                        (Checkbox.checkbox
                            "Fees have interest"
                            ToggleInterest
                            form.hasInterest
                            |> Checkbox.renderElement options.renderConfig
                        )
                    ]
                }
            , if form.hasInterest then
                viewField options.showHelp
                    { tooltip = Just InterestRateFollowsSiteInfo
                    , description = "Does the interest rate follow from the website?"
                    , children =
                        [ column [ spacing 5, width fill ]
                            [ Checkbox.checkbox
                                "Interest rate follows site"
                                ToggleInterestFollowSite
                                form.interestFollowsSite
                                |> Checkbox.renderElement options.renderConfig
                            ]
                        ]
                    }

              else
                Element.none
            ]
        , if form.interestFollowsSite then
            Element.none

          else
            viewField options.showHelp
                { tooltip = Just InterestRateInfo
                , description = "The rate of interest that accrues for fees."
                , children =
                    [ column [ spacing 5, width fill ]
                        [ TextField.singlelineText ChangedInterestRate
                            "Interest rate"
                            form.interestRate
                            |> TextField.setLabelVisible True
                            |> TextField.withOnEnterPressed ConfirmedInterestRate
                            |> TextField.withPlaceholder "0%"
                            |> TextField.renderElement options.renderConfig
                        ]
                    ]
                }
        ]


viewJudgmentPlaintiff : FormOptions -> JudgmentForm -> List (Element Msg)
viewJudgmentPlaintiff options form =
    [ viewField options.showHelp
        { tooltip = Just FeesAwardedInfo
        , description = "Fees the Plaintiff has been awarded."
        , children =
            [ TextField.singlelineText ChangedFeesAwarded
                "Fees awarded"
                (if form.awardsFees == "" then
                    form.awardsFees

                 else
                    "$" ++ form.awardsFees
                )
                |> TextField.setLabelVisible True
                |> TextField.withPlaceholder "$0.00"
                |> TextField.withOnEnterPressed ConfirmedFeesAwarded
                |> TextField.renderElement options.renderConfig
            ]
        }
    , viewJudgmentPossession options form
    ]


viewJudgmentDefendant : FormOptions -> JudgmentForm -> List (Element Msg)
viewJudgmentDefendant options form =
    [ viewField options.showHelp
        { tooltip = Just DismissalBasisInfo
        , description = "Why is the case being dismissed?"
        , children =
            [ column [ spacing 5, width (fill |> minimum 350) ]
                [ el labelAttrs (text "Basis for dismissal")
                , dismissalBasisDropdown form
                    |> Dropdown.renderElement options.renderConfig
                ]
            ]
        }
    , viewField options.showHelp
        { tooltip = Just WithPrejudiceInfo
        , description = "Whether or not the dismissal is made with prejudice."
        , children =
            [ el
                [ width (fill |> minimum 200)
                , paddingEach { top = 17, bottom = 0, left = 0, right = 0 }
                ]
                (Checkbox.checkbox
                    "Dismissal is with prejudice"
                    ToggledWithPrejudice
                    form.withPrejudice
                    |> Checkbox.renderElement options.renderConfig
                )
            ]
        }
    ]


viewJudgment : FormOptions -> JudgmentForm -> Element Msg
viewJudgment options form =
    column
        ([ width fill
         , spacing 10
         , padding 20
         , Border.width 1
         , Palette.toBorderColor Palette.gray300
         , Border.innerGlow (Palette.toElementColor Palette.gray300) 1
         , Border.rounded 5
         ]
            ++ (case options.originalJudgment.document of
                    Just _ ->
                        [ inFront
                            (row [ Element.alignRight, padding 20 ]
                                [ Button.fromIcon (Icon.legacyReport "Open PDF")
                                    |> Button.cmd ToggleOpenDocument Button.primary
                                    |> Button.renderElement options.renderConfig
                                ]
                            )
                        ]

                    Nothing ->
                        []
               )
        )
        [ row
            [ spacing 5
            ]
            [ viewCourtDate options
            , viewCourtroom options
            ]
        , wrappedRow [ spacing 5, width fill ]
            [ viewPlaintiffSearch ChangedPlaintiffSearchBox options form.plaintiff
            , viewAttorneySearch ChangedAttorneySearchBox options form.plaintiffAttorney
            , viewJudgeSearch options form
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
                [ viewField options.showHelp
                    { tooltip = Just Summary
                    , description = "The ruling from the court that will determine if fees or repossession are enforced."
                    , children =
                        [ column [ spacing 5, width (fill |> maximum 200) ]
                            [ el labelAttrs (text "Granted to")
                            , conditionsDropdown form
                                |> Dropdown.renderElement options.renderConfig
                            ]
                        ]
                    }
                ]
            , row [ spacing 5, width fill ]
                (case form.condition of
                    Just PlaintiffOption ->
                        viewJudgmentPlaintiff options form

                    Just DefendantOption ->
                        viewJudgmentDefendant options form

                    Nothing ->
                        [ Element.none ]
                )
            , if form.awardsFees /= "" && form.condition == Just PlaintiffOption then
                viewJudgmentInterest options form

              else
                Element.none
            , viewNotes options form
            , row [ spacing 5, width fill ]
                [ if options.showDocument == Just True then
                    case options.originalJudgment.document of
                        Just pleading ->
                            column [ width fill ]
                                [ row [ width fill ]
                                    [ Element.html <|
                                        Html.embed
                                            [ Html.Attributes.width 800
                                            , Html.Attributes.height 1600
                                            , Html.Attributes.src (Url.toString pleading.url)
                                            ]
                                            []
                                    ]
                                ]

                        Nothing ->
                            Element.none

                  else
                    Element.none
                ]
            ]
        ]


subscriptions : Maybe PageUrl -> RouteParams -> Path -> Model -> Sub Msg
subscriptions pageUrl params path model =
    case model.form of
        NotFound ->
            Sub.none

        Initializing _ ->
            Sub.none

        Ready _ ->
            Sub.batch
                (List.concat
                    [ Maybe.withDefault [] (Maybe.map (List.singleton << onOutsideClick) model.tooltip)
                    ]
                )


isOutsideTooltip : String -> Decode.Decoder Bool
isOutsideTooltip tooltipId =
    Decode.oneOf
        [ Decode.field "id" Decode.string
            |> Decode.andThen
                (\id ->
                    if tooltipId == id then
                        Decode.succeed False

                    else
                        Decode.fail "continue"
                )
        , Decode.lazy (\_ -> isOutsideTooltip tooltipId |> Decode.field "parentNode")
        , Decode.succeed True
        ]


outsideTarget : String -> Msg -> Decode.Decoder Msg
outsideTarget tooltipId msg =
    Decode.field "target" (isOutsideTooltip tooltipId)
        |> Decode.andThen
            (\isOutside ->
                if isOutside then
                    Decode.succeed msg

                else
                    Decode.fail "inside dropdown"
            )


onOutsideClick : Tooltip -> Sub Msg
onOutsideClick tip =
    onMouseDown (outsideTarget (tooltipToString tip) CloseTooltip)


tooltipToString : Tooltip -> String
tooltipToString tip =
    case tip of
        FileDateDetail ->
            "file-date-detail"

        CourtroomInfo ->
            "courtroom"

        Summary ->
            "summary"

        FeesAwardedInfo ->
            "fees-claimed-info"

        PossessionAwardedInfo ->
            "possession-claimed-info"

        FeesHaveInterestInfo ->
            "fees-have-interest-info"

        InterestRateFollowsSiteInfo ->
            "interest-rate-follows-site-info"

        InterestRateInfo ->
            "interest-rate-info"

        DismissalBasisInfo ->
            "dismissal-basis-info"

        WithPrejudiceInfo ->
            "with-prejudice-info"

        NotesDetail ->
            "notes-detail"

        PresidingJudgeInfo ->
            "presiding-judge-info"

        PlaintiffAttorneyInfo ->
            "plaintiff-attorney-info"

        PlaintiffInfo ->
            "plaintiff-info"



-- FORM


{-| Marks that we've trimmed the form's fields, so we don't accidentally send
it to the server without having trimmed it!
-}
type TrimmedForm
    = Trimmed JudgmentForm


{-| When adding a variant here, add it to `fieldsToValidate` too!
-}
type ValidatedField
    = JudgmentFileDate


fieldsToValidate : List ValidatedField
fieldsToValidate =
    []


{-| Trim the form and validate its fields. If there are problems, report them!
-}
validate : FormStatus -> Result (List Problem) TrimmedForm
validate formStatus =
    case formStatus of
        NotFound ->
            Err []

        Initializing _ ->
            Err []

        Ready form ->
            let
                trimmedForm =
                    trimFields form
            in
            case List.concatMap (validateField trimmedForm) fieldsToValidate of
                [] ->
                    Ok trimmedForm

                problems ->
                    Err problems


validateField : TrimmedForm -> ValidatedField -> List Problem
validateField (Trimmed form) field =
    List.map (InvalidEntry field) []


{-| Don't trim while the user is typing! That would be super annoying.
Instead, trim only on submit.
-}
trimFields : JudgmentForm -> TrimmedForm
trimFields form =
    Trimmed
        { form
            | notes = String.trim form.notes
        }


conditional fieldNotes fn field =
    Maybe.withDefault [] <| Maybe.map (\f -> [ ( fieldNotes, fn f ) ]) field


encodeRelated record =
    Encode.object [ ( "id", Encode.int record.id ) ]


nullable fieldName fn field =
    Maybe.withDefault [ ( fieldName, Encode.null ) ] <| Maybe.map (\f -> [ ( fieldName, fn f ) ]) field


toBody body =
    Encode.object [ ( "data", body ) ]
        |> Http.jsonBody


encodeJudgment : JudgmentEdit -> Encode.Value
encodeJudgment judgment =
    Encode.object
        ([ ( "interest", Encode.bool judgment.hasInterest )
         ]
            ++ conditional "id" Encode.int judgment.id
            ++ nullable "in_favor_of" Encode.string judgment.inFavorOf
            ++ nullable "notes" Encode.string judgment.notes
            ++ nullable "entered_by" Encode.string judgment.enteredBy
            ++ nullable "awards_fees" Encode.float judgment.awardsFees
            ++ nullable "awards_possession" Encode.bool judgment.awardsPossession
            ++ nullable "interest_rate" Encode.float judgment.interestRate
            ++ nullable "interest_follows_site" Encode.bool judgment.interestFollowsSite
            ++ nullable "dismissal_basis"
                Encode.string
                (if judgment.inFavorOf == Just "DEFENDANT" then
                    judgment.dismissalBasis

                 else
                    Nothing
                )
            ++ nullable "with_prejudice"
                Encode.bool
                (if judgment.inFavorOf == Just "DEFENDANT" then
                    judgment.withPrejudice

                 else
                    Nothing
                )
            ++ nullable "plaintiff" encodeRelated judgment.plaintiff
            ++ nullable "plaintiff_attorney" encodeRelated judgment.plaintiffAttorney
            ++ nullable "judge" encodeRelated judgment.judge
        )


updateJudgment : String -> Maybe Cred -> JudgmentEdit -> Cmd Msg
updateJudgment domain maybeCred form =
    let
        decoder =
            Rest.itemDecoder Judgment.decoder

        body =
            toBody (encodeJudgment form)
    in
    case form.id of
        Just id ->
            Rest.patch (Endpoint.judgment domain id) maybeCred body UpdatedJudgment decoder

        Nothing ->
            Cmd.none


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
    "RDC | Admin | Judgments | Edit"


head :
    StaticPayload Data RouteParams
    -> List Head.Tag
head static =
    Seo.summary
        { canonicalUrlOverride = Nothing
        , siteName = "Red Door Collective"
        , image = Logo.smallImage
        , description = "Edit judgment details"
        , locale = Just "en-us"
        , title = title
        }
        |> Seo.website
