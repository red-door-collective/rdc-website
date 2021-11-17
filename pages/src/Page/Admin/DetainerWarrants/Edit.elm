module Page.Admin.DetainerWarrants.Edit exposing (Data, Model, Msg, page)

import Attorney exposing (Attorney, AttorneyForm)
import Browser.Dom
import Browser.Navigation as Nav
import Courtroom exposing (Courtroom)
import DataSource exposing (DataSource)
import Date exposing (Date)
import Date.Extra
import DatePicker exposing (ChangeEvent(..))
import Defendant exposing (Defendant)
import DetainerWarrant exposing (AmountClaimedCategory, DetainerWarrant, DetainerWarrantEdit, Status)
import Dict
import Element exposing (Element, centerX, column, el, fill, height, inFront, maximum, minimum, padding, paddingEach, paddingXY, paragraph, px, row, spacing, spacingXY, text, textColumn, width, wrappedRow)
import Element.Border as Border
import Element.Font as Font
import Element.Input as Input
import FeatherIcons
import Form.State exposing (DatePickerState)
import Head
import Head.Seo as Seo
import Html.Attributes exposing (selected)
import Http
import Json.Encode as Encode
import Judge exposing (Judge)
import Judgment exposing (ConditionOption(..), Conditions(..), DismissalBasis(..), Entrance(..), Interest(..), Judgment, JudgmentEdit, JudgmentForm)
import List.Extra as List
import Log
import Logo
import Mask
import Maybe.Extra
import Page exposing (StaticPayload)
import Pages.PageUrl exposing (PageUrl)
import Path exposing (Path)
import PhoneNumber
import PhoneNumber.Countries exposing (countryUS)
import Plaintiff exposing (Plaintiff, PlaintiffForm)
import QueryParams
import Rest exposing (Cred)
import Rest.Endpoint as Endpoint exposing (toQueryArgs)
import Rollbar exposing (Rollbar)
import Runtime
import SearchBox
import Session exposing (Session)
import Set
import Shared
import SplitButton
import Sprite
import Task
import Time
import Time.Utils
import UI.Button as Button
import UI.Checkbox as Checkbox
import UI.Dropdown as Dropdown
import UI.Effects as Effects
import UI.Icon as Icon
import UI.Palette as Palette
import UI.RenderConfig exposing (RenderConfig)
import UI.Size
import UI.TextField as TextField
import Url.Builder
import User exposing (NavigationOnSuccess(..), User)
import View exposing (View)


validUSNumber : String -> Bool
validUSNumber number =
    PhoneNumber.valid
        { defaultCountry = countryUS
        , otherCountries = []
        , types = PhoneNumber.anyType
        }
        number


type alias DefendantForm =
    { id : Maybe Int
    , firstName : String
    , middleName : String
    , lastName : String
    , suffix : String
    , potentialPhones : List String
    }


type alias FormOptions =
    { plaintiffs : List Plaintiff
    , attorneys : List Attorney
    , judges : List Judge
    , courtrooms : List Courtroom
    , showHelp : Bool
    , docketId : Maybe String
    , today : Date
    , problems : List Problem
    , originalWarrant : Maybe DetainerWarrant
    , renderConfig : RenderConfig
    , navigationOnSuccess : NavigationOnSuccess
    }


type alias Form =
    { docketId : String
    , fileDate : DatePickerState
    , status : Maybe Status
    , statusDropdown : Dropdown.State (Maybe Status)
    , plaintiff : PlaintiffForm
    , plaintiffAttorney : AttorneyForm
    , caresDropdown : Dropdown.State (Maybe Bool)
    , isCares : Maybe Bool
    , legacyDropdown : Dropdown.State (Maybe Bool)
    , isLegacy : Maybe Bool
    , nonpaymentDropdown : Dropdown.State (Maybe Bool)
    , isNonpayment : Maybe Bool
    , amountClaimed : String
    , amountClaimedCategory : AmountClaimedCategory
    , categoryDropdown : Dropdown.State AmountClaimedCategory
    , address : String
    , defendants : List DefendantForm
    , judgments : List JudgmentForm
    , notes : String
    , saveButtonState : SplitButton.State NavigationOnSuccess
    }


type Problem
    = InvalidEntry ValidatedField String
    | ServerError String


type JudgmentDetail
    = JudgmentFileDateDetail
    | Summary
    | FeesAwardedInfo
    | PossessionAwardedInfo
    | FeesHaveInterestInfo
    | InterestRateFollowsSiteInfo
    | InterestRateInfo
    | DismissalBasisInfo
    | WithPrejudiceInfo
    | JudgmentNotesDetail


type Tooltip
    = DocketIdInfo
    | FileDateInfo
    | StatusInfo
    | PlaintiffInfo
    | PlaintiffAttorneyInfo
    | CourtroomInfo
    | PresidingJudgeInfo
    | AmountClaimedInfo
    | AmountClaimedCategoryInfo
    | CaresInfo
    | LegacyInfo
    | NonpaymentInfo
    | AddressInfo
    | PotentialPhoneNumbersInfo Int
    | JudgmentInfo Int JudgmentDetail
    | NotesInfo


type SaveState
    = SavingRelatedModels { attorney : Bool, plaintiff : Bool, defendants : Int }
    | SavingWarrant
    | SavingJudgments { judgments : Int }
    | Done


type alias Model =
    { warrant : Maybe DetainerWarrant
    , cursor : Maybe String
    , profile : Maybe User
    , nextWarrant : Maybe DetainerWarrant
    , docketId : Maybe String
    , showHelp : Bool
    , problems : List Problem
    , form : FormStatus
    , plaintiffs : List Plaintiff
    , attorneys : List Attorney
    , judges : List Judge
    , courtrooms : List Courtroom
    , saveState : SaveState
    , navigationOnSuccess : NavigationOnSuccess
    }


initDatePicker : Maybe Date -> DatePickerState
initDatePicker date =
    { date = date
    , dateText = Maybe.withDefault "" <| Maybe.map Date.toIsoString date
    , pickerModel = DatePicker.init
    }


initPlaintiffForm : Maybe Plaintiff -> PlaintiffForm
initPlaintiffForm plaintiff =
    { person = plaintiff
    , text = Maybe.withDefault "" <| Maybe.map .name plaintiff
    , searchBox = SearchBox.init
    }


initAttorneyForm : Maybe Attorney -> AttorneyForm
initAttorneyForm attorney =
    { person = attorney
    , text = Maybe.withDefault "" <| Maybe.map .name attorney
    , searchBox = SearchBox.init
    }


initDefendantForm : Maybe Defendant -> DefendantForm
initDefendantForm defendant =
    { id = Maybe.map .id defendant
    , firstName = Maybe.withDefault "" <| Maybe.map .firstName defendant
    , middleName = Maybe.withDefault "" <| Maybe.andThen .middleName defendant
    , lastName = Maybe.withDefault "" <| Maybe.map .lastName defendant
    , suffix = Maybe.withDefault "" <| Maybe.andThen .suffix defendant
    , potentialPhones =
        defendant
            |> Maybe.andThen .potentialPhones
            |> Maybe.map (String.split ",")
            |> Maybe.withDefault [ "" ]
    }


editForm : Date -> DetainerWarrant -> Form
editForm today warrant =
    { docketId = warrant.docketId
    , fileDate =
        { date = Maybe.map Date.Extra.fromPosix warrant.fileDate
        , dateText = Maybe.withDefault (Date.toIsoString today) <| Maybe.map Time.Utils.toIsoString warrant.fileDate
        , pickerModel = DatePicker.init |> DatePicker.setToday today
        }
    , status = warrant.status
    , statusDropdown = Dropdown.init "status-dropdown"
    , plaintiff = initPlaintiffForm warrant.plaintiff
    , plaintiffAttorney = initAttorneyForm warrant.plaintiffAttorney
    , caresDropdown = Dropdown.init "cares-dropdown"
    , isCares = warrant.isCares
    , legacyDropdown = Dropdown.init "legacy-dropdown"
    , isLegacy = warrant.isLegacy
    , nonpaymentDropdown = Dropdown.init "nonpayment-dropdown"
    , isNonpayment = warrant.nonpayment
    , amountClaimed = Maybe.withDefault "" <| Maybe.map (Mask.floatDecimal Mask.defaultDecimalOptions) warrant.amountClaimed
    , amountClaimedCategory = warrant.amountClaimedCategory
    , categoryDropdown = Dropdown.init "amount-claimed-category-dropdown"
    , address = Maybe.withDefault "" <| List.head <| List.map .address warrant.defendants
    , defendants = List.map (initDefendantForm << Just) warrant.defendants
    , judgments = List.indexedMap (\index j -> judgmentFormInit today index (Just j)) warrant.judgments
    , notes = Maybe.withDefault "" warrant.notes
    , saveButtonState = SplitButton.init "save-button"
    }


judgmentFormInit : Date -> Int -> Maybe Judgment -> JudgmentForm
judgmentFormInit today index existing =
    let
        new =
            { id = Nothing
            , conditionsDropdown = Dropdown.init ("judgment-dropdown-new-" ++ String.fromInt index)
            , condition = Just PlaintiffOption
            , courtroom = Nothing
            , courtroomDropdown = Dropdown.init ("judgment-dropdown-courtroom-" ++ String.fromInt index)
            , notes = ""
            , courtDate = { date = Just today, dateText = Date.toIsoString today, pickerModel = DatePicker.init |> DatePicker.setToday today }
            , enteredBy = Default
            , awardsFees = ""
            , awardsPossession = False
            , hasInterest = False
            , interestRate = ""
            , interestFollowsSite = True
            , dismissalBasisDropdown = Dropdown.init ("judgment-dropdown-dismissal-basis-" ++ String.fromInt index)
            , dismissalBasis = FailureToProsecute
            , withPrejudice = False
            , plaintiff = { text = "", person = Nothing, searchBox = SearchBox.init }
            , plaintiffAttorney = { text = "", person = Nothing, searchBox = SearchBox.init }
            , judge = { text = "", person = Nothing, searchBox = SearchBox.init }
            }
    in
    case existing of
        Just judgment ->
            let
                default =
                    { new
                        | id = Just judgment.id
                        , enteredBy = judgment.enteredBy
                        , courtDate =
                            { date = Maybe.map Date.Extra.fromPosix judgment.courtDate
                            , dateText = Maybe.withDefault new.courtDate.dateText <| Maybe.map Time.Utils.toIsoString judgment.courtDate
                            , pickerModel = DatePicker.init |> DatePicker.setToday today
                            }
                        , courtroom = judgment.courtroom
                        , courtroomDropdown = Dropdown.init ("judgment-dropdown-courtroom-" ++ String.fromInt judgment.id)
                        , conditionsDropdown = Dropdown.init ("judgment-dropdown-" ++ String.fromInt judgment.id)
                        , dismissalBasisDropdown = Dropdown.init ("judgment-dropdown-dismissal-basis-" ++ String.fromInt judgment.id)
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
                        , awardsPossession = owed.awardsPossession
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

        Nothing ->
            new


initCreate : Date -> Form
initCreate today =
    { docketId = ""
    , fileDate = { date = Just today, dateText = Date.toIsoString today, pickerModel = DatePicker.init |> DatePicker.setToday today }
    , status = Nothing
    , statusDropdown = Dropdown.init "status-dropdown"
    , plaintiff = initPlaintiffForm Nothing
    , plaintiffAttorney = initAttorneyForm Nothing
    , caresDropdown = Dropdown.init "cares-dropdown"
    , isCares = Nothing
    , legacyDropdown = Dropdown.init "legacy-dropdown"
    , isLegacy = Nothing
    , nonpaymentDropdown = Dropdown.init "nonpayment-dropdown"
    , isNonpayment = Nothing
    , amountClaimed = ""
    , amountClaimedCategory = DetainerWarrant.NotApplicable
    , categoryDropdown = Dropdown.init "amount-claimed-category-dropdown"
    , address = ""
    , defendants = [ initDefendantForm Nothing ]
    , judgments = []
    , notes = ""
    , saveButtonState = SplitButton.init "save-button"
    }


type FormStatus
    = Initializing String
    | Ready Form


init :
    Maybe PageUrl
    -> Shared.Model
    -> StaticPayload Data RouteParams
    -> ( Model, Cmd Msg )
init pageUrl sharedModel static =
    let
        today =
            static.sharedData.runtime.today

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
      , profile = Nothing
      , nextWarrant = Nothing
      , docketId = docketId
      , showHelp = False
      , problems = []
      , form =
            case docketId of
                Just id ->
                    Initializing id

                Nothing ->
                    Ready <| initCreate today
      , plaintiffs = []
      , attorneys = []
      , judges = []
      , courtrooms = []
      , saveState = Done
      , navigationOnSuccess = Remain
      }
    , Cmd.batch
        [ case docketId of
            Just id ->
                getWarrant domain id maybeCred

            _ ->
                Cmd.none
        , Rest.get (Endpoint.courtrooms domain []) maybeCred GotCourtrooms (Rest.collectionDecoder Courtroom.decoder)
        , Rest.get (Endpoint.currentUser domain) maybeCred GotProfile User.decoder
        ]
    )


