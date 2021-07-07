module Page.Organize.DetainerWarrantCreation exposing (Model, Msg, init, subscriptions, toSession, update, view)

import Api exposing (Cred)
import Api.Endpoint as Endpoint
import Browser.Dom
import Browser.Events exposing (onMouseDown)
import Campaign exposing (Campaign)
import Color
import Date exposing (Date)
import DateFormat
import DatePicker exposing (ChangeEvent(..))
import Defendant exposing (Defendant)
import DetainerWarrant exposing (AmountClaimedCategory, Attorney, ConditionOption(..), Conditions(..), Courtroom, DatePickerState, DetainerWarrant, DetainerWarrantEdit, DismissalBasis(..), DismissalConditions, Entrance(..), Interest(..), Judge, Judgement, JudgementEdit, JudgementForm, OwedConditions, Plaintiff, Status, amountClaimedCategoryText)
import Dropdown
import Element exposing (Element, below, centerX, column, el, fill, focusStyle, height, image, inFront, link, maximum, minimum, padding, paddingXY, paragraph, px, row, shrink, spacing, spacingXY, text, textColumn, width, wrappedRow)
import Element.Background as Background
import Element.Border as Border
import Element.Events as Events
import Element.Font as Font
import Element.Input as Input exposing (labelHidden)
import FeatherIcons
import Html.Attributes
import Html.Events
import Http
import Json.Decode as Decode
import Json.Encode as Encode
import LineChart.Axis.Values exposing (Amount)
import List.Extra as List
import Mask
import Maybe.Extra
import Palette
import PhoneNumber
import PhoneNumber.Countries exposing (countryUS)
import Route
import SearchBox
import Session exposing (Session)
import Set
import Settings exposing (Settings)
import Task
import Url.Builder as QueryParam
import User exposing (User)
import Widget
import Widget.Customize as Customize
import Widget.Icon exposing (Icon)
import Widget.Material as Material


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
    , tooltip : Maybe Tooltip
    , docketId : Maybe String
    , today : Maybe Date
    , problems : List Problem
    , originalWarrant : Maybe DetainerWarrant
    }


type alias PlaintiffForm =
    { person : Maybe Plaintiff
    , text : String
    , searchBox : SearchBox.State
    }


type alias AttorneyForm =
    { person : Maybe Attorney
    , text : String
    , searchBox : SearchBox.State
    }


type alias JudgeForm =
    { person : Maybe Judge
    , text : String
    , searchBox : SearchBox.State
    }


type alias CourtroomForm =
    { selection : Maybe Courtroom
    , text : String
    , searchBox : SearchBox.State
    }


type alias Form =
    { docketId : String
    , fileDate : DatePickerState
    , status : Status
    , statusDropdown : Dropdown.State Status
    , plaintiff : PlaintiffForm
    , plaintiffAttorney : AttorneyForm
    , courtDate : DatePickerState
    , courtroom : CourtroomForm
    , presidingJudge : JudgeForm
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
    , judgements : List JudgementForm
    , notes : String
    }


type Problem
    = InvalidEntry ValidatedField String
    | ServerError String


type JudgementDetail
    = JudgementFileDateDetail
    | Summary
    | FeesClaimedInfo
    | PossessionClaimedInfo
    | FeesHaveInterestInfo
    | InterestRateFollowsSiteInfo
    | InterestRateInfo
    | DismissalBasisInfo
    | WithPrejudiceInfo
    | JudgementNotesDetail


type Tooltip
    = DetainerWarrantInfo
    | DocketIdInfo
    | FileDateInfo
    | StatusInfo
    | PlaintiffInfo
    | PlaintiffAttorneyInfo
    | CourtDateInfo
    | CourtroomInfo
    | PresidingJudgeInfo
    | AmountClaimedInfo
    | AmountClaimedCategoryInfo
    | CaresInfo
    | LegacyInfo
    | NonpaymentInfo
    | AddressInfo
    | PotentialPhoneNumbersInfo Int
    | JudgementInfo Int JudgementDetail
    | NotesInfo


type SaveState
    = SavingRelatedModels { attorney : Bool, plaintiff : Bool, courtroom : Bool, judge : Bool, defendants : Int }
    | SavingWarrant
    | Done


