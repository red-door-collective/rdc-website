module Page.Organize.DetainerWarrantCreation exposing (Model, Msg, init, subscriptions, toSession, update, view)

import Api exposing (Cred)
import Api.Endpoint as Endpoint
import Campaign exposing (Campaign)
import Color
import Date exposing (Date)
import DatePicker exposing (ChangeEvent(..))
import Defendant exposing (Defendant)
import DetainerWarrant exposing (AmountClaimedCategory, Attorney, DetainerWarrant, Judge, Judgement, Plaintiff, Status)
import Dropdown
import Element exposing (Element, centerX, column, el, fill, height, image, link, maximum, minimum, padding, paragraph, px, row, spacing, text, textColumn, width, wrappedRow)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Input as Input
import FeatherIcons
import Html.Events
import Http
import Json.Decode as Decode
import Maybe.Extra
import Palette
import Route
import SearchBox
import Session exposing (Session)
import Settings exposing (Settings)
import Task
import User exposing (User)
import Widget
import Widget.Icon


type alias DefendantForm =
    { id : Maybe Int
    , firstName : String
    , middleName : String
    , lastName : String
    , suffix : String
    , potentialPhones : String
    }


type alias DatePickerState =
    { date : Maybe Date
    , dateText : String
    , pickerModel : DatePicker.Model
    }