getWarrant : String -> String -> Maybe Cred -> Cmd Msg
getWarrant domain id maybeCred =
    Rest.get (Endpoint.detainerWarrant domain id) maybeCred GotDetainerWarrant (Rest.itemDecoder DetainerWarrant.decoder)


type Msg
    = GotDetainerWarrant (Result Http.Error (Rest.Item DetainerWarrant))
    | GotDetainerWarrants (Result Http.Error (Rest.Collection DetainerWarrant))
    | ToggleHelp
    | ChangedDocketId String
    | ChangedFileDatePicker ChangeEvent
    | ChangedPlaintiffSearchBox (SearchBox.ChangeEvent Plaintiff)
    | ChangedPlaintiffAttorneySearchBox (SearchBox.ChangeEvent Attorney)
    | PickedStatus (Maybe (Maybe Status))
    | StatusDropdownMsg (Dropdown.Msg (Maybe Status))
    | ChangedAmountClaimed String
    | ConfirmAmountClaimed
    | PickedAmountClaimedCategory (Maybe AmountClaimedCategory)
    | CategoryDropdownMsg (Dropdown.Msg AmountClaimedCategory)
    | CaresDropdownMsg (Dropdown.Msg (Maybe Bool))
    | PickedCares (Maybe (Maybe Bool))
    | LegacyDropdownMsg (Dropdown.Msg (Maybe Bool))
    | PickedLegacy (Maybe (Maybe Bool))
    | NonpaymentDropdownMsg (Dropdown.Msg (Maybe Bool))
    | PickedNonpayment (Maybe (Maybe Bool))
    | ChangedAddress String
    | ChangedFirstName Int String
    | ChangedMiddleName Int String
    | ChangedLastName Int String
    | ChangedSuffix Int String
    | ChangedPotentialPhones Int Int String
    | AddPhone Int
    | RemovePhone Int Int
    | AddDefendant
    | AddJudgment
    | RemoveJudgment Int
    | ChangedJudgmentCourtDatePicker Int ChangeEvent
    | PickedCourtroom Int (Maybe (Maybe Courtroom))
    | CourtroomDropdownMsg Int (Dropdown.Msg (Maybe Courtroom))
    | PickedConditions Int (Maybe (Maybe ConditionOption))
    | ConditionsDropdownMsg Int (Dropdown.Msg (Maybe ConditionOption))
    | ChangedFeesAwarded Int String
    | ConfirmedFeesAwarded Int
    | ToggleJudgmentPossession Int Bool
    | ToggleJudgmentInterest Int Bool
    | ChangedInterestRate Int String
    | ConfirmedInterestRate Int
    | ToggleInterestFollowSite Int Bool
    | DismissalBasisDropdownMsg Int (Dropdown.Msg DismissalBasis)
    | PickedDismissalBasis Int (Maybe DismissalBasis)
    | ToggledWithPrejudice Int Bool
    | ChangedJudgmentPlaintiffSearchBox Int (SearchBox.ChangeEvent Plaintiff)
    | ChangedJudgmentAttorneySearchBox Int (SearchBox.ChangeEvent Attorney)
    | ChangedJudgmentJudgeSearchBox Int (SearchBox.ChangeEvent Judge)
    | ChangedJudgmentNotes Int String
    | ChangedNotes String
    | SplitButtonMsg (SplitButton.Msg NavigationOnSuccess)
    | PickedSaveOption (Maybe NavigationOnSuccess)
    | GotProfile (Result Http.Error User)
    | Save
    | UpsertedPlaintiff (Result Http.Error (Rest.Item Plaintiff))
    | UpsertedAttorney (Result Http.Error (Rest.Item Attorney))
    | UpsertedDefendant Int (Result Http.Error (Rest.Item Defendant))
    | UpsertedJudgment Int (Result Http.Error (Rest.Item Judgment))
    | DeletedJudgment Int (Result Http.Error ())
    | CreatedDetainerWarrant (Result Http.Error (Rest.Item DetainerWarrant))
    | GotPlaintiffs (Result Http.Error (Rest.Collection Plaintiff))
    | GotAttorneys (Result Http.Error (Rest.Collection Attorney))
    | GotJudges (Result Http.Error (Rest.Collection Attorney))
    | GotCourtrooms (Result Http.Error (Rest.Collection Courtroom))
    | NoOp


updateForm : (Form -> Form) -> Model -> ( Model, Cmd Msg )
updateForm transform model =
    ( { model
        | form =
            case model.form of
                Initializing _ ->
                    model.form

                Ready oldForm ->
                    Ready (transform oldForm)
      }
    , Cmd.none
    )


updateFormOnly : (Form -> Form) -> Model -> Model
updateFormOnly transform model =
    { model
        | form =
            case model.form of
                Initializing _ ->
                    model.form

                Ready oldForm ->
                    Ready (transform oldForm)
    }


updateFormNarrow : (Form -> ( Form, Cmd Msg )) -> Model -> ( Model, Cmd Msg )
updateFormNarrow transform model =
    let
        ( newForm, cmd ) =
            case model.form of
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