type alias Model =
    { session : Session
    , warrant : Maybe DetainerWarrant
    , docketId : Maybe String
    , today : Maybe Date
    , tooltip : Maybe Tooltip
    , problems : List Problem
    , form : FormStatus
    , plaintiffs : List Plaintiff
    , attorneys : List Attorney
    , judges : List Judge
    , courtrooms : List Courtroom
    , saveState : SaveState
    , newFormOnSuccess : Bool
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


initJudgeForm : Maybe Judge -> JudgeForm
initJudgeForm judge =
    { person = judge
    , text = Maybe.withDefault "" <| Maybe.map .name judge
    , searchBox = SearchBox.init
    }


initCourtroomForm : Maybe Courtroom -> CourtroomForm
initCourtroomForm courtroom =
    { selection = courtroom
    , text = Maybe.withDefault "" <| Maybe.map .name courtroom
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


editForm : DetainerWarrant -> Form
editForm warrant =
    { docketId = warrant.docketId
    , fileDate = initDatePicker (Just warrant.fileDate)
    , status = warrant.status
    , statusDropdown = Dropdown.init "status-dropdown"
    , plaintiff = initPlaintiffForm warrant.plaintiff
    , plaintiffAttorney = initAttorneyForm warrant.plaintiffAttorney
    , courtDate = initDatePicker warrant.courtDate
    , courtroom = initCourtroomForm warrant.courtroom
    , presidingJudge = initJudgeForm warrant.presidingJudge
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
    , judgements = List.indexedMap (\index j -> judgementFormInit j.fileDate index (Just j)) warrant.judgements
    , notes = Maybe.withDefault "" warrant.notes
    }


judgementFormInit : Date -> Int -> Maybe Judgement -> JudgementForm
judgementFormInit today index existing =
    let
        new =
            { id = Nothing
            , conditionsDropdown = Dropdown.init ("judgement-dropdown-new-" ++ String.fromInt index)
            , condition = PlaintiffOption
            , notes = ""
            , fileDate = { date = Just today, dateText = Date.toIsoString today, pickerModel = DatePicker.init |> DatePicker.setToday today }
            , enteredBy = Default
            , claimsFees = ""
            , claimsPossession = False
            , hasInterest = False
            , interestRate = ""
            , interestFollowsSite = True
            , dismissalBasisDropdown = Dropdown.init ("judgement-dropdown-dismissal-basis-" ++ String.fromInt index)
            , dismissalBasis = FailureToProsecute
            , withPrejudice = False
            }
    in
    case existing of
        Just judgement ->
            let
                default =
                    { new
                        | id = Just judgement.id
                        , enteredBy = judgement.enteredBy
                        , fileDate = { date = Just judgement.fileDate, dateText = Date.toIsoString judgement.fileDate, pickerModel = DatePicker.init |> DatePicker.setToday today }
                        , conditionsDropdown = Dropdown.init ("judgement-dropdown-" ++ String.fromInt judgement.id)
                        , dismissalBasisDropdown = Dropdown.init ("judgement-dropdown-dismissal-basis-" ++ String.fromInt judgement.id)
                        , notes = Maybe.withDefault "" judgement.notes
                    }
            in
            case judgement.conditions of
                PlaintiffConditions owed ->
                    { default
                        | condition = PlaintiffOption
                        , claimsFees = Maybe.withDefault "" <| Maybe.map String.fromFloat owed.claimsFees
                        , claimsPossession = owed.claimsPossession
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

                DefendantConditions dismissal ->
                    { default
                        | condition = DefendantOption
                        , dismissalBasis = dismissal.basis
                        , withPrejudice = dismissal.withPrejudice
                    }

        Nothing ->
            new


initCreate : Form
initCreate =
    { docketId = ""
    , fileDate = initDatePicker Nothing
    , status = DetainerWarrant.Pending
    , statusDropdown = Dropdown.init "status-dropdown"
    , plaintiff = initPlaintiffForm Nothing
    , plaintiffAttorney = initAttorneyForm Nothing
    , courtDate = initDatePicker Nothing
    , courtroom = initCourtroomForm Nothing
    , presidingJudge = initJudgeForm Nothing
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
    , judgements = []
    , notes = ""
    }


type FormStatus
    = Initializing
    | Ready Form


init : Maybe String -> Session -> ( Model, Cmd Msg )
init maybeId session =
    let
        maybeCred =
            Session.cred session
    in
    ( { session = session
      , warrant = Nothing
      , docketId = maybeId
      , tooltip = Nothing
      , problems = []
      , today = Nothing
      , form =
            case maybeId of
                Just _ ->
                    Initializing

                Nothing ->
                    Ready initCreate
      , plaintiffs = []
      , attorneys = []
      , judges = []
      , courtrooms = []
      , saveState = Done
      , newFormOnSuccess = False
      }
    , case maybeId of
        Just id ->
            getWarrant id maybeCred

        Nothing ->
            Task.perform GotToday Date.today
    )


getWarrant : String -> Maybe Cred -> Cmd Msg
getWarrant id maybeCred =
    Api.get (Endpoint.detainerWarrant id) maybeCred GotDetainerWarrant (Api.itemDecoder DetainerWarrant.decoder)


type Msg
    = GotDetainerWarrant (Result Http.Error (Api.Item DetainerWarrant))
    | GotToday Date
    | ChangeTooltip Tooltip
    | CloseTooltip
    | ChangedDocketId String
    | ChangedFileDatePicker ChangeEvent
    | ChangedCourtDatePicker ChangeEvent
    | ChangedPlaintiffSearchBox (SearchBox.ChangeEvent Plaintiff)
    | ChangedPlaintiffAttorneySearchBox (SearchBox.ChangeEvent Attorney)
    | PickedStatus (Maybe Status)
    | StatusDropdownMsg (Dropdown.Msg Status)
    | ChangedCourtroomSearchBox (SearchBox.ChangeEvent Courtroom)
    | ChangedJudgeSearchBox (SearchBox.ChangeEvent Judge)
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
    | AddJudgement
    | RemoveJudgement Int
    | ChangedJudgementFileDatePicker Int ChangeEvent
    | PickedConditions Int (Maybe ConditionOption)
    | ConditionsDropdownMsg Int (Dropdown.Msg ConditionOption)
    | ChangedFeesClaimed Int String
    | ConfirmedFeesClaimed Int
    | ToggleJudgmentPossession Int Bool
    | ToggleJudgmentInterest Int Bool
    | ChangedInterestRate Int String
    | ConfirmedInterestRate Int
    | ToggleInterestFollowSite Int Bool
    | DismissalBasisDropdownMsg Int (Dropdown.Msg DismissalBasis)
    | PickedDismissalBasis Int (Maybe DismissalBasis)
    | ToggledWithPrejudice Int Bool
    | ChangedJudgementNotes Int String
    | ChangedNotes String
    | SubmitForm
    | SubmitAndAddAnother
    | UpsertedPlaintiff (Result Http.Error (Api.Item DetainerWarrant.Plaintiff))
    | UpsertedAttorney (Result Http.Error (Api.Item DetainerWarrant.Attorney))
    | UpsertedCourtroom (Result Http.Error (Api.Item DetainerWarrant.Courtroom))
    | UpsertedJudge (Result Http.Error (Api.Item DetainerWarrant.Judge))
    | UpsertedDefendant Int (Result Http.Error (Api.Item Defendant))
    | CreatedDetainerWarrant (Result Http.Error (Api.Item DetainerWarrant))
    | GotPlaintiffs (Result Http.Error (Api.Collection Plaintiff))
    | GotAttorneys (Result Http.Error (Api.Collection Attorney))
    | GotJudges (Result Http.Error (Api.Collection Attorney))
    | GotCourtrooms (Result Http.Error (Api.Collection Courtroom))
    | NoOp


updateForm : (Form -> Form) -> Model -> ( Model, Cmd Msg )
updateForm transform model =
    ( { model
        | form =
            case model.form of
                Initializing ->
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
                Initializing ->
                    model.form

                Ready oldForm ->
                    Ready (transform oldForm)
    }


updateFormNarrow : (Form -> ( Form, Cmd Msg )) -> Model -> ( Model, Cmd Msg )
updateFormNarrow transform model =
    let
        ( newForm, cmd ) =
            case model.form of
                Initializing ->
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
savingError error model =
    let
        problems =
            [ ServerError "Error saving detainer warrant" ]
    in
    { model | problems = problems }


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    let
        maybeCred =
            Session.cred model.session
    in
    case msg of
        GotDetainerWarrant result ->
            case result of
                Ok warrantPage ->
                    ( { model | warrant = Just warrantPage.data, form = Ready (editForm warrantPage.data) }
                    , Task.perform GotToday Date.today
                    )

                Err errMsg ->
                    ( model, Cmd.none )

        GotToday today ->
            updateForm
                (\form ->
                    let
                        fileDate =
                            form.fileDate

                        updatedFileDate =
                            { fileDate | pickerModel = fileDate.pickerModel |> DatePicker.setToday today }

                        courtDate =
                            form.courtDate

                        updatedCourtDate =
                            { courtDate | pickerModel = courtDate.pickerModel |> DatePicker.setToday today }
                    in
                    { form | fileDate = updatedFileDate, courtDate = updatedCourtDate }
                )
                { model | today = Just today }

        ChangeTooltip selection ->
            ( { model
                | tooltip =
                    if Just selection == model.tooltip then
                        Nothing

                    else
                        Just selection
              }
            , Cmd.none
            )

        CloseTooltip ->
            ( { model | tooltip = Nothing }, Cmd.none )

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

        ChangedCourtDatePicker changeEvent ->
            case changeEvent of
                DateChanged date ->
                    updateForm
                        (\form ->
                            let
                                courtDate =
                                    form.courtDate

                                updatedCourtDate =
                                    { courtDate | date = Just date, dateText = Date.toIsoString date }
                            in
                            { form | courtDate = updatedCourtDate }
                        )
                        model

                TextChanged text ->
                    updateForm
                        (\form ->
                            let
                                courtDate =
                                    form.courtDate

                                updatedCourtDate =
                                    { courtDate
                                        | date =
                                            Date.fromIsoString text
                                                |> Result.toMaybe
                                                |> Maybe.Extra.orElse courtDate.date
                                        , dateText = text
                                    }
                            in
                            { form | courtDate = updatedCourtDate }
                        )
                        model

                PickerChanged subMsg ->
                    updateForm
                        (\form ->
                            let
                                courtDate =
                                    form.courtDate

                                updatedCourtDate =
                                    { courtDate | pickerModel = courtDate.pickerModel |> DatePicker.update subMsg }
                            in
                            { form | courtDate = updatedCourtDate }
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
                    , Api.get (Endpoint.plaintiffs [ ( "name", text ) ]) maybeCred GotPlaintiffs (Api.collectionDecoder DetainerWarrant.plaintiffDecoder)
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
                    , Api.get (Endpoint.attorneys [ ( "name", text ) ]) maybeCred GotAttorneys (Api.collectionDecoder DetainerWarrant.attorneyDecoder)
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
                        | status = Maybe.withDefault DetainerWarrant.Pending option
                    }
                )
                model

        StatusDropdownMsg subMsg ->
            updateFormNarrow
                (\form ->
                    let
                        ( state, cmd ) =
                            Dropdown.update (statusDropdownConfig [])
                                subMsg
                                { options = DetainerWarrant.statusOptions
                                , selectedOption = Just form.status
                                }
                                form.statusDropdown
                    in
                    ( { form | statusDropdown = state }, cmd )
                )
                model

        ChangedCourtroomSearchBox changeEvent ->
            case changeEvent of
                SearchBox.SelectionChanged selection ->
                    updateForm
                        (\form ->
                            let
                                courtroom =
                                    form.courtroom

                                updatedCourtroom =
                                    { courtroom | selection = Just selection, text = selection.name }
                            in
                            { form | courtroom = updatedCourtroom }
                        )
                        model

                SearchBox.TextChanged text ->
                    ( updateFormOnly
                        (\form ->
                            let
                                courtroom =
                                    form.courtroom

                                updatedCourtroom =
                                    { courtroom
                                        | selection = Nothing
                                        , text = text
                                        , searchBox = SearchBox.reset courtroom.searchBox
                                    }
                            in
                            { form | courtroom = updatedCourtroom }
                        )
                        model
                    , Api.get (Endpoint.courtrooms [ ( "name", text ) ]) maybeCred GotCourtrooms (Api.collectionDecoder DetainerWarrant.courtroomDecoder)
                    )

                SearchBox.SearchBoxChanged subMsg ->
                    updateForm
                        (\form ->
                            let
                                courtroom =
                                    form.courtroom

                                updatedCourtroom =
                                    { courtroom
                                        | searchBox = SearchBox.update subMsg courtroom.searchBox
                                    }
                            in
                            { form | courtroom = updatedCourtroom }
                        )
                        model

        ChangedJudgeSearchBox changeEvent ->
            case changeEvent of
                SearchBox.SelectionChanged person ->
                    updateForm
                        (\form ->
                            let
                                judge =
                                    form.presidingJudge

                                updatedJudge =
                                    { judge | person = Just person }
                            in
                            { form | presidingJudge = updatedJudge }
                        )
                        model

                SearchBox.TextChanged text ->
                    ( updateFormOnly
                        (\form ->
                            let
                                judge =
                                    form.presidingJudge

                                updatedJudge =
                                    { judge
                                        | person = Nothing
                                        , text = text
                                        , searchBox = SearchBox.reset judge.searchBox
                                    }
                            in
                            { form | presidingJudge = updatedJudge }
                        )
                        model
                    , Api.get (Endpoint.judges [ ( "name", text ) ]) maybeCred GotJudges (Api.collectionDecoder DetainerWarrant.judgeDecoder)
                    )

                SearchBox.SearchBoxChanged subMsg ->
                    updateForm
                        (\form ->
                            let
                                judge =
                                    form.presidingJudge

                                updatedJudge =
                                    { judge
                                        | searchBox = SearchBox.update subMsg judge.searchBox
                                    }
                            in
                            { form | presidingJudge = updatedJudge }
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
                        ( state, cmd ) =
                            Dropdown.update (categoryDropdownConfig [])
                                subMsg
                                { options =
                                    DetainerWarrant.amountClaimedCategoryOptions
                                , selectedOption = Just form.amountClaimedCategory
                                }
                                form.categoryDropdown
                    in
                    ( { form | categoryDropdown = state }, cmd )
                )
                model

        CaresDropdownMsg subMsg ->
            updateFormNarrow
                (\form ->
                    let
                        ( state, cmd ) =
                            Dropdown.update (caresDropdownConfig [])
                                subMsg
                                { options = DetainerWarrant.ternaryOptions
                                , selectedOption = Just form.isCares
                                }
                                form.caresDropdown
                    in
                    ( { form | caresDropdown = state }, cmd )
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
                        ( state, cmd ) =
                            Dropdown.update (legacyDropdownConfig [])
                                subMsg
                                { options = DetainerWarrant.ternaryOptions
                                , selectedOption = Just form.isLegacy
                                }
                                form.legacyDropdown
                    in
                    ( { form | legacyDropdown = state }, cmd )
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
                        ( state, cmd ) =
                            Dropdown.update (nonpaymentDropdownConfig [])
                                subMsg
                                { options = DetainerWarrant.ternaryOptions
                                , selectedOption = Just form.isNonpayment
                                }
                                form.nonpaymentDropdown
                    in
                    ( { form | nonpaymentDropdown = state }, cmd )
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

        AddJudgement ->
            case model.today of
                Just today ->
                    updateFormNarrow
                        (\form ->
                            let
                                nextJudgementId =
                                    List.length form.judgements
                            in
                            ( { form
                                | judgements = form.judgements ++ [ judgementFormInit today nextJudgementId Nothing ]
                              }
                            , Task.attempt
                                (always NoOp)
                                (Browser.Dom.focus (judgementInfoText nextJudgementId JudgementFileDateDetail))
                            )
                        )
                        model

                Nothing ->
                    ( model, Cmd.none )

        RemoveJudgement selected ->
            updateForm (\form -> { form | judgements = List.removeAt selected form.judgements }) model

        ChangedJudgementFileDatePicker selected changeEvent ->
            case changeEvent of
                DateChanged date ->
                    updateForm
                        (updateJudgement selected
                            (\judgement ->
                                let
                                    fileDate =
                                        judgement.fileDate

                                    updatedFileDate =
                                        { fileDate | date = Just date, dateText = Date.toIsoString date }
                                in
                                { judgement | fileDate = updatedFileDate }
                            )
                        )
                        model

                TextChanged text ->
                    updateForm
                        (updateJudgement selected
                            (\judgement ->
                                let
                                    fileDate =
                                        judgement.fileDate

                                    updatedFileDate =
                                        { fileDate
                                            | date =
                                                Date.fromIsoString text
                                                    |> Result.toMaybe
                                                    |> Maybe.Extra.orElse fileDate.date
                                            , dateText = text
                                        }
                                in
                                { judgement | fileDate = updatedFileDate }
                            )
                        )
                        model

                PickerChanged subMsg ->
                    updateForm
                        (updateJudgement selected
                            (\judgement ->
                                let
                                    fileDate =
                                        judgement.fileDate

                                    updatedFileDate =
                                        { fileDate | pickerModel = fileDate.pickerModel |> DatePicker.update subMsg }
                                in
                                { judgement | fileDate = updatedFileDate }
                            )
                        )
                        model

        PickedConditions selected option ->
            updateForm
                (updateJudgement selected (\judgement -> { judgement | condition = Maybe.withDefault PlaintiffOption option }))
                model

        DismissalBasisDropdownMsg selected subMsg ->
            updateFormNarrow
                (\form ->
                    let
                        judgementsAndCmds =
                            List.indexedMap
                                (\candidate judgement ->
                                    if selected == candidate then
                                        let
                                            ( state, cmd ) =
                                                Dropdown.update (dismissalBasisDropdownConfig selected [])
                                                    subMsg
                                                    { options = DetainerWarrant.dismissalBasisOptions
                                                    , selectedOption = Just judgement.dismissalBasis
                                                    }
                                                    judgement.dismissalBasisDropdown
                                        in
                                        ( { judgement
                                            | dismissalBasisDropdown = state
                                          }
                                        , cmd
                                        )

                                    else
                                        ( judgement, Cmd.none )
                                )
                                form.judgements
                    in
                    ( { form | judgements = List.map Tuple.first judgementsAndCmds }
                    , Cmd.batch (List.map Tuple.second judgementsAndCmds)
                    )
                )
                model

        PickedDismissalBasis selected option ->
            updateForm
                (updateJudgement selected (\judgement -> { judgement | dismissalBasis = Maybe.withDefault FailureToProsecute option }))
                model

        ToggledWithPrejudice selected checked ->
            updateForm
                (updateJudgement selected (\judgement -> { judgement | withPrejudice = checked }))
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
                        judgementsAndCmds =
                            List.indexedMap
                                (\candidate judgement ->
                                    if selected == candidate then
                                        let
                                            ( state, cmd ) =
                                                Dropdown.update (conditionsDropdownConfig selected [])
                                                    subMsg
                                                    { options = DetainerWarrant.conditionsOptions
                                                    , selectedOption = Just judgement.condition
                                                    }
                                                    judgement.conditionsDropdown
                                        in
                                        ( { judgement
                                            | conditionsDropdown = state
                                          }
                                        , cmd
                                        )

                                    else
                                        ( judgement, Cmd.none )
                                )
                                form.judgements
                    in
                    ( { form | judgements = List.map Tuple.first judgementsAndCmds }
                    , Cmd.batch (List.map Tuple.second judgementsAndCmds)
                    )
                )
                model

        ChangedFeesClaimed selected money ->
            updateForm
                (updateJudgement selected (\judgement -> { judgement | claimsFees = String.replace "$" "" money }))
                model

        ConfirmedFeesClaimed selected ->
            let
                extract money =
                    String.toFloat (String.replace "," "" money)

                options =
                    Mask.defaultDecimalOptions
            in
            updateForm
                (updateJudgement selected
                    (\judgement ->
                        { judgement
                            | claimsFees =
                                case extract judgement.claimsFees of
                                    Just moneyFloat ->
                                        Mask.floatDecimal options moneyFloat

                                    Nothing ->
                                        judgement.claimsFees
                        }
                    )
                )
                model

        ToggleJudgmentPossession selected checked ->
            updateForm
                (updateJudgement selected (\judgement -> { judgement | claimsPossession = checked }))
                model

        ToggleJudgmentInterest selected checked ->
            updateForm
                (updateJudgement selected (\judgement -> { judgement | hasInterest = checked }))
                model

        ChangedInterestRate selected interestRate ->
            updateForm
                (updateJudgement selected (\judgement -> { judgement | interestRate = String.replace "%" "" interestRate }))
                model

        ConfirmedInterestRate selected ->
            updateForm
                (updateJudgement selected (\judgement -> { judgement | interestRate = String.replace "%" "" judgement.interestRate ++ "%" }))
                model

        ToggleInterestFollowSite selected checked ->
            updateForm
                (updateJudgement selected (\judgement -> { judgement | interestFollowsSite = checked }))
                model

        ChangedJudgementNotes selected notes ->
            updateForm
                (updateJudgement selected (\judgement -> { judgement | notes = notes }))
                model

        ChangedNotes notes ->
            updateForm
                (\form -> { form | notes = notes })
                model

        SubmitForm ->
            submitForm model

        SubmitAndAddAnother ->
            submitFormAndAddAnother model

        UpsertedPlaintiff (Ok plaintiffItem) ->
            nextStepSave
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

        UpsertedPlaintiff (Err errors) ->
            ( model, Cmd.none )

        UpsertedCourtroom (Ok courtroomItem) ->
            nextStepSave
                (updateFormOnly
                    (\form -> { form | courtroom = initCourtroomForm (Just courtroomItem.data) })
                    { model
                        | saveState =
                            case model.saveState of
                                SavingRelatedModels models ->
                                    SavingRelatedModels { models | courtroom = True }

                                _ ->
                                    model.saveState
                    }
                )

        UpsertedCourtroom (Err errors) ->
            ( model, Cmd.none )

        UpsertedJudge (Ok judgeItem) ->
            nextStepSave
                (updateFormOnly
                    (\form -> { form | presidingJudge = initJudgeForm (Just judgeItem.data) })
                    { model
                        | saveState =
                            case model.saveState of
                                SavingRelatedModels models ->
                                    SavingRelatedModels { models | judge = True }

                                _ ->
                                    model.saveState
                    }
                )

        UpsertedJudge (Err errors) ->
            ( model, Cmd.none )

        UpsertedDefendant index (Ok defendant) ->
            nextStepSave
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

        UpsertedDefendant _ (Err errors) ->
            ( model, Cmd.none )

        UpsertedAttorney (Ok attorney) ->
            nextStepSave
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

        UpsertedAttorney (Err errors) ->
            ( model, Cmd.none )

        CreatedDetainerWarrant (Ok detainerWarrantItem) ->
            ( { model
                | form =
                    Ready (editForm detainerWarrantItem.data)
                , warrant = Just detainerWarrantItem.data
              }
            , if model.newFormOnSuccess then
                Route.replaceUrl (Session.navKey model.session) (Route.DetainerWarrantCreation Nothing)

              else
                Cmd.none
            )

        CreatedDetainerWarrant (Err errors) ->
            ( savingError errors model, Cmd.none )

        GotPlaintiffs (Ok plaintiffsPage) ->
            ( { model | plaintiffs = plaintiffsPage.data }, Cmd.none )

        GotPlaintiffs (Err problems) ->
            ( model, Cmd.none )

        GotAttorneys (Ok attorneysPage) ->
            ( { model | attorneys = attorneysPage.data }, Cmd.none )

        GotAttorneys (Err problems) ->
            ( model, Cmd.none )

        GotJudges (Ok judgesPage) ->
            ( { model | judges = judgesPage.data }, Cmd.none )

        GotJudges (Err problems) ->
            ( model, Cmd.none )

        GotCourtrooms (Ok courtroomsPage) ->
            ( { model | courtrooms = courtroomsPage.data }, Cmd.none )

        GotCourtrooms (Err problems) ->
            ( model, Cmd.none )

        NoOp ->
            ( model, Cmd.none )


updateJudgement : Int -> (JudgementForm -> JudgementForm) -> Form -> Form
updateJudgement selected fn form =
    { form
        | judgements =
            List.indexedMap
                (\index judgement ->
                    if selected == index then
                        fn judgement

                    else
                        judgement
                )
                form.judgements
    }


submitFormAndAddAnother : Model -> ( Model, Cmd Msg )
submitFormAndAddAnother model =
    Tuple.mapFirst (\m -> { m | newFormOnSuccess = True }) (submitForm model)


submitForm : Model -> ( Model, Cmd Msg )
submitForm model =
    let
        maybeCred =
            Session.cred model.session
    in
    case model.today of
        Just today ->
            case validate today model.form of
                Ok validForm ->
                    let
                        apiForms =
                            toDetainerWarrant today validForm
                    in
                    ( { model
                        | newFormOnSuccess = False
                        , problems = []
                        , saveState =
                            SavingRelatedModels
                                { attorney = apiForms.attorney == Nothing
                                , plaintiff = apiForms.plaintiff == Nothing
                                , courtroom = apiForms.courtroom == Nothing
                                , judge = apiForms.judge == Nothing
                                , defendants = 0
                                }
                      }
                    , Cmd.batch
                        (List.concat
                            [ apiForms.attorney
                                |> Maybe.map (List.singleton << upsertAttorney maybeCred)
                                |> Maybe.withDefault []
                            , Maybe.withDefault [] <| Maybe.map (List.singleton << upsertPlaintiff maybeCred) apiForms.plaintiff
                            , Maybe.withDefault [] <| Maybe.map (List.singleton << upsertCourtroom maybeCred) apiForms.courtroom
                            , Maybe.withDefault [] <| Maybe.map (List.singleton << upsertJudge maybeCred) apiForms.judge
                            , List.indexedMap (upsertDefendant maybeCred) apiForms.defendants
                            ]
                        )
                    )

                Err problems ->
                    ( { model | newFormOnSuccess = False, problems = problems }
                    , Cmd.none
                    )

        Nothing ->
            ( model, Cmd.none )


nextStepSave : Model -> ( Model, Cmd Msg )
nextStepSave model =
    let
        maybeCred =
            Session.cred model.session
    in
    case model.today of
        Just today ->
            case validate today model.form of
                Ok form ->
                    let
                        apiForms =
                            toDetainerWarrant today form
                    in
                    case model.saveState of
                        SavingRelatedModels models ->
                            if
                                models.attorney
                                    && models.courtroom
                                    && models.judge
                                    && models.plaintiff
                                    && List.length apiForms.defendants
                                    >= models.defendants
                            then
                                ( { model | saveState = SavingWarrant }
                                , updateDetainerWarrant maybeCred apiForms.detainerWarrant
                                )

                            else
                                ( model, Cmd.none )

                        SavingWarrant ->
                            ( model, Cmd.none )

                        Done ->
                            ( model, Cmd.none )

                Err _ ->
                    ( model, Cmd.none )

        Nothing ->
            ( model, Cmd.none )


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


palette : Material.Palette
palette =
    { primary = Color.rgb255 236 31 39
    , secondary = Color.rgb255 216 27 96
    , background = Color.rgb255 255 255 255
    , surface = Color.rgb255 255 255 255
    , error = Color.rgb255 156 39 176
    , on =
        { primary = Color.rgb255 255 255 255
        , secondary = Color.rgb255 0 0 0
        , background = Color.rgb255 0 0 0
        , surface = Color.rgb255 0 0 0
        , error = Color.rgb255 255 255 255
        }
    }


focusedButtonStyles : List (Element.Attr decorative msg)
focusedButtonStyles =
    [ Background.color Palette.sred, Font.color Palette.white ]


hoveredButtonStyles : List (Element.Attr decorative msg)
hoveredButtonStyles =
    [ Background.color Palette.sred, Font.color Palette.white ]


helpButton : Tooltip -> Element Msg
helpButton tooltip =
    Input.button
        [ Events.onLoseFocus CloseTooltip
        , Font.color Palette.sred
        , padding 10
        , Element.alignBottom
        , Border.rounded 3
        , Element.mouseOver hoveredButtonStyles
        , Element.focused focusedButtonStyles
        ]
        { label =
            Element.html
                (FeatherIcons.helpCircle
                    |> FeatherIcons.toHtml []
                )
        , onPress = Just (ChangeTooltip tooltip)
        }


type alias Field =
    { tooltip : Maybe Tooltip
    , description : String
    , children : List (Element Msg)
    , currentTooltip : Maybe Tooltip
    }


requiredStar =
    el [ Font.color Palette.sred, Element.alignTop, width Element.shrink ] (text "*")


viewField : Field -> Element Msg
viewField field =
    let
        help =
            Maybe.withDefault Element.none <| Maybe.map helpButton field.tooltip

        tooltip =
            case field.tooltip of
                Just tip ->
                    withTooltip tip field.currentTooltip field.description

                Nothing ->
                    []
    in
    row
        ([ width fill, height fill, spacingXY 5 0, paddingXY 0 10 ] ++ tooltip)
        (help :: field.children)


withChanges hasChanged attrs =
    attrs
        ++ (if hasChanged then
                [ Border.color Palette.purpleLight ]

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
                    [ Border.color Palette.sred
                    , Element.below
                        (row [ paddingXY 0 10, spacing 5, Font.color Palette.sred, Font.size 14 ]
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
    column [ width fill, height fill, paddingXY 0 10 ]
        [ viewField
            { tooltip = Just DocketIdInfo
            , description = "This is the unique id for a detainer warrant. Please take care when entering this."
            , currentTooltip = options.tooltip
            , children =
                [ case options.docketId of
                    Just docketId ->
                        el [ height (px 41), Element.alignBottom, padding 10, Element.width Element.shrink ] (text ("Docket Number: " ++ docketId))

                    Nothing ->
                        textInput
                            (withValidation DocketId options.problems [ Input.focusedOnLoad ])
                            { onChange = ChangedDocketId
                            , text = form.docketId
                            , placeholder = Just (Input.placeholder [] (text "12AB34"))
                            , label = requiredLabel Input.labelAbove "Docket Number"
                            }
                ]
            }
        ]


viewFileDate : FormOptions -> Form -> Element Msg
viewFileDate options form =
    let
        hasChanges =
            (Maybe.withDefault False <|
                Maybe.map ((/=) form.fileDate.date << Just << .fileDate) options.originalWarrant
            )
                || (options.originalWarrant == Nothing && form.fileDate.date /= Nothing)
    in
    column [ width fill, padding 10 ]
        [ viewField
            { tooltip = Just FileDateInfo
            , description = "The date the detainer warrant was created in the court system."
            , currentTooltip = options.tooltip
            , children =
                [ DatePicker.input (withValidation FileDate options.problems (withChanges hasChanges [ centerX, Element.centerY, Border.color Palette.grayLight ]))
                    { onChange = ChangedFileDatePicker
                    , selected = form.fileDate.date
                    , text = form.fileDate.dateText
                    , label =
                        requiredLabel Input.labelAbove "File Date"
                    , placeholder =
                        Maybe.map (Input.placeholder [] << text << Date.toIsoString) options.today
                    , settings = DatePicker.defaultSettings
                    , model = form.fileDate.pickerModel
                    }
                ]
            }
        ]


dropdownConfig label itemToStr dropdownMsg itemPickedMsg attrs =
    let
        containerAttrs =
            [ width (Element.fill |> Element.minimum 250)
            ]

        selectAttrs =
            [ Border.width 1
            , Border.rounded 5
            , Border.color Palette.grayLight
            , paddingXY 16 8
            , spacing 10
            , width fill
            , Element.focused
                [ Border.color Palette.grayLight
                , Border.shadow { offset = ( 0, 0 ), size = 3, blur = 3, color = Palette.gray }
                ]
            ]
                ++ attrs

        listAttrs =
            [ Border.width 1
            , Border.roundEach { topLeft = 0, topRight = 0, bottomLeft = 5, bottomRight = 5 }
            , width fill
            , spacing 5
            , Background.color Palette.white
            ]

        itemToPrompt item =
            text (itemToStr item)

        itemToElement selected highlighted item =
            let
                bgColor =
                    if highlighted then
                        Palette.redLight

                    else if selected then
                        Palette.sred

                    else
                        Palette.white
            in
            el
                ([ Background.color bgColor
                 , padding 8
                 , spacing 10
                 , width fill
                 ]
                    ++ (if selected then
                            []

                        else
                            [ Element.mouseOver [ Background.color Palette.redLight ] ]
                       )
                )
                (text (itemToStr item))
    in
    Dropdown.basic
        { itemsFromModel = .options
        , selectionFromModel = .selectedOption
        , dropdownMsg = dropdownMsg
        , onSelectMsg = itemPickedMsg
        , itemToPrompt = itemToPrompt
        , itemToElement = itemToElement
        }
        |> Dropdown.withContainerAttributes containerAttrs
        |> Dropdown.withSelectAttributes selectAttrs
        |> Dropdown.withListAttributes listAttrs
        |> Dropdown.withPromptElement (el [] <| text label)
        |> Dropdown.withOpenCloseButtons
            { openButton =
                FeatherIcons.chevronDown |> FeatherIcons.toHtml [] |> Element.html
            , closeButton = FeatherIcons.chevronUp |> FeatherIcons.toHtml [] |> Element.html
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


withUnknown fn maybe =
    case maybe of
        Just a ->
            fn a

        Nothing ->
            "Unknown"


categoryDropdownConfig =
    dropdownConfig "Amount Claimed Category" DetainerWarrant.amountClaimedCategoryText CategoryDropdownMsg PickedAmountClaimedCategory


statusDropdownConfig =
    dropdownConfig "Status" DetainerWarrant.statusText StatusDropdownMsg PickedStatus


caresDropdownConfig =
    dropdownConfig "Cares" ternaryText CaresDropdownMsg PickedCares


legacyDropdownConfig =
    dropdownConfig "Legacy" ternaryText LegacyDropdownMsg PickedLegacy


nonpaymentDropdownConfig =
    dropdownConfig "Nonpayment" ternaryText NonpaymentDropdownMsg PickedNonpayment


conditionsDropdownConfig index =
    dropdownConfig "Granted to" DetainerWarrant.conditionText (ConditionsDropdownMsg index) (PickedConditions index)


dismissalBasisDropdownConfig index =
    dropdownConfig "Dismissal based on" DetainerWarrant.dismissalBasisOption (DismissalBasisDropdownMsg index) (PickedDismissalBasis index)


viewStatus : FormOptions -> Form -> Element Msg
viewStatus options form =
    let
        defaultStatus =
            DetainerWarrant.Pending

        hasChanges =
            (Maybe.withDefault False <|
                Maybe.map ((/=) form.status << .status) options.originalWarrant
            )
                || (options.originalWarrant == Nothing && form.status /= defaultStatus)
    in
    column [ width shrink ]
        [ viewField
            { tooltip = Just StatusInfo
            , currentTooltip = options.tooltip
            , description = "The current status of the case in the court system."
            , children =
                [ column [ spacing 5, width fill ]
                    [ requiredLabel Element.el "Status"
                    , Dropdown.view (statusDropdownConfig (withChanges hasChanges [])) { options = DetainerWarrant.statusOptions, selectedOption = Just form.status } form.statusDropdown
                        |> el []
                    ]
                ]
            }
        ]


searchBox attrs =
    SearchBox.input ([ Border.color Palette.grayLight ] ++ attrs)


viewPlaintiffSearch : FormOptions -> Form -> Element Msg
viewPlaintiffSearch options form =
    let
        hasChanges =
            (Maybe.withDefault False <|
                Maybe.map ((/=) form.plaintiff.person << .plaintiff) options.originalWarrant
            )
                || (options.originalWarrant == Nothing && form.plaintiff.text /= "")
    in
    row [ width fill ]
        [ viewField
            { tooltip = Just PlaintiffInfo
            , currentTooltip = options.tooltip
            , description = "The plaintiff is typically the landlord seeking money or possession from the defendant (tenant)."
            , children =
                [ searchBox (withChanges hasChanges [])
                    { onChange = ChangedPlaintiffSearchBox
                    , text = form.plaintiff.text
                    , selected = form.plaintiff.person
                    , options = Just ({ id = -1, name = form.plaintiff.text } :: options.plaintiffs)
                    , label = Input.labelAbove [] (text "Plaintiff")
                    , placeholder = Just <| Input.placeholder [] (text "Search for plaintiff")
                    , toLabel = \person -> person.name
                    , filter = \query option -> True
                    , state = form.plaintiff.searchBox
                    }
                ]
            }
        ]


viewPlaintiffAttorneySearch : FormOptions -> Form -> Element Msg
viewPlaintiffAttorneySearch options form =
    let
        hasChanges =
            (Maybe.withDefault False <|
                Maybe.map ((/=) form.plaintiffAttorney.person << .plaintiffAttorney) options.originalWarrant
            )
                || (options.originalWarrant == Nothing && form.plaintiffAttorney.text /= "")
    in
    column [ width fill ]
        [ viewField
            { tooltip = Just PlaintiffAttorneyInfo
            , currentTooltip = options.tooltip
            , description = "The plaintiff attorney is the legal representation for the plaintiff in this eviction process."
            , children =
                [ searchBox (withChanges hasChanges [])
                    { onChange = ChangedPlaintiffAttorneySearchBox
                    , text = form.plaintiffAttorney.text
                    , selected = form.plaintiffAttorney.person
                    , options = Just ({ id = -1, name = form.plaintiffAttorney.text } :: options.attorneys)
                    , label = Input.labelAbove [] (text "Plaintiff Attorney")
                    , placeholder = Just <| Input.placeholder [] (text "Search for plaintiff attorney")
                    , toLabel = \person -> person.name
                    , filter = \query option -> True
                    , state = form.plaintiffAttorney.searchBox
                    }
                ]
            }
        ]


viewCourtDate : FormOptions -> Form -> Element Msg
viewCourtDate options form =
    let
        hasChanges =
            (Maybe.withDefault False <|
                Maybe.map ((/=) form.courtDate.date << .courtDate) options.originalWarrant
            )
                || (options.originalWarrant == Nothing && form.courtDate.dateText /= "")
    in
    column [ width fill ]
        [ viewField
            { tooltip = Just CourtDateInfo
            , currentTooltip = options.tooltip
            , description = "The date set for deliberating the judgement of the eviction in court."
            , children =
                [ DatePicker.input (withValidation CourtDate options.problems (withChanges hasChanges [ Element.centerX, Element.centerY ]))
                    { onChange = ChangedCourtDatePicker
                    , selected = form.courtDate.date
                    , text = form.courtDate.dateText
                    , label =
                        Input.labelAbove [] (text "Court Date")
                    , placeholder = Just <| Input.placeholder [] (text (Maybe.withDefault "" <| Maybe.map Date.toIsoString options.today))
                    , settings = DatePicker.defaultSettings
                    , model = form.courtDate.pickerModel
                    }
                ]
            }
        ]


viewCourtroom : FormOptions -> Form -> Element Msg
viewCourtroom options form =
    let
        hasChanges =
            (Maybe.withDefault False <|
                Maybe.map ((/=) form.courtroom.selection << .courtroom) options.originalWarrant
            )
                || (options.originalWarrant == Nothing && form.courtroom.text /= "")
    in
    column [ width fill ]
        [ viewField
            { tooltip = Just CourtroomInfo
            , currentTooltip = options.tooltip
            , description = "The court room where eviction proceedings will occur."
            , children =
                [ searchBox (withChanges hasChanges [])
                    { onChange = ChangedCourtroomSearchBox
                    , text = form.courtroom.text
                    , selected = form.courtroom.selection
                    , options = Just ({ id = -1, name = form.courtroom.text } :: options.courtrooms)
                    , label =
                        Input.labelAbove [] (text "Courtroom")
                    , placeholder = Just <| Input.placeholder [] (text "Search for courtroom")
                    , toLabel = .name
                    , filter = \query option -> True
                    , state = form.courtroom.searchBox
                    }
                ]
            }
        ]


viewPresidingJudgeSearch : FormOptions -> Form -> Element Msg
viewPresidingJudgeSearch options form =
    let
        hasChanges =
            (Maybe.withDefault False <|
                Maybe.map ((/=) form.presidingJudge.person << .presidingJudge) options.originalWarrant
            )
                || (options.originalWarrant == Nothing && form.presidingJudge.text /= "")
    in
    column [ width fill ]
        [ viewField
            { tooltip = Just PresidingJudgeInfo
            , currentTooltip = options.tooltip
            , description = "The judge that will be presiding over the court case."
            , children =
                [ searchBox (withChanges hasChanges [])
                    { onChange = ChangedJudgeSearchBox
                    , text = form.presidingJudge.text
                    , selected = form.presidingJudge.person
                    , options = Just ({ id = -1, name = form.presidingJudge.text } :: options.judges)
                    , label = Input.labelAbove [] (text "Presiding Judge")
                    , placeholder = Just <| Input.placeholder [] (text "Search for judge")
                    , toLabel = \person -> person.name
                    , filter = \query option -> True
                    , state = form.presidingJudge.searchBox
                    }
                ]
            }
        ]


viewAmountClaimed : FormOptions -> Form -> Element Msg
viewAmountClaimed options form =
    let
        hasChanges =
            (Maybe.withDefault False <|
                Maybe.map ((/=) form.amountClaimed << Mask.floatDecimal Mask.defaultDecimalOptions) <|
                    Maybe.andThen .amountClaimed options.originalWarrant
            )
                || (options.originalWarrant == Nothing && form.amountClaimed /= "")
    in
    column [ width fill ]
        [ viewField
            { tooltip = Just AmountClaimedInfo
            , currentTooltip = options.tooltip
            , description = "The monetary amount the plaintiff is requesting from the defendant."
            , children =
                [ textInput (withChanges hasChanges [ Events.onLoseFocus ConfirmAmountClaimed ])
                    { onChange = ChangedAmountClaimed
                    , text =
                        if form.amountClaimed == "" then
                            form.amountClaimed

                        else
                            "$" ++ form.amountClaimed
                    , label = Input.labelAbove [] (text "Amount Claimed")
                    , placeholder = Just <| Input.placeholder [] (text "$0.00")
                    }
                ]
            }
        ]


viewAmountClaimedCategory : FormOptions -> Form -> Element Msg
viewAmountClaimedCategory options form =
    let
        defaultCategory =
            DetainerWarrant.NotApplicable

        hasChanges =
            (Maybe.withDefault False <|
                Maybe.map ((/=) form.amountClaimedCategory << .amountClaimedCategory) options.originalWarrant
            )
                || (options.originalWarrant == Nothing && form.amountClaimedCategory /= defaultCategory)
    in
    column [ width fill ]
        [ viewField
            { tooltip = Just AmountClaimedCategoryInfo
            , currentTooltip = options.tooltip
            , description = "Plaintiffs may ask for payment, repossession, or more."
            , children =
                [ column [ spacing 5, width fill ]
                    [ el [] (text "Amount Claimed Category")
                    , Dropdown.view (categoryDropdownConfig (withChanges hasChanges []))
                        { options =
                            DetainerWarrant.amountClaimedCategoryOptions
                        , selectedOption = Just form.amountClaimedCategory
                        }
                        form.categoryDropdown
                        |> el []
                    ]
                ]
            }
        ]


viewCares : FormOptions -> Form -> Element Msg
viewCares options form =
    let
        hasChanges =
            (Maybe.withDefault False <|
                Maybe.map ((/=) form.isCares << .isCares) options.originalWarrant
            )
                || (options.originalWarrant == Nothing && form.isCares /= Nothing)
    in
    column [ width fill ]
        [ viewField
            { tooltip = Just CaresInfo
            , currentTooltip = options.tooltip
            , description = "C.A.R.E.S. was an aid package provided during the pandemic. If a docket number has a \"Notice,\" check to see whether the property falls under the CARES act"
            , children =
                [ column [ spacing 5, width fill ]
                    [ el [] (text "Is C.A.R.E.S. property?")
                    , Dropdown.view (caresDropdownConfig (withChanges hasChanges [])) { options = DetainerWarrant.ternaryOptions, selectedOption = Just form.isCares } form.caresDropdown
                        |> el []
                    ]
                ]
            }
        ]


viewLegacy : FormOptions -> Form -> Element Msg
viewLegacy options form =
    let
        hasChanges =
            (Maybe.withDefault False <|
                Maybe.map ((/=) form.isLegacy << .isLegacy) options.originalWarrant
            )
                || (options.originalWarrant == Nothing && form.isLegacy /= Nothing)
    in
    column [ width fill ]
        [ viewField
            { tooltip = Just LegacyInfo
            , currentTooltip = options.tooltip
            , description = "L.E.G.A.C.Y. is a special court created for handling evictions during the pandemic. Looks up cases listed under \"LEGACY Case DW Numbers\" tab and check if the case is there or not."
            , children =
                [ column [ spacing 5, width fill ]
                    [ el [] (text "Is L.E.G.A.C.Y. property?")
                    , Dropdown.view (legacyDropdownConfig (withChanges hasChanges [])) { options = DetainerWarrant.ternaryOptions, selectedOption = Just form.isLegacy } form.legacyDropdown
                        |> el []
                    ]
                ]
            }
        ]


viewNonpayment : FormOptions -> Form -> Element Msg
viewNonpayment options form =
    let
        hasChanges =
            (Maybe.withDefault False <|
                Maybe.map ((/=) form.isNonpayment << .nonpayment) options.originalWarrant
            )
                || (options.originalWarrant == Nothing && form.isNonpayment /= Nothing)
    in
    column [ width fill ]
        [ viewField
            { tooltip = Just NonpaymentInfo
            , currentTooltip = options.tooltip
            , description = "People can be evicted for a number of reasons, including non-payment of rent. We want to know if people are being evicted for this reason because those cases should go to the diversionary court. We assume cases that request $$ are for non-payment but this box is sometimes checked on eviction forms."
            , children =
                [ column [ spacing 5, width fill ]
                    [ el [] (text "Is nonpayment?")
                    , Dropdown.view (nonpaymentDropdownConfig (withChanges hasChanges [])) { options = DetainerWarrant.ternaryOptions, selectedOption = Just form.isNonpayment } form.nonpaymentDropdown
                        |> el []
                    ]
                ]
            }
        ]


requiredLabel labelFn str =
    labelFn [] (row [ spacing 5 ] [ text str, requiredStar ])


viewAddress : FormOptions -> Form -> Element Msg
viewAddress options form =
    let
        hasChanges =
            (Maybe.withDefault False <|
                Maybe.map ((/=) form.address << .address) <|
                    Maybe.andThen (List.head << .defendants) options.originalWarrant
            )
                || (options.originalWarrant == Nothing && form.address /= "")
    in
    row [ width (fill |> maximum 800) ]
        [ viewField
            { tooltip = Just AddressInfo
            , currentTooltip = options.tooltip
            , description = "The address where the defendant or defendants reside."
            , children =
                [ textInput (withValidation DefendantAddress options.problems (withChanges hasChanges []))
                    { onChange = ChangedAddress
                    , text = form.address
                    , label = requiredLabel Input.labelAbove "Defendant Address"
                    , placeholder = Just <| Input.placeholder [] (text "123 Street Address, City, Zip Code")
                    }
                ]
            }
        ]


textInput attrs config =
    Input.text ([ Border.color Palette.grayLight ] ++ attrs) config


viewFirstName : FormOptions -> Int -> DefendantForm -> Element Msg
viewFirstName options index defendant =
    let
        hasChanges =
            (Maybe.withDefault False <|
                Maybe.map ((/=) defendant.firstName << .firstName) <|
                    Maybe.andThen (List.head << .defendants) options.originalWarrant
            )
                || (options.originalWarrant == Nothing && defendant.firstName /= "")
    in
    column [ width fill ]
        [ viewField
            { tooltip = Nothing
            , description = ""
            , currentTooltip = Nothing
            , children =
                [ textInput (withValidation (DefendantFirstName index) options.problems (withChanges hasChanges []))
                    { onChange = ChangedFirstName index
                    , text = defendant.firstName
                    , label = requiredLabel Input.labelAbove "First Name"
                    , placeholder = Nothing
                    }
                ]
            }
        ]


viewMiddleName : FormOptions -> Int -> DefendantForm -> Element Msg
viewMiddleName options index defendant =
    let
        hasChanges =
            (Maybe.withDefault False <|
                Maybe.map ((/=) defendant.middleName) <|
                    Maybe.andThen .middleName <|
                        Maybe.andThen (List.head << .defendants) options.originalWarrant
            )
                || (options.originalWarrant == Nothing && defendant.middleName /= "")
    in
    column [ width fill ]
        [ viewField
            { tooltip = Nothing
            , description = ""
            , currentTooltip = Nothing
            , children =
                [ textInput (withChanges hasChanges [])
                    { onChange = ChangedMiddleName index
                    , text = defendant.middleName
                    , label = Input.labelAbove [] (text "Middle Name")
                    , placeholder = Nothing
                    }
                ]
            }
        ]


viewLastName : FormOptions -> Int -> DefendantForm -> Element Msg
viewLastName options index defendant =
    let
        hasChanges =
            (Maybe.withDefault False <|
                Maybe.map ((/=) defendant.lastName << .lastName) <|
                    Maybe.andThen (List.head << .defendants) options.originalWarrant
            )
                || (options.originalWarrant == Nothing && defendant.lastName /= "")
    in
    column [ width fill ]
        [ viewField
            { tooltip = Nothing
            , description = ""
            , currentTooltip = Nothing
            , children =
                [ textInput (withValidation (DefendantLastName index) options.problems (withChanges hasChanges []))
                    { onChange = ChangedLastName index
                    , text = defendant.lastName
                    , label =
                        requiredLabel Input.labelAbove "Last Name"
                    , placeholder = Nothing
                    }
                ]
            }
        ]


viewSuffix : FormOptions -> Int -> DefendantForm -> Element Msg
viewSuffix options index defendant =
    let
        hasChanges =
            (Maybe.withDefault False <|
                Maybe.map ((/=) defendant.suffix) <|
                    Maybe.andThen .suffix <|
                        Maybe.andThen (List.head << .defendants) options.originalWarrant
            )
                || (options.originalWarrant == Nothing && defendant.suffix /= "")
    in
    column [ width (fill |> maximum 100) ]
        [ viewField
            { tooltip = Nothing
            , description = ""
            , currentTooltip = Nothing
            , children =
                [ textInput (withChanges hasChanges [])
                    { onChange = ChangedSuffix index
                    , text = defendant.suffix
                    , label = Input.labelAbove [] (text "Suffix")
                    , placeholder = Nothing
                    }
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

                    hasChanges =
                        (Maybe.withDefault False <|
                            Maybe.map ((/=) phone) <|
                                originalPhone
                        )
                            || (options.originalWarrant == Nothing && defendant.potentialPhones /= [ "" ])
                            || (options.originalWarrant /= Nothing && i >= (Maybe.withDefault 0 <| Maybe.map List.length originalPhones))
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
                    [ viewField
                        { tooltip =
                            if i == 0 then
                                Just <| PotentialPhoneNumbersInfo index

                            else
                                Nothing
                        , currentTooltip = options.tooltip
                        , description = "Provide a phone number for the tenant so they will be called and texted during upcoming phonebanks and receive notifications about their detainer warrant updates."
                        , children =
                            [ textInput (withValidation (DefendantPhoneNumber index i) options.problems (withChanges hasChanges []))
                                { onChange = ChangedPotentialPhones index i
                                , text = phone
                                , label =
                                    if i == 0 then
                                        Input.labelLeft [ paddingXY 5 0 ] (text "Potential Phone Numbers")

                                    else
                                        Input.labelHidden "Potential Phone"
                                , placeholder = Just <| Input.placeholder [] (text "123-456-7890")
                                }
                            , if i == 0 then
                                Element.none

                              else
                                Input.button
                                    [ padding 2
                                    , Element.alignTop
                                    , Font.color Palette.sred
                                    , Border.color Palette.sred
                                    , Border.width 1
                                    ]
                                    { onPress = Just <| RemovePhone index i
                                    , label =
                                        Element.el
                                            [ width shrink
                                            , height shrink
                                            , padding 0
                                            ]
                                            (Element.html (FeatherIcons.x |> FeatherIcons.withSize 16 |> FeatherIcons.toHtml []))
                                    }
                            ]
                        }
                    ]
            )
            defendant.potentialPhones
            ++ [ Input.button primaryStyles { onPress = Just <| AddPhone index, label = Element.el [ width shrink, height shrink ] (Element.html (FeatherIcons.plus |> FeatherIcons.withSize 15 |> FeatherIcons.toHtml [])) } ]
        )


viewDefendantForm : FormOptions -> Int -> DefendantForm -> Element Msg
viewDefendantForm options index defendant =
    column
        [ width fill
        , spacing 10
        , padding 20
        , Border.width 1
        , Border.color Palette.grayLight
        , Border.innerGlow Palette.grayLightest 2
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
                ++ [ Input.button (primaryStyles ++ [ Element.alignRight ]) { onPress = Just AddDefendant, label = text "Add Defendant" } ]
            )
        ]


viewJudgements : FormOptions -> Form -> Element Msg
viewJudgements options form =
    column [ centerX, spacing 20, width (fill |> maximum 1000), padding 10 ]
        (List.indexedMap (viewJudgement options) form.judgements
            ++ [ Input.button
                    (primaryStyles
                        ++ [ if List.isEmpty form.judgements then
                                Element.centerX

                             else
                                Element.alignRight
                           ]
                    )
                    { onPress = Just AddJudgement, label = text "Add Judgement" }
               ]
        )


viewJudgementInterest : FormOptions -> Int -> JudgementForm -> Element Msg
viewJudgementInterest options index form =
    column []
        [ row [ spacing 5 ]
            [ viewField
                { tooltip = Just (JudgementInfo index FeesHaveInterestInfo)
                , currentTooltip = options.tooltip
                , description = "Do the fees claimed have interest?"
                , children =
                    [ column [ spacing 5, width fill ]
                        [ Input.checkbox
                            []
                            { onChange = ToggleJudgmentInterest index
                            , icon = Input.defaultCheckbox
                            , checked = form.hasInterest
                            , label = Input.labelAbove [] (text "Fees Have Interest")
                            }
                        ]
                    ]
                }
            , if form.hasInterest then
                viewField
                    { tooltip = Just (JudgementInfo index InterestRateFollowsSiteInfo)
                    , currentTooltip = options.tooltip
                    , description = "Does the interest rate follow from the website?"
                    , children =
                        [ column [ spacing 5, width fill ]
                            [ Input.checkbox
                                []
                                { onChange = ToggleInterestFollowSite index
                                , icon = Input.defaultCheckbox
                                , checked = form.interestFollowsSite
                                , label = Input.labelAbove [] (text "Interest Rate Follows Site")
                                }
                            ]
                        ]
                    }

              else
                Element.none
            ]
        , if form.interestFollowsSite then
            Element.none

          else
            viewField
                { tooltip = Just (JudgementInfo index InterestRateInfo)
                , currentTooltip = options.tooltip
                , description = "The rate of interest that accrues for fees."
                , children =
                    [ column [ spacing 5, width fill ]
                        [ textInput (withChanges False [ Events.onLoseFocus (ConfirmedInterestRate index) ])
                            { onChange = ChangedInterestRate index
                            , text = form.interestRate
                            , label = Input.labelAbove [] (text "Interest Rate")
                            , placeholder = Just <| Input.placeholder [] (text "0%")
                            }
                        ]
                    ]
                }
        ]


viewJudgementPossession : FormOptions -> Int -> JudgementForm -> Element Msg
viewJudgementPossession options index form =
    viewField
        { tooltip = Just (JudgementInfo index PossessionClaimedInfo)
        , currentTooltip = options.tooltip
        , description = "Has the Plaintiff claimed the residence?"
        , children =
            [ column [ spacing 5, width fill ]
                [ Input.checkbox
                    []
                    { onChange = ToggleJudgmentPossession index
                    , icon = Input.defaultCheckbox
                    , checked = form.claimsPossession
                    , label = Input.labelAbove [] (text "Possession Claimed")
                    }
                ]
            ]
        }


viewJudgementPlaintiff : FormOptions -> Int -> JudgementForm -> List (Element Msg)
viewJudgementPlaintiff options index form =
    [ viewField
        { tooltip = Just (JudgementInfo index FeesClaimedInfo)
        , currentTooltip = options.tooltip
        , description = "Fees the Plaintiff has claimed."
        , children =
            [ column [ spacing 5, width fill ]
                [ textInput (withChanges False [ Events.onLoseFocus (ConfirmedFeesClaimed index) ])
                    { onChange = ChangedFeesClaimed index
                    , text =
                        if form.claimsFees == "" then
                            form.claimsFees

                        else
                            "$" ++ form.claimsFees
                    , label = Input.labelAbove [] (text "Fees Claimed")
                    , placeholder = Just <| Input.placeholder [] (text "$0.00")
                    }
                ]
            ]
        }
    , viewJudgementPossession options index form
    ]


viewJudgementDefendant : FormOptions -> Int -> JudgementForm -> List (Element Msg)
viewJudgementDefendant options index form =
    [ viewField
        { tooltip = Just (JudgementInfo index DismissalBasisInfo)
        , currentTooltip = options.tooltip
        , description = "Why is the case being dismissed?"
        , children =
            [ column [ spacing 5, width (fill |> minimum 350) ]
                [ el [] (text "Basis for dismissal")
                , Dropdown.view (dismissalBasisDropdownConfig index [])
                    { options = DetainerWarrant.dismissalBasisOptions
                    , selectedOption = Just form.dismissalBasis
                    }
                    form.dismissalBasisDropdown
                    |> el [ width fill ]
                ]
            ]
        }
    , viewField
        { tooltip = Just (JudgementInfo index WithPrejudiceInfo)
        , currentTooltip = options.tooltip
        , description = "Whether or not the dismissal is made with prejudice."
        , children =
            [ row [ spacing 5, width fill ]
                [ Input.checkbox
                    []
                    { onChange = ToggledWithPrejudice index
                    , icon = Input.defaultCheckbox
                    , checked = form.withPrejudice
                    , label = Input.labelRight [] (text "Dismissal is with prejudice")
                    }
                ]
            ]
        }
    ]


viewJudgement : FormOptions -> Int -> JudgementForm -> Element Msg
viewJudgement options index form =
    let
        hasChanges =
            True

        -- (Maybe.withDefault False <|
        --     Maybe.map ((/=) form.judgement << .judgement) options.originalWarrant
        -- )
        --     || (options.originalWarrant == Nothing && form.judgement /= defaultCategory)
    in
    column
        [ width fill
        , spacing 10
        , padding 20
        , Border.width 1
        , Border.color Palette.grayLight
        , Border.innerGlow Palette.grayLightest 2
        , Border.rounded 5
        , inFront
            (row [ Element.alignRight, padding 20 ]
                [ Input.button primaryStyles
                    { onPress = Just (RemoveJudgement index)
                    , label =
                        Element.el
                            [ width shrink
                            , height shrink
                            , padding 0
                            ]
                            (Element.html (FeatherIcons.x |> FeatherIcons.withSize 16 |> FeatherIcons.toHtml []))
                    }
                ]
            )
        ]
        [ row
            [ spacing 5
            ]
            [ viewField
                { tooltip = Just (JudgementInfo index JudgementFileDateDetail)
                , currentTooltip = options.tooltip
                , description = "The date this judgement was filed."
                , children =
                    [ DatePicker.input
                        (withValidation
                            (ValidJudgement index JudgementFileDate)
                            options.problems
                            (withChanges
                                hasChanges
                                [ Element.htmlAttribute (Html.Attributes.id (judgementInfoText index JudgementFileDateDetail))
                                , centerX
                                , Element.centerY
                                , Border.color Palette.grayLight
                                ]
                            )
                        )
                        { onChange = ChangedJudgementFileDatePicker index
                        , selected = form.fileDate.date
                        , text = form.fileDate.dateText
                        , label =
                            requiredLabel Input.labelAbove "File Date"
                        , placeholder =
                            Maybe.map (Input.placeholder [] << text << Date.toIsoString) options.today
                        , settings = DatePicker.defaultSettings
                        , model = form.fileDate.pickerModel
                        }
                    ]
                }
            , viewField
                { tooltip = Just (JudgementInfo index Summary)
                , currentTooltip = options.tooltip
                , description = "The ruling from the court that will determine if fees or repossession are enforced."
                , children =
                    [ column [ spacing 5, width fill ]
                        [ el [] (text "Granted to")
                        , Dropdown.view (conditionsDropdownConfig index [])
                            { options = DetainerWarrant.conditionsOptions
                            , selectedOption = Just form.condition
                            }
                            form.conditionsDropdown
                            |> el []
                        ]
                    ]
                }
            ]
        , row [ spacing 5 ]
            (case form.condition of
                PlaintiffOption ->
                    viewJudgementPlaintiff options index form

                DefendantOption ->
                    viewJudgementDefendant options index form
            )
        , if form.claimsFees /= "" && form.condition == PlaintiffOption then
            viewJudgementInterest options index form

          else
            Element.none
        , viewJudgementNotes options index form
        ]


viewJudgementNotes : FormOptions -> Int -> JudgementForm -> Element Msg
viewJudgementNotes options index form =
    let
        hasChanges =
            (options.originalWarrant
                |> Maybe.map (List.take index << .judgements)
                |> Maybe.andThen List.head
                |> Maybe.andThen .notes
                |> Maybe.map ((/=) form.notes)
                |> Maybe.withDefault False
            )
                || (options.originalWarrant == Nothing && form.notes /= "")
    in
    column [ width fill ]
        [ viewField
            { tooltip = Just (JudgementInfo index JudgementNotesDetail)
            , currentTooltip = options.tooltip
            , description = "Any additional notes you have about this particular judgement go here!"
            , children =
                [ Input.multiline (withChanges hasChanges [])
                    { onChange = ChangedJudgementNotes index
                    , text = form.notes
                    , label = Input.labelAbove [] (text "Notes")
                    , placeholder = Just <| Input.placeholder [] (text "Add any notes from the judgement sheet or any comments you think is noteworthy.")
                    , spellcheck = True
                    }
                ]
            }
        ]


viewNotes : FormOptions -> Form -> Element Msg
viewNotes options form =
    let
        hasChanges =
            (Maybe.withDefault False <|
                Maybe.map ((/=) form.notes) <|
                    Maybe.andThen .notes options.originalWarrant
            )
                || (options.originalWarrant == Nothing && form.notes /= "")
    in
    column [ width fill ]
        [ viewField
            { tooltip = Just NotesInfo
            , currentTooltip = options.tooltip
            , description = "Any additional notes you have about this case go here! This is a great place to leave feedback for the form as well, perhaps there's another field or field option we need to provide."
            , children =
                [ Input.multiline (withChanges hasChanges [])
                    { onChange = ChangedNotes
                    , text = form.notes
                    , label = Input.labelAbove [] (text "Notes")
                    , placeholder = Just <| Input.placeholder [] (text "Add anything you think is noteworthy.")
                    , spellcheck = True
                    }
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
        , Border.color Palette.grayLight
        , Border.width 1
        , Border.shadow { offset = ( 0, 10 ), size = 1, blur = 30, color = Palette.grayLight }
        ]
        groups


primaryStyles : List (Element.Attr () msg)
primaryStyles =
    [ Background.color Palette.sred
    , Font.color Palette.white
    , Font.size 20
    , padding 10
    , Border.rounded 3
    ]


submitAndAddAnother : Element Msg
submitAndAddAnother =
    Input.button
        [ Background.color Palette.redLightest
        , Font.color Palette.sred
        , padding 10
        , Border.rounded 3
        , Border.width 1
        , Border.color Palette.sred
        , Font.size 22
        ]
        { onPress = Just SubmitAndAddAnother, label = text "Submit and add another" }


submitButton : Element Msg
submitButton =
    Input.button
        (primaryStyles ++ [ Font.size 22 ])
        { onPress = Just SubmitForm, label = text "Submit" }


viewForm : FormOptions -> FormStatus -> Element Msg
viewForm options formStatus =
    case formStatus of
        Initializing ->
            column [] [ text "Initializing" ]

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
                        [ viewPlaintiffSearch options form
                        , viewPlaintiffAttorneySearch options form
                        ]
                    , formGroup
                        [ viewCourtDate options form
                        , viewCourtroom options form
                        , viewPresidingJudgeSearch options form
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
                    [ paragraph [ Font.center, centerX ] [ text "Judgements" ]
                    , viewJudgements options form
                    ]
                , tile
                    [ viewNotes options form
                    ]
                , row [ Element.alignRight, spacing 10 ]
                    [ submitAndAddAnother
                    , submitButton
                    ]
                ]


formOptions : Model -> FormOptions
formOptions model =
    { plaintiffs = model.plaintiffs
    , attorneys = model.attorneys
    , judges = model.judges
    , courtrooms = model.courtrooms
    , tooltip = model.tooltip
    , docketId = model.docketId
    , today = model.today
    , problems = model.problems
    , originalWarrant = model.warrant
    }


viewProblem : Problem -> Element Msg
viewProblem problem =
    paragraph []
        [ case problem of
            InvalidEntry _ value ->
                Element.none

            ServerError err ->
                text ("something went wrong: " ++ err)
        ]


viewProblems : List Problem -> Element Msg
viewProblems problems =
    row [] [ column [] (List.map viewProblem problems) ]


viewTooltip : String -> Element Msg
viewTooltip str =
    textColumn
        [ width (fill |> maximum 600)
        , padding 10
        , Background.color Palette.red
        , Font.color Palette.white
        , Border.rounded 3
        , Font.size 14
        , Border.shadow
            { offset = ( 0, 3 ), blur = 6, size = 0, color = Element.rgba 0 0 0 0.32 }
        ]
        [ paragraph [] [ text str ] ]


withTooltip : Tooltip -> Maybe Tooltip -> String -> List (Element.Attribute Msg)
withTooltip candidate active str =
    if Just candidate == active then
        [ below (viewTooltip str) ]

    else
        []


view : Settings -> Model -> { title : String, content : Element Msg }
view settings model =
    { title = "Organize - Detainer Warrant - Edit"
    , content =
        row
            [ centerX
            , padding 20
            , Font.size 20
            , width (fill |> maximum 1200 |> minimum 400)
            , Element.inFront
                (Input.button
                    (primaryStyles
                        ++ [ Font.size 14
                           , Element.alignRight
                           , Element.alignTop
                           , Events.onLoseFocus CloseTooltip
                           ]
                        ++ withTooltip DetainerWarrantInfo model.tooltip "In some states, such as Tennessee, when a property owner wants to evict a tenant, he must first give notice, known as a detainer warrant. A detainer warrant is not the same as an arrest warrant, however. It is the document that informs the tenant about the court date set in the eviction proceeding. The notification gives the tenant the opportunity to appear in court and tell the judge her side of the story."
                    )
                    { onPress = Just (ChangeTooltip DetainerWarrantInfo), label = text "What is a Detainer Warrant?" }
                )
            ]
            [ column [ centerX, spacing 10 ]
                [ row
                    [ width fill
                    ]
                    [ column [ centerX, width (px 300) ]
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
                , viewProblems model.problems
                , row [ width fill ]
                    [ viewForm (formOptions model) model.form
                    ]
                ]
            ]
    }


subscriptions : Model -> Sub Msg
subscriptions model =
    case model.form of
        Initializing ->
            Sub.none

        Ready form ->
            Sub.batch
                ([ Dropdown.onOutsideClick form.statusDropdown StatusDropdownMsg
                 , Dropdown.onOutsideClick form.categoryDropdown CategoryDropdownMsg

                 --  , Dropdown.onOutsideClick form.conditionsDropdown ConditionsDropdownMsg
                 ]
                    ++ Maybe.withDefault [] (Maybe.map (List.singleton << onOutsideClick) model.tooltip)
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


judgementInfoText : Int -> JudgementDetail -> String
judgementInfoText index detail =
    "judgement-"
        ++ (case detail of
                JudgementFileDateDetail ->
                    "file-date-detail"

                Summary ->
                    "summary"

                FeesClaimedInfo ->
                    "fees-claimed-info"

                PossessionClaimedInfo ->
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

                JudgementNotesDetail ->
                    "notes-detail"
           )
        ++ "-"
        ++ String.fromInt index


tooltipToString : Tooltip -> String
tooltipToString tip =
    case tip of
        DetainerWarrantInfo ->
            "detainer-warrant-info"

        DocketIdInfo ->
            "docket-id-info"

        FileDateInfo ->
            "file-date-info"

        StatusInfo ->
            "status-info"

        PlaintiffInfo ->
            "plaintiff-info"

        PlaintiffAttorneyInfo ->
            "plaintiff-attorney-info"

        CourtDateInfo ->
            "court-date-info"

        CourtroomInfo ->
            "courtroom-info"

        PresidingJudgeInfo ->
            "presiding-judge-info"

        AmountClaimedInfo ->
            "amount-claimed-info"

        AmountClaimedCategoryInfo ->
            "amount-claimed-category-info"

        CaresInfo ->
            "cares-info"

        LegacyInfo ->
            "legacy-info"

        NonpaymentInfo ->
            "nonpayment-info"

        AddressInfo ->
            "address-info"

        PotentialPhoneNumbersInfo index ->
            "potential-phone-numbers-info-" ++ String.fromInt index

        JudgementInfo index detail ->
            judgementInfoText index detail

        NotesInfo ->
            "notes-info"



-- EXPORT


toSession : Model -> Session
toSession model =
    model.session



-- FORM


{-| Marks that we've trimmed the form's fields, so we don't accidentally send
it to the server without having trimmed it!
-}
type TrimmedForm
    = Trimmed Form


type JudgementValidation
    = JudgementFileDate


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
    | ValidJudgement Int JudgementValidation


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
        Initializing ->
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
                case Date.fromIsoString form.fileDate.dateText of
                    Ok _ ->
                        []

                    Err errorStr ->
                        [ errorStr ]

            CourtDate ->
                if String.isEmpty form.courtDate.dateText then
                    []

                else
                    case Date.fromIsoString form.courtDate.dateText of
                        Ok _ ->
                            []

                        Err errorStr ->
                            [ errorStr ]

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

            ValidJudgement index judgementValidation ->
                case List.head <| List.take index form.judgements of
                    Just judgement ->
                        case judgementValidation of
                            JudgementFileDate ->
                                if Date.compare (Maybe.withDefault today judgement.fileDate.date) (Maybe.withDefault today form.fileDate.date) == LT then
                                    [ "Judgement cannot be filed before detainer warrant." ]

                                else
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
    , judge : Maybe Judge
    , courtroom : Maybe Courtroom
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
        , fileDate = Maybe.withDefault (Date.toIsoString today) <| Maybe.map Date.toIsoString form.fileDate.date
        , status = form.status
        , plaintiff = Maybe.map (related << .id) form.plaintiff.person
        , plaintiffAttorney = Maybe.map (related << .id) form.plaintiffAttorney.person
        , courtDate = Maybe.map Date.toIsoString form.courtDate.date
        , courtroom = Maybe.map (related << .id) form.courtroom.selection
        , presidingJudge = Maybe.map (related << .id) form.presidingJudge.person
        , isCares = form.isCares
        , isLegacy = form.isLegacy
        , nonpayment = form.isNonpayment
        , amountClaimed = String.toFloat <| String.replace "," "" form.amountClaimed
        , amountClaimedCategory = form.amountClaimedCategory
        , defendants = List.filterMap (Maybe.map related << .id) form.defendants
        , judgements = List.map (DetainerWarrant.editFromForm today) form.judgements
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
    , judge =
        form.presidingJudge.person
    , courtroom =
        form.courtroom.selection
    }


conditional fieldName fn field =
    Maybe.withDefault [] <| Maybe.map (\f -> [ ( fieldName, fn f ) ]) field


nullable fieldName fn field =
    Maybe.withDefault [ ( fieldName, Encode.null ) ] <| Maybe.map (\f -> [ ( fieldName, fn f ) ]) field


toBody data =
    Encode.object [ ( "data", data ) ]
        |> Http.jsonBody


upsertDefendant : Maybe Cred -> Int -> Defendant -> Cmd Msg
upsertDefendant maybeCred index form =
    let
        decoder =
            Api.itemDecoder Defendant.decoder

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
            Api.patch (Endpoint.defendant id) maybeCred body (UpsertedDefendant index) decoder

        Nothing ->
            Api.post (Endpoint.defendants []) maybeCred body (UpsertedDefendant index) decoder


upsertCourtroom : Maybe Cred -> Courtroom -> Cmd Msg
upsertCourtroom maybeCred courtroom =
    let
        decoder =
            Api.itemDecoder DetainerWarrant.courtroomDecoder

        data =
            Encode.object
                ([ ( "name", Encode.string courtroom.name )
                 , defaultDistrict
                 ]
                    ++ conditional "id" Encode.int (remoteId courtroom)
                )

        body =
            toBody data
    in
    case remoteId courtroom of
        Just id ->
            Api.patch (Endpoint.courtroom id) maybeCred body UpsertedCourtroom decoder

        Nothing ->
            Api.post (Endpoint.courtrooms []) maybeCred body UpsertedCourtroom decoder


upsertJudge : Maybe Cred -> Judge -> Cmd Msg
upsertJudge maybeCred form =
    let
        decoder =
            Api.itemDecoder DetainerWarrant.judgeDecoder

        judge =
            Encode.object
                ([ ( "name", Encode.string form.name )
                 , defaultDistrict
                 ]
                    ++ conditional "id" Encode.int (remoteId form)
                )

        body =
            toBody judge
    in
    case remoteId form of
        Just id ->
            Api.patch (Endpoint.judge id) maybeCred body UpsertedJudge decoder

        Nothing ->
            Api.post (Endpoint.judges []) maybeCred body UpsertedJudge decoder


remoteId : { a | id : number } -> Maybe number
remoteId resource =
    if resource.id == -1 then
        Nothing

    else
        Just resource.id


upsertAttorney : Maybe Cred -> Attorney -> Cmd Msg
upsertAttorney maybeCred attorney =
    let
        decoder =
            Api.itemDecoder DetainerWarrant.attorneyDecoder

        data =
            Encode.object
                ([ ( "name", Encode.string attorney.name )
                 , defaultDistrict
                 ]
                    ++ conditional "id" Encode.int (remoteId attorney)
                )

        body =
            toBody data
    in
    case remoteId attorney of
        Just id ->
            Api.patch (Endpoint.attorney id) maybeCred body UpsertedAttorney decoder

        Nothing ->
            Api.post (Endpoint.attorneys []) maybeCred body UpsertedAttorney decoder


defaultDistrict =
    ( "district_id", Encode.int 1 )


upsertPlaintiff : Maybe Cred -> Plaintiff -> Cmd Msg
upsertPlaintiff maybeCred plaintiff =
    let
        decoder =
            Api.itemDecoder DetainerWarrant.plaintiffDecoder

        data =
            Encode.object
                ([ ( "name", Encode.string plaintiff.name )
                 , defaultDistrict
                 ]
                    ++ conditional "id" Encode.int (remoteId plaintiff)
                )

        body =
            toBody data
    in
    case remoteId plaintiff of
        Just id ->
            Api.patch (Endpoint.plaintiff id) maybeCred body UpsertedPlaintiff decoder

        Nothing ->
            Api.post (Endpoint.plaintiffs []) maybeCred body UpsertedPlaintiff decoder


encodeRelated record =
    Encode.object [ ( "id", Encode.int record.id ) ]


encodeJudgement : JudgementEdit -> Encode.Value
encodeJudgement judgement =
    Encode.object
        ([ ( "in_favor_of", Encode.string judgement.inFavorOf )
         , ( "interest", Encode.bool judgement.hasInterest )
         , ( "file_date", Encode.string judgement.fileDate )
         ]
            ++ nullable "id" Encode.int judgement.id
            ++ nullable "notes" Encode.string judgement.notes
            ++ nullable "entered_by" Encode.string judgement.enteredBy
            ++ nullable "claims_fees" Encode.float judgement.claimsFees
            ++ nullable "claims_possession" Encode.bool judgement.claimsPossession
            ++ nullable "interest_rate" Encode.float judgement.interestRate
            ++ nullable "interest_follows_site" Encode.bool judgement.interestFollowsSite
            ++ nullable "dismissal_basis" Encode.string judgement.dismissalBasis
            ++ nullable "with_prejudice" Encode.bool judgement.withPrejudice
        )


updateDetainerWarrant : Maybe Cred -> DetainerWarrantEdit -> Cmd Msg
updateDetainerWarrant maybeCred form =
    let
        detainerWarrant =
            Encode.object
                ([ ( "docket_id", Encode.string form.docketId )
                 , ( "file_date", Encode.string form.fileDate )
                 , ( "status", Encode.string (DetainerWarrant.statusText form.status) )
                 , ( "defendants", Encode.list encodeRelated form.defendants )
                 , ( "amount_claimed_category", Encode.string (DetainerWarrant.amountClaimedCategoryText form.amountClaimedCategory) )
                 , ( "judgements", Encode.list encodeJudgement form.judgements )
                 ]
                    ++ nullable "plaintiff" encodeRelated form.plaintiff
                    ++ nullable "plaintiff_attorney" encodeRelated form.plaintiffAttorney
                    ++ nullable "court_date" Encode.string form.courtDate
                    ++ nullable "courtroom" encodeRelated form.courtroom
                    ++ nullable "presiding_judge" encodeRelated form.presidingJudge
                    ++ nullable "is_cares" Encode.bool form.isCares
                    ++ nullable "is_legacy" Encode.bool form.isLegacy
                    ++ nullable "nonpayment" Encode.bool form.nonpayment
                    ++ nullable "amount_claimed" Encode.float form.amountClaimed
                    ++ nullable "notes" Encode.string form.notes
                )
    in
    Api.itemDecoder DetainerWarrant.decoder
        |> Api.patch (Endpoint.detainerWarrant form.docketId) maybeCred (toBody detainerWarrant) CreatedDetainerWarrant
