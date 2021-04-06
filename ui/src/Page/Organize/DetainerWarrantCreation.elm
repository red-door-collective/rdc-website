module Page.Organize.DetainerWarrantCreation exposing (Model, Msg, init, subscriptions, toSession, update, view)

import Api exposing (Cred)
import Api.Endpoint as Endpoint
import Campaign exposing (Campaign)
import Color
import Date exposing (Date)
import DatePicker exposing (ChangeEvent(..))
import DetainerWarrant exposing (AmountClaimedCategory, Attorney, DetainerWarrant, Judge, Plaintiff, Status)
import Dropdown
import Element exposing (Element, centerX, column, el, fill, height, image, link, maximum, minimum, padding, paragraph, px, row, spacing, text, textColumn, width)
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
    { firstName : String
    , middleName : String
    , lastName : String
    , suffix : String
    , potentialPhones : List String
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


type alias Form =
    { docketId : String
    , fileDate : DatePickerState
    , status : Status
    , statusDropdown : Dropdown.State String
    , plaintiff : PlaintiffForm
    , plaintiffAttorney : AttorneyForm
    , courtDate : DatePickerState
    , courtroom : String
    , isCares : Maybe Bool
    , isLegacy : Maybe Bool
    , isNonpayment : Maybe Bool
    , amountClaimed : String
    , amountClaimedCategory : AmountClaimedCategory
    , categoryDropdown : Dropdown.State String
    , address : String
    , defendants : List DefendantForm
    , notes : String
    }


type alias Model =
    { session : Session
    , warrant : Maybe DetainerWarrant
    , docketId : Maybe String
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
    , isCares = Nothing
    , isLegacy = Nothing
    , isNonpayment = Nothing
    , amountClaimed = ""
    , amountClaimedCategory = DetainerWarrant.NotApplicable
    , categoryDropdown = Dropdown.init "amount-claimed-category-dropdown"
    , address = ""
    , defendants = []
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
    | PickedAmountClaimedCategory (Maybe String)
    | CategoryDropdownMsg (Dropdown.Msg String)
    | CheckedCares Bool
    | CheckedLegacy Bool
    | CheckedNonpayment Bool
    | ChangedAddress String
    | ChangedNotes String


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


statusOptions =
    [ "Pending", "Closed" ]


amountClaimedCategoryOptions =
    [ "Possession", "Fees", "Both", "Not Applicable" ]


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

        PickedAmountClaimedCategory option ->
            updateForm
                (\form ->
                    { form
                        | amountClaimedCategory =
                            case option of
                                Just "Posession" ->
                                    DetainerWarrant.Possession

                                Just "Fees" ->
                                    DetainerWarrant.Fees

                                Just "Both" ->
                                    DetainerWarrant.Both

                                Just "Not Applicable" ->
                                    DetainerWarrant.NotApplicable

                                _ ->
                                    DetainerWarrant.NotApplicable
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

        ChangedNotes notes ->
            updateForm
                (\form -> { form | notes = notes })
                model


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


viewFileDate form =
    row []
        [ DatePicker.input [ Element.centerX, Element.centerY ]
            { onChange = ChangedFileDatePicker
            , selected = form.fileDate.date
            , text = form.fileDate.dateText
            , label =
                Input.labelAbove [] <|
                    Element.text "Select File Date"
            , placeholder = Nothing
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


viewStatus form =
    row []
        [ Dropdown.view statusDropdownConfig form.statusDropdown statusOptions
            |> el []
        ]


viewPlaintiffSearch options form =
    row []
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
    row []
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
    row []
        [ DatePicker.input [ Element.centerX, Element.centerY ]
            { onChange = ChangedCourtDatePicker
            , selected = form.courtDate.date
            , text = form.courtDate.dateText
            , label =
                Input.labelAbove [] <|
                    Element.text "Select Court Date"
            , placeholder = Nothing
            , settings = DatePicker.defaultSettings
            , model = form.courtDate.pickerModel
            }
        ]


viewCourtroom form =
    row []
        [ Input.text []
            { onChange = ChangedCourtroom
            , text = form.courtroom
            , label = Input.labelHidden "Courtroom"
            , placeholder = Just <| Input.placeholder [] (text "Courtroom")
            }
        ]


viewPresidingJudgeSearch form =
    row [] []


viewAmountClaimed form =
    row []
        [ Input.text []
            { onChange = ChangedCourtroom
            , text = form.amountClaimed
            , label = Input.labelHidden "Amount Claimed"
            , placeholder = Just <| Input.placeholder [] (text "Amount Claimed ($)")
            }
        ]


viewAmountClaimedCategory form =
    row []
        [ Dropdown.view categoryDropdownConfig form.categoryDropdown amountClaimedCategoryOptions
            |> el []
        ]


viewCares : Form -> Element Msg
viewCares form =
    row []
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
    row []
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
    row []
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
    row []
        [ Input.text []
            { onChange = ChangedAddress
            , text = form.address
            , label = Input.labelHidden "Defendant Address"
            , placeholder = Just <| Input.placeholder [] (text "Defendant Address")
            }
        ]


viewDefendants =
    row [] []


viewJudgement form =
    row [] []


viewNotes form =
    row []
        [ Input.multiline []
            { onChange = ChangedNotes
            , text = form.notes
            , label = Input.labelHidden "Notes"
            , placeholder = Just <| Input.placeholder [] (text "Notes")
            , spellcheck = True
            }
        ]


viewForm : FormOptions -> FormStatus -> Element Msg
viewForm options formStatus =
    case formStatus of
        Initializing ->
            column [] [ text "Initializing" ]

        Ready form ->
            column []
                [ Input.text [] { onChange = ChangedDocketId, text = form.docketId, placeholder = Just (Input.placeholder [] (text "Docket Id")), label = Input.labelHidden "Docket Id" }
                , viewFileDate form
                , viewStatus form
                , viewPlaintiffSearch options form
                , viewPlaintiffAttorneySearch options form
                , viewCourtDate form
                , viewCourtroom form
                , viewPresidingJudgeSearch form
                , viewAmountClaimed form
                , viewAmountClaimedCategory form
                , viewCares form
                , viewLegacy form
                , viewNonpayment form
                , viewAddress form
                , viewDefendants
                , viewJudgement form
                , viewNotes form
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
                [ row [ centerX ]
                    [ paragraph []
                        [ text
                            ((case model.docketId of
                                Just _ ->
                                    "Edit"

                                Nothing ->
                                    "Create"
                             )
                                ++ " Detainer Warrant"
                            )
                        , viewForm (formOptions model) model.form
                        ]
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