savingError : Http.Error -> Model -> Model
savingError httpError model =
    let
        problems =
            [ ServerError "Error saving detainer warrant" ]
    in
    { model | problems = problems }


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

        cfg =
            sharedModel.renderConfig

        session =
            sharedModel.session

        maybeCred =
            Session.cred session

        rollbar =
            Log.reporting static.sharedData.runtime

        domain =
            Runtime.domain static.sharedData.runtime.environment

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
                        , form = Ready (editForm today warrantPage.data)
                      }
                    , Cmd.none
                    )

                Err httpError ->
                    ( model, logHttpError httpError )

        GotDetainerWarrants result ->
            case result of
                Ok warrantPage ->
                    ( { model
                        | nextWarrant = List.head warrantPage.data
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

        ChangedDocketId id ->
            updateForm (\form -> { form | docketId = id }) model

        ChangedFileDatePicker changeEvent ->
            case changeEvent of
                DateChanged date ->
                    updateForm
                        (\form ->
                            let
                                fileDate =
                                    form.fileDate

                                updatedFileDate =
                                    { fileDate | date = Just date, dateText = Date.toIsoString date }
                            in
                            { form | fileDate = updatedFileDate }
                        )
                        model

                TextChanged text ->
                    updateForm
                        (\form ->
                            let
                                fileDate =
                                    form.fileDate

                                updatedFileDate =
                                    { fileDate
                                        | date =
                                            Date.fromIsoString text
                                                |> Result.toMaybe
                                                |> Maybe.Extra.orElse fileDate.date
                                        , dateText = text
                                    }
                            in
                            { form | fileDate = updatedFileDate }
                        )
                        model

                PickerChanged subMsg ->
                    updateForm
                        (\form ->
                            let
                                fileDate =
                                    form.fileDate

                                updatedFileDate =
                                    { fileDate | pickerModel = fileDate.pickerModel |> DatePicker.update subMsg }
                            in
                            { form | fileDate = updatedFileDate }
                        )
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
                                    { plaintiff | person = Just person, text = person.name }
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

        ChangedPlaintiffAttorneySearchBox changeEvent ->
            case changeEvent of
                SearchBox.SelectionChanged person ->
                    updateForm
                        (\form ->
                            let
                                attorney =
                                    form.plaintiffAttorney

                                updatedAttorney =
                                    { attorney | person = Just person, text = person.name }
                            in
                            { form | plaintiffAttorney = updatedAttorney }
                        )
                        model

                SearchBox.TextChanged text ->
                    ( updateFormOnly
                        (\form ->
                            let
                                attorney =
                                    form.plaintiffAttorney

                                updatedAttorney =
                                    { attorney
                                        | person = Nothing
                                        , text = text
                                        , searchBox = SearchBox.reset attorney.searchBox
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
                                attorney =
                                    form.plaintiffAttorney

                                updatedAttorney =
                                    { attorney
                                        | searchBox = SearchBox.update subMsg attorney.searchBox
                                    }
                            in
                            { form | plaintiffAttorney = updatedAttorney }
                        )
                        model

        PickedStatus option ->
            updateForm
                (\form ->
                    { form
                        | status = Maybe.andThen identity option
                    }
                )
                model

        StatusDropdownMsg subMsg ->
            updateFormNarrow
                (\form ->
                    let
                        ( newState, newCmd ) =
                            Dropdown.update cfg subMsg (statusDropdown form)
                    in
                    ( { form | statusDropdown = newState }, Effects.perform newCmd )
                )
                model

        ChangedAmountClaimed money ->
            updateForm (\form -> { form | amountClaimed = String.replace "$" "" money }) model

        ConfirmAmountClaimed ->
            let
                extract money =
                    String.toFloat (String.replace "," "" money)

                options =
                    Mask.defaultDecimalOptions
            in
            updateForm
                (\form ->
                    { form
                        | amountClaimed =
                            case extract form.amountClaimed of
                                Just moneyFloat ->
                                    Mask.floatDecimal options moneyFloat

                                Nothing ->
                                    form.amountClaimed
                    }
                )
                model

        PickedAmountClaimedCategory option ->
            updateForm
                (\form ->
                    { form
                        | amountClaimedCategory = Maybe.withDefault DetainerWarrant.NotApplicable option
                    }
                )
                model

        CategoryDropdownMsg subMsg ->
            updateFormNarrow
                (\form ->
                    let
                        ( newState, newCmd ) =
                            Dropdown.update cfg subMsg (amountClaimedDropdown form)
                    in
                    ( { form | categoryDropdown = newState }, Effects.perform newCmd )
                )
                model

        CaresDropdownMsg subMsg ->
            updateFormNarrow
                (\form ->
                    let
                        ( newState, newCmd ) =
                            Dropdown.update cfg subMsg (caresDropdown form)
                    in
                    ( { form | caresDropdown = newState }, Effects.perform newCmd )
                )
                model

        PickedCares isCares ->
            updateForm
                (\form -> { form | isCares = Maybe.andThen identity isCares })
                model

        LegacyDropdownMsg subMsg ->
            updateFormNarrow
                (\form ->
                    let
                        ( newState, newCmd ) =
                            Dropdown.update cfg subMsg (legacyDropdown form)
                    in
                    ( { form | legacyDropdown = newState }, Effects.perform newCmd )
                )
                model

        PickedLegacy isLegacy ->
            updateForm
                (\form -> { form | isLegacy = Maybe.andThen identity isLegacy })
                model

        NonpaymentDropdownMsg subMsg ->
            updateFormNarrow
                (\form ->
                    let
                        ( newState, newCmd ) =
                            Dropdown.update cfg subMsg (nonpaymentDropdown form)
                    in
                    ( { form | nonpaymentDropdown = newState }, Effects.perform newCmd )
                )
                model

        PickedNonpayment isNonpayment ->
            updateForm
                (\form -> { form | isNonpayment = Maybe.andThen identity isNonpayment })
                model

        ChangedAddress address ->
            updateForm
                (\form -> { form | address = address })
                model

        AddJudgment ->
            updateFormNarrow
                (\form ->
                    let
                        nextJudgmentId =
                            List.length form.judgments
                    in
                    ( { form
                        | judgments = form.judgments ++ [ judgmentFormInit today nextJudgmentId Nothing ]
                      }
                    , Task.attempt
                        (always NoOp)
                        (Browser.Dom.focus (judgmentInfoText nextJudgmentId JudgmentFileDateDetail))
                    )
                )
                model

        RemoveJudgment selected ->
            updateForm (\form -> { form | judgments = List.removeAt selected form.judgments }) model

        ChangedJudgmentCourtDatePicker selected changeEvent ->
            case changeEvent of
                DateChanged date ->
                    updateForm
                        (updateJudgment selected
                            (\judgment ->
                                let
                                    courtDate =
                                        judgment.courtDate

                                    updatedCourtDate =
                                        { courtDate | date = Just date, dateText = Date.toIsoString date }
                                in
                                { judgment | courtDate = updatedCourtDate }
                            )
                        )
                        model

                TextChanged text ->
                    updateForm
                        (updateJudgment selected
                            (\judgment ->
                                let
                                    courtDate =
                                        judgment.courtDate

                                    updatedCourtDate =
                                        { courtDate
                                            | date =
                                                Date.fromIsoString text
                                                    |> Result.toMaybe
                                                    |> Maybe.Extra.orElse courtDate.date
                                            , dateText = text
                                        }
                                in
                                { judgment | courtDate = updatedCourtDate }
                            )
                        )
                        model

                PickerChanged subMsg ->
                    updateForm
                        (updateJudgment selected
                            (\judgment ->
                                let
                                    courtDate =
                                        judgment.courtDate

                                    updatedCourtDate =
                                        { courtDate
                                            | pickerModel =
                                                courtDate.pickerModel |> DatePicker.update subMsg
                                        }
                                in
                                { judgment | courtDate = updatedCourtDate }
                            )
                        )
                        model

        PickedCourtroom selected option ->
            updateForm
                (updateJudgment selected (\judgment -> { judgment | courtroom = Maybe.andThen identity option }))
                model

        CourtroomDropdownMsg selected subMsg ->
            updateFormNarrow
                (\form ->
                    let
                        judgmentsAndCmds =
                            List.indexedMap
                                (\candidate judgment ->
                                    if selected == candidate then
                                        let
                                            ( newState, newCmd ) =
                                                Dropdown.update cfg subMsg (courtroomDropdown model.courtrooms selected judgment)
                                        in
                                        ( { judgment | courtroomDropdown = newState }, Effects.perform newCmd )

                                    else
                                        ( judgment, Cmd.none )
                                )
                                form.judgments
                    in
                    ( { form | judgments = List.map Tuple.first judgmentsAndCmds }
                    , Cmd.batch (List.map Tuple.second judgmentsAndCmds)
                    )
                )
                model

        PickedConditions selected option ->
            updateForm
                (updateJudgment selected (\judgment -> { judgment | condition = Maybe.andThen identity option }))
                model

        DismissalBasisDropdownMsg selected subMsg ->
            updateFormNarrow
                (\form ->
                    let
                        judgmentsAndCmds =
                            List.indexedMap
                                (\candidate judgment ->
                                    if selected == candidate then
                                        let
                                            ( newState, newCmd ) =
                                                Dropdown.update cfg subMsg (dismissalBasisDropdown selected judgment)
                                        in
                                        ( { judgment | dismissalBasisDropdown = newState }, Effects.perform newCmd )

                                    else
                                        ( judgment, Cmd.none )
                                )
                                form.judgments
                    in
                    ( { form | judgments = List.map Tuple.first judgmentsAndCmds }
                    , Cmd.batch (List.map Tuple.second judgmentsAndCmds)
                    )
                )
                model

        PickedDismissalBasis selected option ->
            updateForm
                (updateJudgment selected (\judgment -> { judgment | dismissalBasis = Maybe.withDefault FailureToProsecute option }))
                model

        ToggledWithPrejudice selected checked ->
            updateForm
                (updateJudgment selected (\judgment -> { judgment | withPrejudice = checked }))
                model

        ChangedFirstName selected name ->
            updateForm
                (\form ->
                    { form
                        | defendants =
                            List.indexedMap
                                (\index defendant ->
                                    if index == selected then
                                        { defendant | firstName = name }

                                    else
                                        defendant
                                )
                                form.defendants
                    }
                )
                model

        ChangedMiddleName selected name ->
            updateForm
                (\form ->
                    { form
                        | defendants =
                            List.indexedMap
                                (\index defendant ->
                                    if index == selected then
                                        { defendant | middleName = name }

                                    else
                                        defendant
                                )
                                form.defendants
                    }
                )
                model

        ChangedLastName selected name ->
            updateForm
                (\form ->
                    { form
                        | defendants =
                            List.indexedMap
                                (\index defendant ->
                                    if index == selected then
                                        { defendant | lastName = name }

                                    else
                                        defendant
                                )
                                form.defendants
                    }
                )
                model

        ChangedSuffix selected suffix ->
            updateForm
                (\form ->
                    { form
                        | defendants =
                            List.indexedMap
                                (\index defendant ->
                                    if index == selected then
                                        { defendant | suffix = suffix }

                                    else
                                        defendant
                                )
                                form.defendants
                    }
                )
                model

        ChangedPotentialPhones selected phoneIndex phone ->
            updateForm
                (\form ->
                    { form
                        | defendants =
                            List.indexedMap
                                (\index defendant ->
                                    if index == selected then
                                        { defendant
                                            | potentialPhones =
                                                List.indexedMap
                                                    (\i p ->
                                                        if i == phoneIndex then
                                                            Mask.number "###-###-####" phone

                                                        else
                                                            p
                                                    )
                                                    defendant.potentialPhones
                                        }

                                    else
                                        defendant
                                )
                                form.defendants
                    }
                )
                model

        AddDefendant ->
            updateForm
                (\form -> { form | defendants = form.defendants ++ [ initDefendantForm Nothing ] })
                model

        AddPhone defendantIndex ->
            updateForm
                (\form ->
                    { form
                        | defendants =
                            List.indexedMap
                                (\index def ->
                                    if index == defendantIndex then
                                        { def | potentialPhones = def.potentialPhones ++ [ "" ] }

                                    else
                                        def
                                )
                                form.defendants
                    }
                )
                model

        RemovePhone defendantIndex phoneIndex ->
            updateForm
                (\form ->
                    { form
                        | defendants =
                            List.indexedMap
                                (\index def ->
                                    if index == defendantIndex then
                                        { def | potentialPhones = List.removeAt phoneIndex def.potentialPhones }

                                    else
                                        def
                                )
                                form.defendants
                    }
                )
                model

        ConditionsDropdownMsg selected subMsg ->
            updateFormNarrow
                (\form ->
                    let
                        judgmentsAndCmds =
                            List.indexedMap
                                (\candidate judgment ->
                                    if selected == candidate then
                                        let
                                            ( newState, newCmd ) =
                                                Dropdown.update cfg subMsg (conditionsDropdown selected judgment)
                                        in
                                        ( { judgment | conditionsDropdown = newState }, Effects.perform newCmd )

                                    else
                                        ( judgment, Cmd.none )
                                )
                                form.judgments
                    in
                    ( { form | judgments = List.map Tuple.first judgmentsAndCmds }
                    , Cmd.batch (List.map Tuple.second judgmentsAndCmds)
                    )
                )
                model

        ChangedFeesAwarded selected money ->
            updateForm
                (updateJudgment selected (\judgment -> { judgment | awardsFees = String.replace "$" "" money }))
                model

        ConfirmedFeesAwarded selected ->
            let
                extract money =
                    String.toFloat (String.replace "," "" money)

                options =
                    Mask.defaultDecimalOptions
            in
            updateForm
                (updateJudgment selected
                    (\judgment ->
                        { judgment
                            | awardsFees =
                                case extract judgment.awardsFees of
                                    Just moneyFloat ->
                                        Mask.floatDecimal options moneyFloat

                                    Nothing ->
                                        judgment.awardsFees
                        }
                    )
                )
                model

        ToggleJudgmentPossession selected checked ->
            updateForm
                (updateJudgment selected (\judgment -> { judgment | awardsPossession = checked }))
                model

        ToggleJudgmentInterest selected checked ->
            updateForm
                (updateJudgment selected (\judgment -> { judgment | hasInterest = checked }))
                model

        ChangedInterestRate selected interestRate ->
            updateForm
                (updateJudgment selected (\judgment -> { judgment | interestRate = String.replace "%" "" interestRate }))
                model

        ConfirmedInterestRate selected ->
            updateForm
                (updateJudgment selected (\judgment -> { judgment | interestRate = String.replace "%" "" judgment.interestRate ++ "%" }))
                model

        ToggleInterestFollowSite selected checked ->
            updateForm
                (updateJudgment selected (\judgment -> { judgment | interestFollowsSite = checked }))
                model

        ChangedJudgmentPlaintiffSearchBox selected changeEvent ->
            case changeEvent of
                SearchBox.SelectionChanged person ->
                    updateForm
                        (updateJudgment selected
                            (\form ->
                                let
                                    plaintiff =
                                        form.plaintiff

                                    updatedPlaintiff =
                                        { plaintiff | person = Just person }
                                in
                                { form | plaintiff = updatedPlaintiff }
                            )
                        )
                        model

                SearchBox.TextChanged text ->
                    ( updateFormOnly
                        (updateJudgment selected
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
                        )
                        model
                    , Rest.get (Endpoint.plaintiffs domain [ ( "free_text", text ) ]) maybeCred GotPlaintiffs (Rest.collectionDecoder Plaintiff.decoder)
                    )

                SearchBox.SearchBoxChanged subMsg ->
                    updateForm
                        (updateJudgment selected
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
                        )
                        model

        ChangedJudgmentAttorneySearchBox selected changeEvent ->
            case changeEvent of
                SearchBox.SelectionChanged person ->
                    updateForm
                        (updateJudgment selected
                            (\form ->
                                let
                                    plaintiffAttorney =
                                        form.plaintiffAttorney

                                    updatedPlaintiff =
                                        { plaintiffAttorney | person = Just person }
                                in
                                { form | plaintiffAttorney = updatedPlaintiff }
                            )
                        )
                        model

                SearchBox.TextChanged text ->
                    ( updateFormOnly
                        (updateJudgment selected
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
                        )
                        model
                    , Rest.get (Endpoint.attorneys domain [ ( "free_text", text ) ]) maybeCred GotAttorneys (Rest.collectionDecoder Attorney.decoder)
                    )

                SearchBox.SearchBoxChanged subMsg ->
                    updateForm
                        (updateJudgment selected
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
                        )
                        model

        ChangedJudgmentJudgeSearchBox selected changeEvent ->
            case changeEvent of
                SearchBox.SelectionChanged person ->
                    updateForm
                        (updateJudgment selected
                            (\form ->
                                let
                                    judge =
                                        form.judge

                                    updatedJudge =
                                        { judge | person = Just person }
                                in
                                { form | judge = updatedJudge }
                            )
                        )
                        model

                SearchBox.TextChanged text ->
                    ( updateFormOnly
                        (updateJudgment selected
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
                        )
                        model
                    , Rest.get (Endpoint.judges domain [ ( "free_text", text ) ]) maybeCred GotJudges (Rest.collectionDecoder Judge.decoder)
                    )

                SearchBox.SearchBoxChanged subMsg ->
                    updateForm
                        (updateJudgment selected
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
                        )
                        model

        ChangedJudgmentNotes selected notes ->
            updateForm
                (updateJudgment selected (\judgment -> { judgment | notes = notes }))
                model

        ChangedNotes notes ->
            updateForm
                (\form -> { form | notes = notes })
                model

        SplitButtonMsg subMsg ->
            updateFormNarrow
                (\form ->
                    let
                        ( newState, newCmd ) =
                            SplitButton.update (saveConfig cfg) subMsg form.saveButtonState
                    in
                    ( { form | saveButtonState = newState }, newCmd )
                )
                model

        PickedSaveOption option ->
            ( { model | navigationOnSuccess = Maybe.withDefault model.navigationOnSuccess option }
            , case ( model.profile, option ) of
                ( Just user, Just nav ) ->
                    let
                        body =
                            toBody
                                (Encode.object
                                    [ ( "id", Encode.int user.id )
                                    , ( "preferred_navigation"
                                      , Encode.string <| User.navigationToText nav
                                      )
                                    ]
                                )
                    in
                    Rest.patch (Endpoint.user domain user.id) maybeCred body GotProfile User.decoder

                ( _, _ ) ->
                    Cmd.none
            )

        GotProfile (Ok user) ->
            ( { model
                | profile = Just user
                , navigationOnSuccess = user.preferredNavigation
              }
            , Cmd.none
            )

        GotProfile (Err httpError) ->
            ( model, Cmd.none )

        Save ->
            submitForm today domain session model

        UpsertedPlaintiff (Ok plaintiffItem) ->
            nextStepSave
                today
                domain
                session
                (updateFormOnly
                    (\form -> { form | plaintiff = initPlaintiffForm (Just plaintiffItem.data) })
                    { model
                        | saveState =
                            case model.saveState of
                                SavingRelatedModels models ->
                                    SavingRelatedModels { models | plaintiff = True }

                                _ ->
                                    model.saveState
                    }
                )

        UpsertedPlaintiff (Err httpError) ->
            ( model, logHttpError httpError )

        UpsertedDefendant index (Ok defendant) ->
            nextStepSave
                today
                domain
                session
                (updateFormOnly
                    (\form ->
                        { form
                            | defendants =
                                List.indexedMap
                                    (\i def ->
                                        if i == index then
                                            initDefendantForm (Just defendant.data)

                                        else
                                            def
                                    )
                                    form.defendants
                        }
                    )
                    { model
                        | saveState =
                            case model.saveState of
                                SavingRelatedModels models ->
                                    SavingRelatedModels { models | defendants = models.defendants + 1 }

                                _ ->
                                    model.saveState
                    }
                )

        UpsertedDefendant _ (Err httpError) ->
            ( model, logHttpError httpError )

        UpsertedJudgment index (Ok judgment) ->
            nextStepSave
                today
                domain
                session
                (updateFormOnly
                    (\form ->
                        { form
                            | judgments =
                                List.indexedMap
                                    (\i def ->
                                        if i == index then
                                            judgmentFormInit today index (Just judgment.data)

                                        else
                                            def
                                    )
                                    form.judgments
                        }
                    )
                    { model
                        | saveState =
                            case model.saveState of
                                SavingJudgments models ->
                                    SavingJudgments { models | judgments = models.judgments + 1 }

                                _ ->
                                    model.saveState
                    }
                )

        UpsertedJudgment _ (Err httpError) ->
            ( model, logHttpError httpError )

        DeletedJudgment _ (Ok _) ->
            nextStepSave today domain session model

        DeletedJudgment _ (Err httpError) ->
            ( model, logHttpError httpError )

        UpsertedAttorney (Ok attorney) ->
            nextStepSave
                today
                domain
                session
                (updateFormOnly
                    (\form -> { form | plaintiffAttorney = initAttorneyForm (Just attorney.data) })
                    { model
                        | saveState =
                            case model.saveState of
                                SavingRelatedModels models ->
                                    SavingRelatedModels { models | attorney = True }

                                _ ->
                                    model.saveState
                    }
                )

        UpsertedAttorney (Err httpError) ->
            ( model, logHttpError httpError )

        CreatedDetainerWarrant (Ok detainerWarrantItem) ->
            nextStepSave
                today
                domain
                session
                { model
                    | warrant = Just detainerWarrantItem.data
                    , cursor = Just detainerWarrantItem.meta.cursor
                }

        CreatedDetainerWarrant (Err httpError) ->
            ( savingError httpError model, logHttpError httpError )

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

        GotCourtrooms (Ok courtroomsPage) ->
            ( { model | courtrooms = courtroomsPage.data }, Cmd.none )

        GotCourtrooms (Err httpError) ->
            ( model, logHttpError httpError )

        NoOp ->
            ( model, Cmd.none )


error : Rollbar -> String -> Cmd Msg
error rollbar report =
    Log.error rollbar (\_ -> NoOp) report


updateJudgment : Int -> (JudgmentForm -> JudgmentForm) -> Form -> Form
updateJudgment selected fn form =
    { form
        | judgments =
            List.indexedMap
                (\index judgment ->
                    if selected == index then
                        fn judgment

                    else
                        judgment
                )
                form.judgments
    }


fetchAdjacentDetainerWarrant : String -> Maybe Cred -> Model -> Cmd Msg
fetchAdjacentDetainerWarrant domain maybeCred model =
    let
        cursor =
            ( "cursor", Maybe.withDefault "" model.cursor )

        limit =
            ( "limit", "1" )
    in
    case model.navigationOnSuccess of
        Remain ->
            Cmd.none

        NewWarrant ->
            Cmd.none

        NextWarrant ->
            Rest.get (Endpoint.detainerWarrantsSearch domain [ limit, cursor ]) maybeCred GotDetainerWarrants (Rest.collectionDecoder DetainerWarrant.decoder)

        PreviousWarrant ->
            Rest.get (Endpoint.detainerWarrantsSearch domain [ limit, cursor, ( "sort", "order_number" ) ]) maybeCred GotDetainerWarrants (Rest.collectionDecoder DetainerWarrant.decoder)


doneSavingRelatedModels : ApiForms -> SaveState -> Bool
doneSavingRelatedModels apiForms state =
    case state of
        SavingRelatedModels models ->
            models.attorney
                && models.plaintiff
                && List.length apiForms.defendants
                >= models.defendants

        _ ->
            False


submitForm : Date -> String -> Session -> Model -> ( Model, Cmd Msg )
submitForm today domain session model =
    let
        maybeCred =
            Session.cred session
    in
    case validate today model.form of
        Ok validForm ->
            let
                apiForms =
                    toDetainerWarrant today validForm

                savingRelatedModels =
                    SavingRelatedModels
                        { attorney = apiForms.attorney == Nothing
                        , plaintiff = apiForms.plaintiff == Nothing
                        , defendants = 0
                        }

                updatedModel =
                    { model
                        | problems = []
                        , saveState = savingRelatedModels
                    }
            in
            if doneSavingRelatedModels apiForms savingRelatedModels then
                nextStepSave today domain session updatedModel

            else
                ( updatedModel
                , Cmd.batch
                    (List.concat
                        [ apiForms.attorney
                            |> Maybe.map (List.singleton << upsertAttorney domain maybeCred)
                            |> Maybe.withDefault []
                        , Maybe.withDefault [] <| Maybe.map (List.singleton << upsertPlaintiff domain maybeCred) apiForms.plaintiff
                        , List.indexedMap (upsertDefendant domain maybeCred) apiForms.defendants
                        , List.singleton <| fetchAdjacentDetainerWarrant domain maybeCred model
                        ]
                    )
                )

        Err problems ->
            ( { model | problems = problems }
            , Cmd.none
            )


nextStepSave : Date -> String -> Session -> Model -> ( Model, Cmd Msg )
nextStepSave today domain session model =
    let
        maybeCred =
            Session.cred session
    in
    case validate today model.form of
        Ok form ->
            let
                apiForms =
                    toDetainerWarrant today form
            in
            case model.saveState of
                SavingRelatedModels models ->
                    if doneSavingRelatedModels apiForms model.saveState then
                        ( { model | saveState = SavingWarrant }
                        , updateDetainerWarrant domain maybeCred apiForms.detainerWarrant
                        )

                    else
                        ( model, Cmd.none )

                SavingWarrant ->
                    let
                        toDelete =
                            case model.warrant of
                                Just warrant ->
                                    if List.length warrant.judgments /= List.length apiForms.judgments then
                                        Set.toList (Set.diff (Set.fromList (List.map .id warrant.judgments)) (Set.fromList (List.filterMap .id apiForms.judgments)))

                                    else
                                        []

                                Nothing ->
                                    []
                    in
                    if List.isEmpty apiForms.judgments && List.isEmpty toDelete then
                        nextStepSave today domain session { model | saveState = Done }

                    else
                        ( { model | saveState = SavingJudgments { judgments = 0 } }
                        , Cmd.batch
                            (List.concat
                                [ List.indexedMap (upsertJudgment domain maybeCred apiForms.detainerWarrant) apiForms.judgments
                                , List.indexedMap (deleteJudgment domain maybeCred) toDelete
                                ]
                            )
                        )

                SavingJudgments models ->
                    if models.judgments >= List.length apiForms.judgments then
                        nextStepSave today domain session { model | saveState = Done }

                    else
                        ( model, Cmd.none )

                Done ->
                    let
                        currentPath =
                            [ "admin", "detainer-warrants", "edit" ]
                    in
                    ( model
                    , Cmd.batch
                        (Rest.get (Endpoint.currentUser domain) maybeCred GotProfile User.decoder
                            :: (case model.navigationOnSuccess of
                                    Remain ->
                                        [ Maybe.withDefault Cmd.none <|
                                            Maybe.map (\key -> Nav.replaceUrl key (Url.Builder.absolute currentPath (toQueryArgs [ ( "docket-id", apiForms.detainerWarrant.docketId ) ]))) (Session.navKey session)
                                        ]

                                    NewWarrant ->
                                        [ Maybe.withDefault Cmd.none <|
                                            Maybe.map (\key -> Nav.replaceUrl key (Url.Builder.absolute currentPath [])) (Session.navKey session)
                                        ]

                                    PreviousWarrant ->
                                        [ Maybe.withDefault Cmd.none <|
                                            Maybe.map (\key -> Nav.replaceUrl key (Url.Builder.absolute currentPath (toQueryArgs [ ( "docket-id", Maybe.withDefault "" <| Maybe.map .docketId model.nextWarrant ) ]))) (Session.navKey session)
                                        , Maybe.withDefault Cmd.none <| Maybe.map (\warrant -> getWarrant domain warrant.docketId maybeCred) model.nextWarrant
                                        ]

                                    NextWarrant ->
                                        [ Maybe.withDefault Cmd.none <|
                                            Maybe.map (\key -> Nav.replaceUrl key (Url.Builder.absolute currentPath (toQueryArgs [ ( "docket-id", Maybe.withDefault "" <| Maybe.map .docketId model.nextWarrant ) ]))) (Session.navKey session)
                                        , Maybe.withDefault Cmd.none <| Maybe.map (\warrant -> getWarrant domain warrant.docketId maybeCred) model.nextWarrant
                                        ]
                               )
                        )
                    )

        Err _ ->
            ( model, Cmd.none )


type alias Field =
    { tooltip : Maybe Tooltip
    , description : String
    , children : List (Element Msg)
    }


requiredStar =
    el [ Palette.toFontColor Palette.red, Element.alignTop, width Element.shrink ] (text "*")


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


withChanges hasChanged attrs =
    attrs
        ++ (if hasChanged then
                [ Palette.toBorderColor Palette.yellow300 ]

            else
                []
           )


withValidation : ValidatedField -> List Problem -> List (Element.Attr () msg) -> List (Element.Attr () msg)
withValidation validatedField problems attrs =
    let
        maybeError =
            problems
                |> List.filterMap
                    (\problem ->
                        case problem of
                            InvalidEntry field problemText ->
                                if validatedField == field then
                                    Just problemText

                                else
                                    Nothing

                            ServerError _ ->
                                Nothing
                    )
                |> List.head
    in
    attrs
        ++ (case maybeError of
                Just errorText ->
                    [ Palette.toBorderColor Palette.red
                    , Element.below
                        (row [ paddingXY 0 10, spacing 5, Palette.toFontColor Palette.red, Font.size 14 ]
                            [ FeatherIcons.alertTriangle
                                |> FeatherIcons.withSize 16
                                |> FeatherIcons.toHtml []
                                |> Element.html
                                |> Element.el []
                            , text errorText
                            ]
                        )
                    ]

                Nothing ->
                    []
           )


viewDocketId : FormOptions -> Form -> Element Msg
viewDocketId options form =
    column [ width (fill |> maximum 215), height fill, paddingXY 0 10 ]
        [ viewField options.showHelp
            { tooltip = Just DocketIdInfo
            , description = "This is the unique id for a detainer warrant. Please take care when entering this."
            , children =
                [ case options.docketId of
                    Just docketId ->
                        el [ height (px 41), Element.alignBottom, padding 10, Element.width Element.shrink ] (text ("Docket # " ++ docketId))

                    Nothing ->
                        TextField.singlelineText ChangedDocketId
                            "Docket number"
                            form.docketId
                            |> TextField.setLabelVisible True
                            |> TextField.withPlaceholder "12AB3456"
                            |> TextField.renderElement options.renderConfig

                -- (withValidation DocketId options.problems [ Input.focusedOnLoad ])
                ]
            }
        ]


viewFileDate : FormOptions -> Form -> Element Msg
viewFileDate options form =
    -- let
    --     hasChanges =
    --         (Maybe.withDefault False <|
    --             Maybe.map ((/=) form.fileDate.date << .fileDate) options.originalWarrant
    --         )
    --             || (options.originalWarrant == Nothing && form.fileDate.date /= Nothing)
    -- in
    column [ width (fill |> maximum 150), padding 10 ]
        [ viewField options.showHelp
            { tooltip = Just FileDateInfo
            , description = "The date the detainer warrant was created in the court system."
            , children =
                [ DatePicker.input (withValidation FileDate options.problems (withChanges False (boxAttrs ++ [ centerX, Element.centerY ])))
                    { onChange = ChangedFileDatePicker
                    , selected = form.fileDate.date
                    , text = form.fileDate.dateText
                    , label = defaultLabel "File date"
                    , placeholder =
                        Just <| Input.placeholder labelAttrs <| text <| Date.toIsoString options.today
                    , settings = DatePicker.defaultSettings
                    , model = form.fileDate.pickerModel
                    }
                ]
            }
        ]


basicDropdown { config, itemToStr, selected, items } =
    Dropdown.basic config
        |> Dropdown.withItems items
        |> Dropdown.withSelected selected
        |> Dropdown.withItemToText itemToStr
        |> Dropdown.withMaximumListHeight 200


statusDropdown : Form -> Dropdown.Dropdown (Maybe Status) Msg
statusDropdown form =
    basicDropdown
        { config =
            { dropdownMsg = StatusDropdownMsg
            , onSelectMsg = PickedStatus
            , state = form.statusDropdown
            }
        , selected = Just form.status
        , itemToStr = Maybe.withDefault "-" << Maybe.map DetainerWarrant.statusText
        , items = DetainerWarrant.statusOptions
        }


caresDropdown form =
    basicDropdown
        { config =
            { dropdownMsg = CaresDropdownMsg
            , onSelectMsg = PickedCares
            , state = form.caresDropdown
            }
        , selected = Just form.isCares
        , itemToStr = ternaryText
        , items = DetainerWarrant.ternaryOptions
        }


legacyDropdown form =
    basicDropdown
        { config =
            { dropdownMsg = LegacyDropdownMsg
            , onSelectMsg = PickedLegacy
            , state = form.legacyDropdown
            }
        , selected = Just form.isLegacy
        , itemToStr = ternaryText
        , items = DetainerWarrant.ternaryOptions
        }


nonpaymentDropdown form =
    basicDropdown
        { config =
            { dropdownMsg = NonpaymentDropdownMsg
            , onSelectMsg = PickedNonpayment
            , state = form.nonpaymentDropdown
            }
        , selected = Just form.isNonpayment
        , itemToStr = ternaryText
        , items = DetainerWarrant.ternaryOptions
        }


amountClaimedDropdown form =
    basicDropdown
        { config =
            { dropdownMsg = CategoryDropdownMsg
            , onSelectMsg = PickedAmountClaimedCategory
            , state = form.categoryDropdown
            }
        , selected = Just form.amountClaimedCategory
        , itemToStr = DetainerWarrant.amountClaimedCategoryText
        , items = DetainerWarrant.amountClaimedCategoryOptions
        }


courtroomDropdown courtrooms index judgment =
    basicDropdown
        { config =
            { dropdownMsg = CourtroomDropdownMsg index
            , onSelectMsg = PickedCourtroom index
            , state = judgment.courtroomDropdown
            }
        , selected = Just judgment.courtroom
        , itemToStr = Maybe.withDefault "-" << Maybe.map .name
        , items = Nothing :: List.map Just courtrooms
        }


dismissalBasisDropdown index judgment =
    basicDropdown
        { config =
            { dropdownMsg = DismissalBasisDropdownMsg index
            , onSelectMsg = PickedDismissalBasis index
            , state = judgment.dismissalBasisDropdown
            }
        , selected = Just judgment.dismissalBasis
        , itemToStr = Judgment.dismissalBasisOption
        , items = Judgment.dismissalBasisOptions
        }


conditionsDropdown index judgment =
    basicDropdown
        { config =
            { dropdownMsg = ConditionsDropdownMsg index
            , onSelectMsg = PickedConditions index
            , state = judgment.conditionsDropdown
            }
        , selected = Just judgment.condition
        , itemToStr = Maybe.withDefault "N/A" << Maybe.map Judgment.conditionText
        , items = Judgment.conditionsOptions
        }


ternaryText isCares =
    case isCares of
        Just bool ->
            if bool then
                "Yes"

            else
                "No"

        Nothing ->
            "Unknown"


viewStatus : FormOptions -> Form -> Element Msg
viewStatus options form =
    column [ width (fill |> maximum 200) ]
        [ viewField options.showHelp
            { tooltip = Just StatusInfo
            , description = "The current status of the case in the court system."
            , children =
                [ column [ spacing 5, width fill ]
                    [ el labelAttrs (text "Status")
                    , statusDropdown form
                        |> Dropdown.renderElement options.renderConfig
                    ]
                ]
            }
        ]


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


firstAliasMatch query person =
    List.find (insensitiveMatch query) person.aliases


withAliasBadge str =
    str ++ " [Alias]"


viewPlaintiffSearch : (SearchBox.ChangeEvent Plaintiff -> Msg) -> FormOptions -> PlaintiffForm -> Element Msg
viewPlaintiffSearch onChange options form =
    let
        hasChanges =
            (Maybe.withDefault False <|
                Maybe.map ((/=) form.person << .plaintiff) options.originalWarrant
            )
                || (options.originalWarrant == Nothing && form.text /= "")
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
            (Maybe.withDefault False <|
                Maybe.map ((/=) form.person << .plaintiffAttorney) options.originalWarrant
            )
                || (options.originalWarrant == Nothing && form.text /= "")
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


viewCourtroom : FormOptions -> Int -> JudgmentForm -> Element Msg
viewCourtroom options index form =
    -- let
    --     hasChanges =
    --         (Maybe.withDefault False <|
    --             Maybe.map ((/=) form.courtroom.selection << .courtroom) options.originalWarrant
    --         )
    --             || (options.originalWarrant == Nothing && form.courtroom.text /= "")
    -- in
    column [ width fill ]
        [ viewField options.showHelp
            { tooltip = Just CourtroomInfo
            , description = "The court room where eviction proceedings will occur."
            , children =
                [ column [ spacing 5, width fill ]
                    [ el labelAttrs (text "Courtroom")
                    , courtroomDropdown options.courtrooms index form
                        |> Dropdown.renderElement options.renderConfig
                    ]
                ]
            }
        ]


viewAmountClaimed : FormOptions -> Form -> Element Msg
viewAmountClaimed options form =
    column [ width (fill |> maximum 215) ]
        [ viewField options.showHelp
            { tooltip = Just AmountClaimedInfo
            , description = "The monetary amount the plaintiff is requesting from the defendant."
            , children =
                [ TextField.singlelineText ChangedAmountClaimed
                    "Amount claimed"
                    (if form.amountClaimed == "" then
                        form.amountClaimed

                     else
                        "$" ++ form.amountClaimed
                    )
                    |> TextField.setLabelVisible True
                    |> TextField.withPlaceholder "$0.00"
                    |> TextField.withOnEnterPressed ConfirmAmountClaimed
                    |> TextField.renderElement options.renderConfig
                ]
            }
        ]


viewAmountClaimedCategory : FormOptions -> Form -> Element Msg
viewAmountClaimedCategory options form =
    column [ width (fill |> maximum 200) ]
        [ viewField options.showHelp
            { tooltip = Just AmountClaimedCategoryInfo
            , description = "Plaintiffs may ask for payment, repossession, or more."
            , children =
                [ column [ spacing 5, width fill ]
                    [ el labelAttrs (text "Amount Claimed Category")
                    , amountClaimedDropdown form
                        |> Dropdown.renderElement options.renderConfig
                    ]
                ]
            }
        ]


viewCares : FormOptions -> Form -> Element Msg
viewCares options form =
    column [ width fill ]
        [ viewField options.showHelp
            { tooltip = Just CaresInfo
            , description = "C.A.R.E.S. was an aid package provided during the pandemic. If a docket number has a \"Notice,\" check to see whether the property falls under the CARES act"
            , children =
                [ column [ spacing 5, width fill ]
                    [ el labelAttrs (text "Is C.A.R.E.S. property?")
                    , caresDropdown form
                        |> Dropdown.renderElement options.renderConfig
                    ]
                ]
            }
        ]


viewLegacy : FormOptions -> Form -> Element Msg
viewLegacy options form =
    column [ width fill ]
        [ viewField options.showHelp
            { tooltip = Just LegacyInfo
            , description = "L.E.G.A.C.Y. is a special court created for handling evictions during the pandemic. Looks up cases listed under \"LEGACY Case DW Numbers\" tab and check if the case is there or not."
            , children =
                [ column [ spacing 5, width fill ]
                    [ el labelAttrs (text "Is L.E.G.A.C.Y. property?")
                    , legacyDropdown form
                        |> Dropdown.renderElement options.renderConfig
                    ]
                ]
            }
        ]


viewNonpayment : FormOptions -> Form -> Element Msg
viewNonpayment options form =
    column [ width fill ]
        [ viewField options.showHelp
            { tooltip = Just NonpaymentInfo
            , description = "People can be evicted for a number of reasons, including non-payment of rent. We want to know if people are being evicted for this reason because those cases should go to the diversionary court. We assume cases that request $$ are for non-payment but this box is sometimes checked on eviction forms."
            , children =
                [ column [ spacing 5, width fill ]
                    [ el labelAttrs (text "Is nonpayment?")
                    , nonpaymentDropdown form
                        |> Dropdown.renderElement options.renderConfig
                    ]
                ]
            }
        ]


requiredLabel labelFn attrs str =
    labelFn attrs (row [ spacing 5 ] [ text str, requiredStar ])


viewAddress : FormOptions -> Form -> Element Msg
viewAddress options form =
    row [ width (fill |> maximum 800) ]
        [ viewField options.showHelp
            { tooltip = Just AddressInfo
            , description = "The address where the defendant or defendants reside."
            , children =
                [ TextField.singlelineText ChangedAddress
                    "Defendant address"
                    form.address
                    |> TextField.setLabelVisible True
                    |> TextField.withPlaceholder "123 Street Address, City, Zip Code"
                    |> TextField.withWidth TextField.widthFull
                    |> TextField.renderElement options.renderConfig
                ]
            }
        ]


viewFirstName : FormOptions -> Int -> DefendantForm -> Element Msg
viewFirstName options index defendant =
    column [ width fill ]
        [ viewField options.showHelp
            { tooltip = Nothing
            , description = ""
            , children =
                [ TextField.singlelineText (ChangedFirstName index)
                    "First name"
                    defendant.firstName
                    |> TextField.setLabelVisible True
                    |> TextField.renderElement options.renderConfig

                --(withValidation (DefendantFirstName index) options.problems (withChanges hasChanges []))
                ]
            }
        ]


viewMiddleName : FormOptions -> Int -> DefendantForm -> Element Msg
viewMiddleName options index defendant =
    column [ width fill ]
        [ viewField options.showHelp
            { tooltip = Nothing
            , description = ""
            , children =
                [ TextField.singlelineText (ChangedMiddleName index)
                    "Middle name"
                    defendant.middleName
                    |> TextField.setLabelVisible True
                    |> TextField.renderElement options.renderConfig
                ]
            }
        ]


viewLastName : FormOptions -> Int -> DefendantForm -> Element Msg
viewLastName options index defendant =
    column [ width fill ]
        [ viewField options.showHelp
            { tooltip = Nothing
            , description = ""
            , children =
                [ TextField.singlelineText (ChangedLastName index)
                    "Last name"
                    defendant.lastName
                    |> TextField.setLabelVisible True
                    |> TextField.renderElement options.renderConfig

                -- (withValidation (DefendantLastName index) options.problems (withChanges hasChanges []))
                ]
            }
        ]


viewSuffix : FormOptions -> Int -> DefendantForm -> Element Msg
viewSuffix options index defendant =
    column [ width (fill |> maximum 100) ]
        [ viewField options.showHelp
            { tooltip = Nothing
            , description = ""
            , children =
                [ TextField.singlelineText (ChangedSuffix index)
                    "Suffix"
                    defendant.suffix
                    |> TextField.setLabelVisible True
                    |> TextField.renderElement options.renderConfig
                ]
            }
        ]


viewPotentialPhones : FormOptions -> Int -> DefendantForm -> Element Msg
viewPotentialPhones options index defendant =
    wrappedRow [ width fill, spacing 10 ]
        (List.indexedMap
            (\i phone ->
                let
                    originalPhones : Maybe (List String)
                    originalPhones =
                        Maybe.map (String.split ",") <|
                            Maybe.andThen .potentialPhones <|
                                Maybe.andThen (List.getAt index) <|
                                    Maybe.map .defendants options.originalWarrant

                    originalPhone : Maybe String
                    originalPhone =
                        Maybe.andThen (List.getAt i) <| originalPhones
                in
                column
                    [ width
                        (px
                            (if i == 0 then
                                495

                             else
                                205
                            )
                        )
                    ]
                    [ viewField options.showHelp
                        { tooltip =
                            if i == 0 then
                                Just <| PotentialPhoneNumbersInfo index

                            else
                                Nothing
                        , description = "Provide a phone number for the tenant so they will be called and texted during upcoming phonebanks and receive notifications about their detainer warrant updates."
                        , children =
                            [ TextField.singlelineText (ChangedPotentialPhones index i)
                                "Potential phone"
                                phone
                                |> TextField.setLabelVisible True
                                |> TextField.withPlaceholder "123-456-7890"
                                |> TextField.renderElement options.renderConfig
                            , if i == 0 then
                                Element.none

                              else
                                el
                                    [ padding 2
                                    , Element.alignTop
                                    ]
                                    (Button.fromIcon (Icon.close "Remove phone")
                                        |> Button.cmd (RemovePhone index i) Button.clear
                                        |> Button.withSize UI.Size.extraSmall
                                        |> Button.renderElement options.renderConfig
                                    )
                            ]
                        }
                    ]
            )
            defendant.potentialPhones
            ++ [ Button.fromIcon (Icon.add "Add phone")
                    |> Button.cmd (AddPhone index) Button.clear
                    |> Button.renderElement options.renderConfig
               ]
        )


viewDefendantForm : FormOptions -> Int -> DefendantForm -> Element Msg
viewDefendantForm options index defendant =
    column
        [ width fill
        , spacing 10
        , padding 20
        , Border.width 1
        , Palette.toBorderColor Palette.gray300
        , Border.innerGlow (Palette.toElementColor Palette.gray300) 1
        , Border.rounded 5
        ]
        [ row [ centerX, spacing 20 ]
            [ viewFirstName options index defendant
            , viewMiddleName options index defendant
            , viewLastName options index defendant
            , viewSuffix options index defendant
            ]
        , viewPotentialPhones options index defendant
        ]


viewDefendants : FormOptions -> Form -> Element Msg
viewDefendants options form =
    row [ centerX, width (fill |> maximum 1000), padding 10 ]
        [ column [ width fill, spacing 20 ]
            (List.indexedMap (viewDefendantForm options) form.defendants
                ++ [ el [ Element.alignRight ]
                        (Button.fromLabeledOnLeftIcon (Icon.add "Add defendant")
                            |> Button.cmd AddDefendant Button.primary
                            |> Button.renderElement options.renderConfig
                        )
                   ]
            )
        ]


viewJudgments : FormOptions -> Form -> Element Msg
viewJudgments options form =
    column [ centerX, spacing 20, width (fill |> maximum 1000), padding 10 ]
        (List.indexedMap (viewJudgment options) form.judgments
            ++ [ el
                    [ if List.isEmpty form.judgments then
                        Element.centerX

                      else
                        Element.alignRight
                    ]
                    (Button.fromLabeledOnLeftIcon (Icon.add "Add hearing")
                        |> Button.cmd AddJudgment Button.primary
                        |> Button.renderElement options.renderConfig
                    )
               ]
        )


viewJudgmentInterest : FormOptions -> Int -> JudgmentForm -> Element Msg
viewJudgmentInterest options index form =
    column []
        [ row [ spacing 5 ]
            [ viewField options.showHelp
                { tooltip = Just (JudgmentInfo index FeesHaveInterestInfo)
                , description = "Do the fees claimed have interest?"
                , children =
                    [ el
                        [ width (fill |> minimum 200)

                        -- , paddingEach { top = 17, bottom = 0, left = 0, right = 0 }
                        ]
                        (Checkbox.checkbox
                            "Fees have interest"
                            (ToggleJudgmentInterest index)
                            form.hasInterest
                            |> Checkbox.renderElement options.renderConfig
                        )
                    ]
                }
            , if form.hasInterest then
                viewField options.showHelp
                    { tooltip = Just (JudgmentInfo index InterestRateFollowsSiteInfo)
                    , description = "Does the interest rate follow from the website?"
                    , children =
                        [ column [ spacing 5, width fill ]
                            [ Checkbox.checkbox
                                "Interest rate follows site"
                                (ToggleInterestFollowSite index)
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
                { tooltip = Just (JudgmentInfo index InterestRateInfo)
                , description = "The rate of interest that accrues for fees."
                , children =
                    [ column [ spacing 5, width fill ]
                        [ TextField.singlelineText (ChangedInterestRate index)
                            "Interest rate"
                            form.interestRate
                            |> TextField.setLabelVisible True
                            |> TextField.withOnEnterPressed (ConfirmedInterestRate index)
                            |> TextField.withPlaceholder "0%"
                            |> TextField.renderElement options.renderConfig
                        ]
                    ]
                }
        ]


viewJudgmentPossession : FormOptions -> Int -> JudgmentForm -> Element Msg
viewJudgmentPossession options index form =
    viewField options.showHelp
        { tooltip = Just (JudgmentInfo index PossessionAwardedInfo)
        , description = "Has the Plaintiff claimed the residence?"
        , children =
            [ el
                [ width (fill |> minimum 200)
                , paddingEach { top = 17, bottom = 0, left = 0, right = 0 }
                ]
                (Checkbox.checkbox
                    "Possession awarded"
                    (ToggleJudgmentPossession index)
                    form.awardsPossession
                    |> Checkbox.renderElement options.renderConfig
                )
            ]
        }


viewJudgmentPlaintiff : FormOptions -> Int -> JudgmentForm -> List (Element Msg)
viewJudgmentPlaintiff options index form =
    [ viewField options.showHelp
        { tooltip = Just (JudgmentInfo index FeesAwardedInfo)
        , description = "Fees the Plaintiff has been awarded."
        , children =
            [ TextField.singlelineText (ChangedFeesAwarded index)
                "Fees awarded"
                (if form.awardsFees == "" then
                    form.awardsFees

                 else
                    "$" ++ form.awardsFees
                )
                |> TextField.setLabelVisible True
                |> TextField.withPlaceholder "$0.00"
                |> TextField.withOnEnterPressed (ConfirmedFeesAwarded index)
                |> TextField.renderElement options.renderConfig
            ]
        }
    , viewJudgmentPossession options index form
    ]


viewJudgmentDefendant : FormOptions -> Int -> JudgmentForm -> List (Element Msg)
viewJudgmentDefendant options index form =
    [ viewField options.showHelp
        { tooltip = Just (JudgmentInfo index DismissalBasisInfo)
        , description = "Why is the case being dismissed?"
        , children =
            [ column [ spacing 5, width (fill |> minimum 350) ]
                [ el labelAttrs (text "Basis for dismissal")
                , dismissalBasisDropdown index form
                    |> Dropdown.renderElement options.renderConfig
                ]
            ]
        }
    , viewField options.showHelp
        { tooltip = Just (JudgmentInfo index WithPrejudiceInfo)
        , description = "Whether or not the dismissal is made with prejudice."
        , children =
            [ el
                [ width (fill |> minimum 200)
                , paddingEach { top = 17, bottom = 0, left = 0, right = 0 }
                ]
                (Checkbox.checkbox
                    "Dismissal is with prejudice"
                    (ToggledWithPrejudice index)
                    form.withPrejudice
                    |> Checkbox.renderElement options.renderConfig
                )
            ]
        }
    ]


viewJudgeSearch : FormOptions -> Int -> JudgmentForm -> Element Msg
viewJudgeSearch options index form =
    let
        hasChanges =
            False

        -- (Maybe.withDefault False <|
        --     Maybe.map ((/=) form.judge.person << .judge) options.originalWarrant
        -- )
        --     || (options.originalWarrant == Nothing && form.presidingJudge.text /= "")
    in
    column [ width fill ]
        [ viewField options.showHelp
            { tooltip = Just PresidingJudgeInfo
            , description = "The judge that will be presiding over the court case."
            , children =
                [ searchBox (withChanges hasChanges [])
                    { onChange = ChangedJudgmentJudgeSearchBox index
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


viewCourtDate options index form =
    let
        hasChanges =
            True

        -- (Maybe.withDefault False <|
        --     Maybe.map ((/=) form.judgment << .judgment) options.originalWarrant
        -- )
        --     || (options.originalWarrant == Nothing && form.judgment /= defaultCategory)
    in
    viewField options.showHelp
        { tooltip = Just (JudgmentInfo index JudgmentFileDateDetail)
        , description = "The date this judgment was filed."
        , children =
            [ DatePicker.input
                (withValidation
                    (ValidJudgment index JudgmentFileDate)
                    options.problems
                    (withChanges
                        hasChanges
                        (boxAttrs
                            ++ [ Element.htmlAttribute (Html.Attributes.id (judgmentInfoText index JudgmentFileDateDetail))
                               , centerX
                               , Element.centerY
                               ]
                        )
                    )
                )
                { onChange = ChangedJudgmentCourtDatePicker index
                , selected = form.date
                , text = form.dateText
                , label =
                    requiredLabel Input.labelAbove labelAttrs "Court date"
                , placeholder =
                    Just <| Input.placeholder labelAttrs <| text <| Date.toIsoString <| options.today
                , settings = DatePicker.defaultSettings
                , model = form.pickerModel
                }
            ]
        }


viewJudgment : FormOptions -> Int -> JudgmentForm -> Element Msg
viewJudgment options index form =
    column
        [ width fill
        , spacing 10
        , padding 20
        , Border.width 1
        , Palette.toBorderColor Palette.gray300
        , Border.innerGlow (Palette.toElementColor Palette.gray300) 1
        , Border.rounded 5
        , inFront
            (row [ Element.alignRight, padding 20 ]
                [ Button.fromIcon (Icon.close "Remove Judgment")
                    |> Button.cmd (RemoveJudgment index) Button.clear
                    |> Button.renderElement options.renderConfig
                ]
            )
        ]
        [ row
            [ spacing 5
            ]
            [ viewCourtDate options index form.courtDate
            , viewCourtroom options index form
            ]
        , wrappedRow [ spacing 5, width fill ]
            [ viewPlaintiffSearch (ChangedJudgmentPlaintiffSearchBox index) options form.plaintiff
            , viewAttorneySearch (ChangedJudgmentAttorneySearchBox index) options form.plaintiffAttorney
            , viewJudgeSearch options index form
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
                    { tooltip = Just (JudgmentInfo index Summary)
                    , description = "The ruling from the court that will determine if fees or repossession are enforced."
                    , children =
                        [ column [ spacing 5, width (fill |> maximum 200) ]
                            [ el labelAttrs (text "Granted to")
                            , conditionsDropdown index form
                                |> Dropdown.renderElement options.renderConfig
                            ]
                        ]
                    }
                ]
            , row [ spacing 5, width fill ]
                (case form.condition of
                    Just PlaintiffOption ->
                        viewJudgmentPlaintiff options index form

                    Just DefendantOption ->
                        viewJudgmentDefendant options index form

                    Nothing ->
                        [ Element.none ]
                )
            , if form.awardsFees /= "" && form.condition == Just PlaintiffOption then
                viewJudgmentInterest options index form

              else
                Element.none
            , viewJudgmentNotes options index form
            ]
        ]


viewJudgmentNotes : FormOptions -> Int -> JudgmentForm -> Element Msg
viewJudgmentNotes options index form =
    column [ width fill ]
        [ viewField options.showHelp
            { tooltip = Just (JudgmentInfo index JudgmentNotesDetail)
            , description = "Any additional notes you have about this particular judgment go here!"
            , children =
                [ TextField.multilineText (ChangedJudgmentNotes index)
                    "Notes"
                    form.notes
                    |> TextField.withPlaceholder "Add any notes from the judgment sheet or any comments you think is noteworthy."
                    |> TextField.setLabelVisible True
                    |> TextField.withWidth TextField.widthFull
                    |> TextField.renderElement options.renderConfig
                ]
            }
        ]


viewNotes : FormOptions -> Form -> Element Msg
viewNotes options form =
    column [ width fill ]
        [ viewField options.showHelp
            { tooltip = Just NotesInfo
            , description = "Any additional notes you have about this case go here! This is a great place to leave feedback for the form as well, perhaps there's another field or field option we need to provide."
            , children =
                [ TextField.multilineText ChangedNotes
                    "Notes"
                    form.notes
                    |> TextField.withPlaceholder "Add anything you think is noteworthy."
                    |> TextField.setLabelVisible True
                    |> TextField.withWidth TextField.widthFull
                    |> TextField.renderElement options.renderConfig
                ]
            }
        ]


formGroup : List (Element Msg) -> Element Msg
formGroup group =
    row
        [ spacing 10
        , width fill
        ]
        group


tile : List (Element Msg) -> Element Msg
tile groups =
    column
        [ spacing 20
        , padding 20
        , width fill
        , Border.rounded 3
        , Palette.toBorderColor Palette.gray400
        , Border.width 1
        , Border.shadow { offset = ( 0, 10 ), size = 1, blur = 30, color = Palette.toElementColor Palette.gray400 }
        ]
        groups


viewForm : FormOptions -> FormStatus -> Element Msg
viewForm options formStatus =
    case formStatus of
        Initializing id ->
            column [] [ text ("Fetching docket " ++ id) ]

        Ready form ->
            column [ centerX, spacing 30 ]
                [ tile
                    [ paragraph [ Font.center, centerX ] [ text "Court" ]
                    , formGroup
                        [ viewDocketId options form
                        , viewFileDate options form
                        , viewStatus options form
                        ]
                    , formGroup
                        [ viewPlaintiffSearch ChangedPlaintiffSearchBox options form.plaintiff
                        , viewAttorneySearch ChangedPlaintiffAttorneySearchBox options form.plaintiffAttorney
                        ]
                    ]
                , tile
                    [ paragraph [ Font.center, centerX ] [ text "Claims" ]
                    , formGroup
                        [ viewAmountClaimed options form
                        , viewAmountClaimedCategory options form
                        ]
                    , formGroup
                        [ viewCares options form
                        , viewLegacy options form
                        , viewNonpayment options form
                        ]
                    ]
                , tile
                    [ paragraph [ Font.center, centerX ] [ text "Defendants" ]
                    , viewAddress options form
                    , viewDefendants options form
                    ]
                , tile
                    [ paragraph [ Font.center, centerX ] [ text "Hearings" ]
                    , viewJudgments options form
                    ]
                , tile
                    [ viewNotes options form
                    ]
                , row [ Element.alignRight, spacing 10, paddingEach { top = 0, bottom = 100, left = 0, right = 0 } ]
                    [ SplitButton.view (saveConfig options.renderConfig) options.navigationOnSuccess saveOptions form.saveButtonState ]
                ]


saveConfig : RenderConfig -> SplitButton.Config NavigationOnSuccess Msg
saveConfig cfg =
    { itemToText = navigationOptionToText
    , dropdownMsg = SplitButtonMsg
    , onSelect = PickedSaveOption
    , onEnter = Save
    , renderConfig = cfg
    }


saveOptions : List NavigationOnSuccess
saveOptions =
    [ Remain, NewWarrant, PreviousWarrant, NextWarrant ]


navigationOptionToText : NavigationOnSuccess -> String
navigationOptionToText navigationOnSuccess =
    case navigationOnSuccess of
        Remain ->
            "Save"

        NewWarrant ->
            "Save and add another"

        PreviousWarrant ->
            "Save and go to previous"

        NextWarrant ->
            "Save and go to next"


formOptions : RenderConfig -> Date -> Model -> FormOptions
formOptions cfg today model =
    { plaintiffs = model.plaintiffs
    , attorneys = model.attorneys
    , judges = model.judges
    , courtrooms = model.courtrooms
    , showHelp = model.showHelp
    , docketId = model.docketId
    , today = today
    , problems = model.problems
    , originalWarrant = model.warrant
    , renderConfig = cfg
    , navigationOnSuccess = model.navigationOnSuccess
    }


viewProblem : Problem -> Element Msg
viewProblem problem =
    paragraph []
        [ case problem of
            InvalidEntry _ _ ->
                Element.none

            ServerError err ->
                text ("Something went wrong: " ++ err)
        ]


viewProblems : List Problem -> Element Msg
viewProblems problems =
    row [] [ column [] (List.map viewProblem problems) ]


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


withTooltip : Bool -> String -> List (Element Msg)
withTooltip showHelp str =
    if showHelp then
        [ viewTooltip str ]

    else
        []


title =
    "RDC | Admin | Detainer Warrants | Edit"


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
                                [ text
                                    ((case model.docketId of
                                        Just _ ->
                                            "Edit"

                                        Nothing ->
                                            "Create"
                                     )
                                        ++ " Detainer Warrant"
                                    )
                                ]
                            ]
                        ]
                    ]
                , viewProblems model.problems
                , row [ width fill ]
                    [ viewForm (formOptions cfg static.sharedData.runtime.today model) model.form
                    ]
                ]
            ]
        ]
    }


subscriptions : Maybe PageUrl -> RouteParams -> Path -> Model -> Sub Msg
subscriptions pageUrl params path model =
    case model.form of
        Initializing _ ->
            Sub.none

        Ready _ ->
            Sub.batch
                ([-- Dropdown.onOutsideClick form.statusDropdown StatusDropdownMsg
                  -- , Dropdown.onOutsideClick form.categoryDropdown CategoryDropdownMsg
                  --  , Dropdown.onOutsideClick form.conditionsDropdown ConditionsDropdownMsg
                 ]
                 -- ++ Maybe.withDefault [] (Maybe.map (List.singleton << onOutsideClick) model.tooltip)
                )


judgmentInfoText : Int -> JudgmentDetail -> String
judgmentInfoText index detail =
    "judgment-"
        ++ (case detail of
                JudgmentFileDateDetail ->
                    "file-date-detail"

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

                JudgmentNotesDetail ->
                    "notes-detail"
           )
        ++ "-"
        ++ String.fromInt index



-- FORM


{-| Marks that we've trimmed the form's fields, so we don't accidentally send
it to the server without having trimmed it!
-}
type TrimmedForm
    = Trimmed Form


type JudgmentValidation
    = JudgmentFileDate


{-| When adding a variant here, add it to `fieldsToValidate` too!
-}
type ValidatedField
    = DocketId
    | FileDate
    | CourtDate
    | DefendantAddress
    | DefendantFirstName Int
    | DefendantLastName Int
    | DefendantPhoneNumber Int Int
    | ValidJudgment Int JudgmentValidation


fieldsToValidate : List DefendantForm -> List ValidatedField
fieldsToValidate defendants =
    let
        numDefendants =
            List.length defendants - 1
    in
    List.concat
        [ [ DocketId
          , FileDate
          , CourtDate
          , DefendantAddress
          ]
        , List.map DefendantFirstName <| List.range 0 numDefendants
        , List.map DefendantLastName <| List.range 0 numDefendants
        , List.concat <| List.indexedMap (\i def -> List.indexedMap (\j _ -> DefendantPhoneNumber i j) def.potentialPhones) defendants
        ]


{-| Trim the form and validate its fields. If there are problems, report them!
-}
validate : Date -> FormStatus -> Result (List Problem) TrimmedForm
validate today formStatus =
    case formStatus of
        Initializing _ ->
            Err []

        Ready form ->
            let
                trimmedForm =
                    trimFields form
            in
            case List.concatMap (validateField today trimmedForm) (fieldsToValidate form.defendants) of
                [] ->
                    Ok trimmedForm

                problems ->
                    Err problems


validateField : Date -> TrimmedForm -> ValidatedField -> List Problem
validateField today (Trimmed form) field =
    List.map (InvalidEntry field) <|
        case field of
            DocketId ->
                if String.isEmpty form.docketId then
                    []

                else
                    []

            FileDate ->
                []

            CourtDate ->
                []

            DefendantAddress ->
                if String.isEmpty form.address then
                    [ "Defendant address cannot be blank" ]

                else
                    []

            DefendantFirstName defIndex ->
                let
                    firstName =
                        List.getAt defIndex form.defendants
                            |> Maybe.map .firstName
                            |> Maybe.withDefault ""
                in
                if String.isEmpty firstName then
                    [ "First name cannot be blank" ]

                else
                    []

            DefendantLastName defIndex ->
                let
                    lastName =
                        List.getAt defIndex form.defendants
                            |> Maybe.map .lastName
                            |> Maybe.withDefault ""
                in
                if String.isEmpty lastName then
                    [ "Last name cannot be blank" ]

                else
                    []

            DefendantPhoneNumber defIndex phoneIndex ->
                let
                    phone =
                        form.defendants
                            |> List.getAt defIndex
                            |> Maybe.andThen (List.getAt phoneIndex << .potentialPhones)
                            |> Maybe.withDefault ""
                in
                if validUSNumber phone then
                    [ "Invalid phone number format" ]

                else
                    []

            ValidJudgment index _ ->
                case List.head <| List.take index form.judgments of
                    Just _ ->
                        -- case judgmentValidation of
                        --     JudgmentFileDate ->
                        --         if Date.compare (Maybe.withDefault today judgment.courtDate.date) (Maybe.withDefault today form.courtDate.date) == LT then
                        --             [ "Judgment cannot be filed before detainer warrant." ]
                        --         else
                        []

                    Nothing ->
                        []


{-| Don't trim while the user is typing! That would be super annoying.
Instead, trim only on submit.
-}
trimFields : Form -> TrimmedForm
trimFields form =
    Trimmed
        { form
            | docketId = String.trim form.docketId
            , amountClaimed = String.trim form.amountClaimed
            , address = String.trim form.address
            , notes = String.trim form.notes
        }


type alias ApiForms =
    { detainerWarrant : DetainerWarrantEdit
    , defendants : List Defendant
    , plaintiff : Maybe Plaintiff
    , attorney : Maybe Attorney
    , judgments : List JudgmentEdit
    }


toDefendantData : String -> DefendantForm -> Defendant
toDefendantData address defendant =
    { id = Maybe.withDefault -1 defendant.id
    , name = ""
    , verifiedPhone = Nothing
    , firstName = defendant.firstName
    , middleName =
        if String.isEmpty defendant.middleName then
            Nothing

        else
            Just defendant.middleName
    , lastName = defendant.lastName
    , suffix =
        if String.isEmpty defendant.suffix then
            Nothing

        else
            Just defendant.suffix
    , aliases =
        []
    , address = address
    , potentialPhones =
        if List.isEmpty defendant.potentialPhones || defendant.potentialPhones == [ "" ] then
            Nothing

        else
            Just <| String.join "," defendant.potentialPhones
    }


related id =
    { id = id }


toDetainerWarrant : Date -> TrimmedForm -> ApiForms
toDetainerWarrant today (Trimmed form) =
    { detainerWarrant =
        { docketId = form.docketId
        , fileDate = Maybe.andThen Date.Extra.toPosix form.fileDate.date
        , status = form.status
        , plaintiff = Maybe.map (related << .id) form.plaintiff.person
        , plaintiffAttorney = Maybe.map (related << .id) form.plaintiffAttorney.person
        , isCares = form.isCares
        , isLegacy = form.isLegacy
        , nonpayment = form.isNonpayment
        , amountClaimed = String.toFloat <| String.replace "," "" form.amountClaimed
        , amountClaimedCategory = form.amountClaimedCategory
        , defendants = List.filterMap (Maybe.map related << .id) form.defendants
        , notes =
            if String.isEmpty form.notes then
                Nothing

            else
                Just form.notes
        }
    , defendants = List.map (toDefendantData form.address) form.defendants
    , plaintiff =
        form.plaintiff.person
    , attorney =
        form.plaintiffAttorney.person
    , judgments =
        List.map (Judgment.editFromForm today) form.judgments
    }


conditional fieldName fn field =
    Maybe.withDefault [] <| Maybe.map (\f -> [ ( fieldName, fn f ) ]) field


nullable fieldName fn field =
    Maybe.withDefault [ ( fieldName, Encode.null ) ] <| Maybe.map (\f -> [ ( fieldName, fn f ) ]) field


toBody body =
    Encode.object [ ( "data", body ) ]
        |> Http.jsonBody


upsertDefendant : String -> Maybe Cred -> Int -> Defendant -> Cmd Msg
upsertDefendant domain maybeCred index form =
    let
        decoder =
            Rest.itemDecoder Defendant.decoder

        defendant =
            Encode.object
                ([ ( "first_name", Encode.string form.firstName )
                 , ( "last_name", Encode.string form.lastName )
                 , ( "address", Encode.string form.address )
                 , defaultDistrict
                 ]
                    ++ conditional "id" Encode.int (remoteId form)
                    ++ conditional "middle_name" Encode.string form.middleName
                    ++ conditional "suffix" Encode.string form.suffix
                    ++ conditional "potential_phones" Encode.string form.potentialPhones
                )

        body =
            toBody defendant
    in
    case remoteId form of
        Just id ->
            Rest.patch (Endpoint.defendant domain id) maybeCred body (UpsertedDefendant index) decoder

        Nothing ->
            Rest.post (Endpoint.defendants domain []) maybeCred body (UpsertedDefendant index) decoder


upsertJudgment : String -> Maybe Cred -> DetainerWarrantEdit -> Int -> JudgmentEdit -> Cmd Msg
upsertJudgment domain maybeCred warrant index form =
    let
        decoder =
            Rest.itemDecoder Judgment.decoder

        body =
            toBody (encodeJudgment warrant form)
    in
    case form.id of
        Just id ->
            Rest.patch (Endpoint.judgment domain id) maybeCred body (UpsertedJudgment index) decoder

        Nothing ->
            Rest.post (Endpoint.judgments domain []) maybeCred body (UpsertedJudgment index) decoder


deleteJudgment : String -> Maybe Cred -> Int -> Int -> Cmd Msg
deleteJudgment domain maybeCred index id =
    Rest.delete (Endpoint.judgment domain id) maybeCred (DeletedJudgment index)


remoteId : { a | id : number } -> Maybe number
remoteId resource =
    if resource.id == -1 then
        Nothing

    else
        Just resource.id


upsertAttorney : String -> Maybe Cred -> Attorney -> Cmd Msg
upsertAttorney domain maybeCred attorney =
    let
        decoder =
            Rest.itemDecoder Attorney.decoder

        postData =
            Encode.object
                ([ ( "name", Encode.string attorney.name )
                 , defaultDistrict
                 ]
                    ++ conditional "id" Encode.int (remoteId attorney)
                )

        body =
            toBody postData
    in
    case remoteId attorney of
        Just id ->
            Rest.patch (Endpoint.attorney domain id) maybeCred body UpsertedAttorney decoder

        Nothing ->
            Rest.post (Endpoint.attorneys domain []) maybeCred body UpsertedAttorney decoder


defaultDistrict =
    ( "district_id", Encode.int 1 )


upsertPlaintiff : String -> Maybe Cred -> Plaintiff -> Cmd Msg
upsertPlaintiff domain maybeCred plaintiff =
    let
        decoder =
            Rest.itemDecoder Plaintiff.decoder

        postData =
            Encode.object
                ([ ( "name", Encode.string plaintiff.name )
                 , defaultDistrict
                 ]
                    ++ conditional "id" Encode.int (remoteId plaintiff)
                )

        body =
            toBody postData
    in
    case remoteId plaintiff of
        Just id ->
            Rest.patch (Endpoint.plaintiff domain id) maybeCred body UpsertedPlaintiff decoder

        Nothing ->
            Rest.post (Endpoint.plaintiffs domain []) maybeCred body UpsertedPlaintiff decoder


encodeRelated record =
    Encode.object [ ( "id", Encode.int record.id ) ]


encodeJudgment : DetainerWarrantEdit -> JudgmentEdit -> Encode.Value
encodeJudgment warrant judgment =
    Encode.object
        ([ ( "interest", Encode.bool judgment.hasInterest )
         , ( "detainer_warrant", Encode.object [ ( "docket_id", Encode.string warrant.docketId ) ] )
         ]
            ++ conditional "id" Encode.int judgment.id
            ++ nullable "court_date" Time.Utils.posixEncoder judgment.courtDate
            ++ nullable "courtroom" encodeRelated judgment.courtroom
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


updateDetainerWarrant : String -> Maybe Cred -> DetainerWarrantEdit -> Cmd Msg
updateDetainerWarrant domain maybeCred form =
    let
        detainerWarrant =
            Encode.object
                ([ ( "docket_id", Encode.string form.docketId )
                 , ( "defendants", Encode.list encodeRelated form.defendants )
                 , ( "amount_claimed_category", Encode.string (DetainerWarrant.amountClaimedCategoryText form.amountClaimedCategory) )
                 ]
                    ++ nullable "file_date" Time.Utils.posixEncoder form.fileDate
                    ++ nullable "status" Encode.string (Maybe.map DetainerWarrant.statusText form.status)
                    ++ nullable "plaintiff" encodeRelated form.plaintiff
                    ++ nullable "plaintiff_attorney" encodeRelated form.plaintiffAttorney
                    ++ nullable "is_cares" Encode.bool form.isCares
                    ++ nullable "is_legacy" Encode.bool form.isLegacy
                    ++ nullable "nonpayment" Encode.bool form.nonpayment
                    ++ nullable "amount_claimed" Encode.float form.amountClaimed
                    ++ nullable "notes" Encode.string form.notes
                )
    in
    Rest.itemDecoder DetainerWarrant.decoder
        |> Rest.patch (Endpoint.detainerWarrant domain form.docketId) maybeCred (toBody detainerWarrant) CreatedDetainerWarrant


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
        , description = "Edit detainer warrant details"
        , locale = Just "en-us"
        , title = title
        }
        |> Seo.website


type alias Data =
    ()