type alias FormOptions =
    { plaintiffs : List Plaintiff
    , attorneys : List Attorney
    , judges : List Judge
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


type alias Form =
    { docketId : String
    , fileDate : DatePickerState
    , status : Status
    , statusDropdown : Dropdown.State String
    , plaintiff : PlaintiffForm
    , plaintiffAttorney : AttorneyForm
    , courtDate : DatePickerState
    , courtroom : String
    , presidingJudge : JudgeForm
    , isCares : Maybe Bool
    , isLegacy : Maybe Bool
    , isNonpayment : Maybe Bool
    , amountClaimed : String
    , amountClaimedCategory : Maybe AmountClaimedCategory
    , categoryDropdown : Dropdown.State String
    , address : String
    , defendants : List DefendantForm
    , judgement : Maybe Judgement
    , judgementDropdown : Dropdown.State String
    , notes : String
    }


type alias FormData =
    { fileDate : Float
    , status : String
    , plaintiffId : Maybe Int
    , plaintiffAttorneyId : Maybe Int
    , courtDate : String
    , courtroom : String
    , presidingJudgeId : Maybe Int
    , isCares : Maybe Bool
    , isLegacy : Maybe Bool
    , isNonpayment : Maybe Bool
    , amountClaimed : Maybe String
    , amountClaimedCategory : Maybe String
    , address : String
    , defendantIds : List Int
    , judgement : Maybe String
    , notes : String
    }


type ApiForm
    = CreateNew FormData
    | EditExisting FormData


type Problem
    = InvalidEntry ValidatedField String
    | ServerError String


type alias Model =
    { session : Session
    , warrant : Maybe DetainerWarrant
    , docketId : Maybe String
    , problems : List Problem
    , form : FormStatus
    , plaintiffs : List Plaintiff
    , attorneys : List Attorney
    , judges : List Judge
    }


initDatePicker : DatePickerState
initDatePicker =
    { date = Nothing
    , dateText = ""
    , pickerModel = DatePicker.init
    }


initPlaintiffForm : PlaintiffForm
initPlaintiffForm =
    { person = Nothing
    , text = ""
    , searchBox = SearchBox.init
    }


initAttorneyForm : AttorneyForm
initAttorneyForm =
    { person = Nothing
    , text = ""
    , searchBox = SearchBox.init
    }


initJudgeForm : JudgeForm
initJudgeForm =
    { person = Nothing
    , text = ""
    , searchBox = SearchBox.init
    }


initDefendantForm : DefendantForm
initDefendantForm =
    { id = Nothing
    , firstName = ""
    , middleName = ""
    , lastName = ""
    , suffix = ""
    , potentialPhones = ""
    }


initCreate : Form
initCreate =
    { docketId = ""
    , fileDate = initDatePicker
    , status = DetainerWarrant.Pending
    , statusDropdown = Dropdown.init "status-dropdown"
    , plaintiff = initPlaintiffForm
    , plaintiffAttorney = initAttorneyForm
    , courtDate = initDatePicker
    , courtroom = ""
    , presidingJudge = initJudgeForm
    , isCares = Nothing
    , isLegacy = Nothing
    , isNonpayment = Nothing
    , amountClaimed = ""
    , amountClaimedCategory = Nothing
    , categoryDropdown = Dropdown.init "amount-claimed-category-dropdown"
    , address = ""
    , defendants = [ initDefendantForm ]
    , judgement = Nothing
    , judgementDropdown = Dropdown.init "judgement-dropdown"
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
      , problems = []
      , form =
            case maybeId of
                Just _ ->
                    Initializing

                Nothing ->
                    Ready initCreate
      , plaintiffs = []
      , attorneys = []
      , judges = []
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
    | ChangedDocketId String
    | ChangedFileDatePicker ChangeEvent
    | ChangedCourtDatePicker ChangeEvent
    | ChangedPlaintiffSearchBox (SearchBox.ChangeEvent Plaintiff)
    | ChangedPlaintiffAttorneySearchBox (SearchBox.ChangeEvent Attorney)
    | PickedStatus (Maybe String)
    | DropdownMsg (Dropdown.Msg String)
    | ChangedCourtroom String
    | ChangedJudgeSearchBox (SearchBox.ChangeEvent Judge)
    | PickedAmountClaimedCategory (Maybe String)
    | CategoryDropdownMsg (Dropdown.Msg String)
    | CheckedCares Bool
    | CheckedLegacy Bool
    | CheckedNonpayment Bool
    | ChangedAddress String
    | ChangedFirstName Int String
    | ChangedMiddleName Int String
    | ChangedLastName Int String
    | ChangedSuffix Int String
    | ChangedPotentialPhones Int String
    | AddDefendant
    | PickedJudgement (Maybe String)
    | JudgementDropdownMsg (Dropdown.Msg String)
    | ChangedNotes String
    | SubmitForm
    | CreatedDetainerWarrant (Result Http.Error DetainerWarrant)


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


statusOptions : List String
statusOptions =
    [ "Pending", "Closed" ]


amountClaimedCategoryOptions : List String
amountClaimedCategoryOptions =
    [ "Possession", "Fees", "Both", "Not Applicable" ]


judgementOptions : List String
judgementOptions =
    [ "Non-suit", "POSS", "POSS + Payment", "Dismissed" ]


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GotDetainerWarrant result ->
            case result of
                Ok warrantPage ->
                    ( { model | warrant = Just warrantPage.data }, Cmd.none )

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
                model

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
                                    { plaintiff | person = Just person }
                            in
                            { form | plaintiff = updatedPlaintiff }
                        )
                        model

                SearchBox.TextChanged text ->
                    updateForm
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
                                    { attorney | person = Just person }
                            in
                            { form | plaintiffAttorney = updatedAttorney }
                        )
                        model

                SearchBox.TextChanged text ->
                    updateForm
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
                        | status =
                            case option of
                                Just "Pending" ->
                                    DetainerWarrant.Pending

                                Just "Closed" ->
                                    DetainerWarrant.Closed

                                _ ->
                                    DetainerWarrant.Pending
                    }
                )
                model

        DropdownMsg subMsg ->
            updateFormNarrow
                (\form ->
                    let
                        ( state, cmd ) =
                            Dropdown.update statusDropdownConfig subMsg form.statusDropdown statusOptions
                    in
                    ( { form | statusDropdown = state }, cmd )
                )
                model

        ChangedCourtroom courtroom ->
            updateForm
                (\form ->
                    { form | courtroom = courtroom }
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
                    updateForm
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

        PickedAmountClaimedCategory option ->
            updateForm
                (\form ->
                    { form
                        | amountClaimedCategory =
                            case option of
                                Just "Possession" ->
                                    Just DetainerWarrant.Possession

                                Just "Fees" ->
                                    Just DetainerWarrant.Fees

                                Just "Both" ->
                                    Just DetainerWarrant.Both

                                Just "Not Applicable" ->
                                    Just DetainerWarrant.NotApplicable

                                _ ->
                                    Nothing
                    }
                )
                model

        CategoryDropdownMsg subMsg ->
            updateFormNarrow
                (\form ->
                    let
                        ( state, cmd ) =
                            Dropdown.update categoryDropdownConfig subMsg form.categoryDropdown amountClaimedCategoryOptions
                    in
                    ( { form | categoryDropdown = state }, cmd )
                )
                model

        CheckedCares bool ->
            updateForm
                (\form -> { form | isCares = Just bool })
                model

        CheckedLegacy bool ->
            updateForm
                (\form -> { form | isLegacy = Just bool })
                model

        CheckedNonpayment bool ->
            updateForm
                (\form -> { form | isNonpayment = Just bool })
                model

        ChangedAddress address ->
            updateForm
                (\form -> { form | address = address })
                model

        PickedJudgement option ->
            updateForm
                (\form ->
                    { form
                        | judgement =
                            case option of
                                Just "Non-suit" ->
                                    Just DetainerWarrant.NonSuit

                                Just "POSS" ->
                                    Just DetainerWarrant.Poss

                                Just "POSS + Payment" ->
                                    Just DetainerWarrant.PossAndPayment

                                Just "Dismissed" ->
                                    Just DetainerWarrant.Dismissed

                                _ ->
                                    Nothing
                    }
                )
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

        ChangedPotentialPhones selected phones ->
            updateForm
                (\form ->
                    { form
                        | defendants =
                            List.indexedMap
                                (\index defendant ->
                                    if index == selected then
                                        { defendant | potentialPhones = phones }

                                    else
                                        defendant
                                )
                                form.defendants
                    }
                )
                model

        AddDefendant ->
            updateForm
                (\form -> { form | defendants = form.defendants ++ [ initDefendantForm ] })
                model

        JudgementDropdownMsg subMsg ->
            updateFormNarrow
                (\form ->
                    let
                        ( state, cmd ) =
                            Dropdown.update judgementDropdownConfig subMsg form.judgementDropdown judgementOptions
                    in
                    ( { form | judgementDropdown = state }, cmd )
                )
                model

        ChangedNotes notes ->
            updateForm
                (\form -> { form | notes = notes })
                model

        SubmitForm ->
            let
                maybeCred =
                    Session.cred model.session
            in
            case validate model.form of
                Ok validForm ->
                    ( { model | problems = [] }
                    , Api.put (Endpoint.editDetainerWarrant validForm.docketId) maybeCred validForm CreatedDetainerWarrant DetainerWarrant.decoder
                    )

                Err problems ->
                    ( { model | problems = problems }
                    , Cmd.none
                    )


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


viewDocketId form =
    column [ width fill ]
        [ Input.text []
            { onChange = ChangedDocketId
            , text = form.docketId
            , placeholder = Just (Input.placeholder [] (text "Docket Id"))
            , label = Input.labelHidden "Docket Id"
            }
        ]


viewFileDate form =
    column [ width fill ]
        [ DatePicker.input [ Element.centerX, Element.centerY ]
            { onChange = ChangedFileDatePicker
            , selected = form.fileDate.date
            , text = form.fileDate.dateText
            , label =
                Input.labelHidden "Select File Date"
            , placeholder = Just <| Input.placeholder [] (text "File Date")
            , settings = DatePicker.defaultSettings
            , model = form.fileDate.pickerModel
            }
        ]


statusDropdownConfig : Dropdown.Config String Msg
statusDropdownConfig =
    let
        itemToPrompt item =
            text item

        itemToElement selected highlighted item =
            text item
    in
    Dropdown.basic DropdownMsg PickedStatus itemToPrompt itemToElement


categoryDropdownConfig : Dropdown.Config String Msg
categoryDropdownConfig =
    let
        itemToPrompt item =
            text item

        itemToElement selected highlighted item =
            text item
    in
    Dropdown.basic CategoryDropdownMsg PickedAmountClaimedCategory itemToPrompt itemToElement


judgementDropdownConfig : Dropdown.Config String Msg
judgementDropdownConfig =
    let
        itemToPrompt item =
            text item

        itemToElement selected highlighted item =
            text item
    in
    Dropdown.basic JudgementDropdownMsg PickedJudgement itemToPrompt itemToElement


viewStatus form =
    column [ width fill ]
        [ Dropdown.view statusDropdownConfig form.statusDropdown statusOptions
            |> el []
        ]


viewPlaintiffSearch options form =
    row [ width fill ]
        [ SearchBox.input []
            { onChange = ChangedPlaintiffSearchBox
            , text = form.plaintiff.text
            , selected = form.plaintiff.person
            , options = Just options.plaintiffs
            , label = Input.labelAbove [] (text "Plaintiff")
            , placeholder = Nothing
            , toLabel = \person -> person.name
            , filter = \query option -> True
            , state = form.plaintiff.searchBox
            }
        ]


viewPlaintiffAttorneySearch options form =
    column [ width fill ]
        [ SearchBox.input []
            { onChange = ChangedPlaintiffAttorneySearchBox
            , text = form.plaintiff.text
            , selected = form.plaintiffAttorney.person
            , options = Just options.attorneys
            , label = Input.labelAbove [] (text "Plaintiff Attorney")
            , placeholder = Nothing
            , toLabel = \person -> person.name
            , filter = \query option -> True
            , state = form.plaintiffAttorney.searchBox
            }
        ]


viewCourtDate form =
    column [ width fill ]
        [ DatePicker.input [ Element.centerX, Element.centerY ]
            { onChange = ChangedCourtDatePicker
            , selected = form.courtDate.date
            , text = form.courtDate.dateText
            , label =
                Input.labelHidden "Select Court Date"
            , placeholder = Just <| Input.placeholder [] (text "Court Date")
            , settings = DatePicker.defaultSettings
            , model = form.courtDate.pickerModel
            }
        ]


viewCourtroom form =
    column [ width fill ]
        [ Input.text []
            { onChange = ChangedCourtroom
            , text = form.courtroom
            , label = Input.labelHidden "Courtroom"
            , placeholder = Just <| Input.placeholder [] (text "Courtroom")
            }
        ]


viewPresidingJudgeSearch : FormOptions -> Form -> Element Msg
viewPresidingJudgeSearch options form =
    column [ width fill ]
        [ SearchBox.input []
            { onChange = ChangedJudgeSearchBox
            , text = form.presidingJudge.text
            , selected = form.presidingJudge.person
            , options = Just options.judges
            , label = Input.labelAbove [] (text "Presiding Judge")
            , placeholder = Nothing
            , toLabel = \person -> person.name
            , filter = \query option -> True
            , state = form.presidingJudge.searchBox
            }
        ]


viewAmountClaimed form =
    column [ width fill ]
        [ Input.text []
            { onChange = ChangedCourtroom
            , text = form.amountClaimed
            , label = Input.labelHidden "Amount Claimed"
            , placeholder = Just <| Input.placeholder [] (text "Amount Claimed ($)")
            }
        ]


viewAmountClaimedCategory form =
    column [ width fill ]
        [ Dropdown.view categoryDropdownConfig form.categoryDropdown amountClaimedCategoryOptions
            |> el []
        ]


viewCares : Form -> Element Msg
viewCares form =
    column [ width fill ]
        [ Input.checkbox []
            { onChange = CheckedCares
            , icon = Input.defaultCheckbox
            , checked = Maybe.withDefault False <| form.isCares
            , label =
                Input.labelRight []
                    (text "Is CARES Property?")
            }
        ]


viewLegacy form =
    column [ width fill ]
        [ Input.checkbox []
            { onChange = CheckedLegacy
            , icon = Input.defaultCheckbox
            , checked = Maybe.withDefault False <| form.isLegacy
            , label =
                Input.labelRight []
                    (text "Is L.E.G.A.C.Y. Property?")
            }
        ]


viewNonpayment form =
    column [ width fill ]
        [ Input.checkbox []
            { onChange = CheckedNonpayment
            , icon = Input.defaultCheckbox
            , checked = Maybe.withDefault False <| form.isNonpayment
            , label =
                Input.labelRight []
                    (text "Is Nonpayment?")
            }
        ]


viewAddress form =
    row [ width fill ]
        [ Input.text []
            { onChange = ChangedAddress
            , text = form.address
            , label = Input.labelHidden "Defendant Address"
            , placeholder = Just <| Input.placeholder [] (text "Defendant Address")
            }
        ]


viewDefendantForm : Int -> DefendantForm -> Element Msg
viewDefendantForm index defendant =
    column [ spacing 10 ]
        [ row [ width fill, spacing 10 ]
            [ column [ width fill ]
                [ Input.text []
                    { onChange = ChangedFirstName index
                    , text = defendant.firstName
                    , label = Input.labelHidden "First Name"
                    , placeholder = Just <| Input.placeholder [] (text "First Name")
                    }
                ]
            , column [ width fill ]
                [ Input.text []
                    { onChange = ChangedMiddleName index
                    , text = defendant.middleName
                    , label = Input.labelHidden "Middle Name"
                    , placeholder = Just <| Input.placeholder [] (text "Middle Name")
                    }
                ]
            , column [ width fill ]
                [ Input.text []
                    { onChange = ChangedLastName index
                    , text = defendant.lastName
                    , label = Input.labelHidden "Last Name"
                    , placeholder = Just <| Input.placeholder [] (text "Last Name")
                    }
                ]
            , column [ width (fill |> maximum 100) ]
                [ Input.text []
                    { onChange = ChangedSuffix index
                    , text = defendant.suffix
                    , label = Input.labelHidden "Suffix"
                    , placeholder = Just <| Input.placeholder [] (text "Suffix")
                    }
                ]
            ]
        , row [ width (fill |> maximum 600) ]
            [ Input.text []
                { onChange = ChangedPotentialPhones index
                , text = defendant.potentialPhones
                , label = Input.labelHidden "Potential Phone Numbers"
                , placeholder = Just <| Input.placeholder [] (text "Potential Phones Numbers")
                }
            ]
        ]


viewDefendants form =
    row [ width (fill |> maximum 1000) ]
        [ column [ width fill, spacing 10 ]
            ([ paragraph [ Font.center, centerX ] [ text "Defendants" ] ]
                ++ List.indexedMap viewDefendantForm form.defendants
                ++ [ Input.button [] { onPress = Just AddDefendant, label = text "Add Defendant" } ]
            )
        ]


viewJudgement form =
    column [ width fill ]
        [ Dropdown.view judgementDropdownConfig form.judgementDropdown judgementOptions
            |> el []
        ]


viewNotes form =
    column [ width fill ]
        [ Input.multiline []
            { onChange = ChangedNotes
            , text = form.notes
            , label = Input.labelHidden "Notes"
            , placeholder = Just <| Input.placeholder [] (text "Notes")
            , spellcheck = True
            }
        ]


formGroup : List (Element Msg) -> Element Msg
formGroup group =
    row [ spacing 10, padding 10, width fill ]
        group


viewForm : FormOptions -> FormStatus -> Element Msg
viewForm options formStatus =
    case formStatus of
        Initializing ->
            column [] [ text "Initializing" ]

        Ready form ->
            column [ centerX, spacing 10 ]
                [ formGroup
                    [ viewDocketId form
                    , viewFileDate form
                    , viewStatus form
                    ]
                , formGroup
                    [ viewPlaintiffSearch options form
                    , viewPlaintiffAttorneySearch options form
                    ]
                , formGroup
                    [ viewCourtDate form
                    , viewCourtroom form
                    , viewPresidingJudgeSearch options form
                    ]
                , formGroup
                    [ viewAmountClaimed form
                    , viewAmountClaimedCategory form
                    ]
                , formGroup
                    [ viewCares form
                    , viewLegacy form
                    , viewNonpayment form
                    ]
                , viewAddress form
                , viewDefendants form
                , formGroup
                    [ viewJudgement form
                    , viewNotes form
                    ]
                ]


formOptions model =
    { plaintiffs = model.plaintiffs
    , attorneys = model.attorneys
    , judges = model.judges
    }


view : Settings -> Model -> { title : String, content : Element Msg }
view settings model =
    { title = "Organize - Detainer Warrant - Edit"
    , content =
        row [ centerX, padding 10, Font.size 20, width (fill |> maximum 1000 |> minimum 400) ]
            [ column [ centerX, spacing 10 ]
                [ paragraph [ Font.center, centerX ]
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
                , paragraph [ Font.center, centerX ]
                    [ text "Insert instructions here" ]
                , row [ width fill ]
                    [ viewForm (formOptions model) model.form
                    ]
                ]
            ]
    }


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- EXPORT


toSession : Model -> Session
toSession model =
    model.session



-- FORM


{-| Marks that we've trimmed the form's fields, so we don't accidentally send
it to the server without having trimmed it!
-}
type TrimmedForm
    = Trimmed FormData


{-| When adding a variant here, add it to `fieldsToValidate` too!
-}
type ValidatedField
    = DefendantAddress


fieldsToValidate : List ValidatedField
fieldsToValidate =
    [ DefendantAddress
    ]


{-| Trim the form and validate its fields. If there are problems, report them!
-}
validate : Form -> Result (List Problem) TrimmedForm
validate form =
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
    List.map (InvalidEntry field) <|
        case field of
            DefendantAddress ->
                if String.isEmpty form.address then
                    [ "Defendant Address cannot be blank" ]

                else
                    []


{-| Don't trim while the user is typing! That would be super annoying.
Instead, trim only on submit.
-}
trimFields : Form -> TrimmedForm
trimFields form =
    Trimmed
        { docketId = String.trim form.docketId
        , fileDate = String.trim form.fileDate
        , status = DetainerWarrant.statusText form.status
        , plaintiffId = Maybe.map .id form.plaintiff.person
        , plaintiffAttorneyId = Maybe.andThen .id <| Maybe.map .attorney form.plaintiff
        , courtDate = Maybe.map Date.toIsoString form.courtDate.date
        , courtroom = String.trim form.courtroom
        , presidingJudgeId = Maybe.map .id form.presidingJudge.person
        , isCares = form.isCares
        , isLegacy = form.isLegacy
        , nonpayment = form.isNonpayment
        , amountClaimed = form.amountClaimed
        , amountClaimedCategory = form.amountClaimedCategory
        , address = String.trim form.address
        , defendants = List.map .id form.defendants
        , judgement = form.judgement
        , notes = String.trim form.notes
        }
