module Page.Organize.DetainerWarrantCreation exposing (Model, Msg, init, subscriptions, toSession, update, view)

import Api exposing (Cred)
import Api.Endpoint as Endpoint
import Campaign exposing (Campaign)
import Color
import Date exposing (Date)
import DatePicker exposing (ChangeEvent(..))
import Defendant exposing (Defendant)
import DetainerWarrant exposing (AmountClaimedCategory, Attorney, Courtroom, DetainerWarrant, DetainerWarrantEdit, Judge, Judgement, Plaintiff, Status)
import Dropdown
import Element exposing (Element, centerX, column, el, fill, height, image, link, maximum, minimum, padding, paddingXY, paragraph, px, row, spacing, text, textColumn, width, wrappedRow)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Input as Input
import FeatherIcons
import Html.Events
import Http
import Json.Decode as Decode
import Json.Encode as Encode
import Maybe.Extra
import Palette
import Route
import SearchBox
import Session exposing (Session)
import Set
import Settings exposing (Settings)
import Task
import Url.Builder as QueryParam
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
    , courtrooms : List Courtroom
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
    , statusDropdown : Dropdown.State String
    , plaintiff : PlaintiffForm
    , plaintiffAttorney : AttorneyForm
    , courtDate : DatePickerState
    , courtroom : CourtroomForm
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
    , courtrooms : List Courtroom
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
    , lastName = Maybe.withDefault "" <| Maybe.andThen .lastName defendant
    , suffix = Maybe.withDefault "" <| Maybe.andThen .suffix defendant
    , potentialPhones = Maybe.withDefault "" <| Maybe.andThen .potentialPhones defendant
    }


editForm : DetainerWarrant -> Form
editForm warrant =
    { docketId = warrant.docketId
    , fileDate = initDatePicker (Just warrant.fileDate)
    , status = warrant.status
    , statusDropdown = Dropdown.init "status-dropdown"
    , plaintiff = initPlaintiffForm warrant.plaintiff
    , plaintiffAttorney = initAttorneyForm (Maybe.andThen .attorney warrant.plaintiff)
    , courtDate = initDatePicker warrant.courtDate
    , courtroom = initCourtroomForm warrant.courtroom
    , presidingJudge = initJudgeForm warrant.presidingJudge
    , isCares = warrant.isCares
    , isLegacy = warrant.isLegacy
    , isNonpayment = warrant.nonpayment
    , amountClaimed = Maybe.withDefault "" <| Maybe.map String.fromFloat warrant.amountClaimed
    , amountClaimedCategory = warrant.amountClaimedCategory
    , categoryDropdown = Dropdown.init "amount-claimed-category-dropdown"
    , address = Maybe.withDefault "" <| Maybe.map (Maybe.withDefault "") <| List.head <| List.map .address warrant.defendants
    , defendants = List.map (initDefendantForm << Just) warrant.defendants
    , judgement = warrant.judgement
    , judgementDropdown = Dropdown.init "judgement-dropdown"
    , notes = Maybe.withDefault "" warrant.notes
    }


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
    , isCares = Nothing
    , isLegacy = Nothing
    , isNonpayment = Nothing
    , amountClaimed = ""
    , amountClaimedCategory = Nothing
    , categoryDropdown = Dropdown.init "amount-claimed-category-dropdown"
    , address = ""
    , defendants = [ initDefendantForm Nothing ]
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
      , courtrooms = []
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
    | StatusDropdownMsg (Dropdown.Msg String)
    | ChangedCourtroomSearchBox (SearchBox.ChangeEvent Courtroom)
    | ChangedJudgeSearchBox (SearchBox.ChangeEvent Judge)
    | ChangedAmountClaimed String
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
    | CreatedDetainerWarrant (Result Http.Error (Api.Item DetainerWarrantEdit))
    | GotPlaintiffs (Result Http.Error (Api.Collection Plaintiff))
    | GotAttorneys (Result Http.Error (Api.Collection Attorney))
    | GotJudges (Result Http.Error (Api.Collection Attorney))
    | GotCourtrooms (Result Http.Error (Api.Collection Courtroom))


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


statusOptions : List String
statusOptions =
    [ "Pending", "Closed" ]


amountClaimedCategoryOptions : List String
amountClaimedCategoryOptions =
    [ "Possession", "Fees", "Both", "Not Applicable" ]


judgementOptions : List String
judgementOptions =
    [ "Non-suit", "POSS", "POSS + Payment", "Dismissed" ]


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
                    , Api.get (Endpoint.plaintiffs [ QueryParam.string "name" text ]) maybeCred GotPlaintiffs (Api.collectionDecoder DetainerWarrant.plaintiffDecoder)
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
                                    { attorney | person = Just person }
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
                    , Api.get (Endpoint.attorneys [ QueryParam.string "name" text ]) maybeCred GotAttorneys (Api.collectionDecoder DetainerWarrant.attorneyDecoder)
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

        StatusDropdownMsg subMsg ->
            updateFormNarrow
                (\form ->
                    let
                        ( state, cmd ) =
                            Dropdown.update statusDropdownConfig subMsg form.statusDropdown statusOptions
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
                                    { courtroom | selection = Just selection }
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
                    , Api.get (Endpoint.courtrooms [ QueryParam.string "name" text ]) maybeCred GotCourtrooms (Api.collectionDecoder DetainerWarrant.courtroomDecoder)
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
                    , Api.get (Endpoint.judges [ QueryParam.string "name" text ]) maybeCred GotJudges (Api.collectionDecoder DetainerWarrant.judgeDecoder)
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
            updateForm
                (\form -> { form | amountClaimed = money })
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
                (\form -> { form | defendants = form.defendants ++ [ initDefendantForm Nothing ] })
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
            case validate model.form of
                Ok validForm ->
                    ( { model | problems = [] }
                    , updateDetainerWarrant maybeCred (toDetainerWarrant validForm).detainerWarrant
                    )

                Err problems ->
                    ( { model | problems = problems }
                    , Cmd.none
                    )

        CreatedDetainerWarrant (Ok detainerWarrant) ->
            ( model, Cmd.none )

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


viewDocketId : Form -> Element Msg
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


dropdownConfig : (Dropdown.Msg String -> Msg) -> (Maybe String -> Msg) -> Dropdown.Config String Msg
dropdownConfig dropdownMsg itemPickedMsg =
    let
        containerAttrs =
            [ width (px 300) ]

        selectAttrs =
            [ Border.width 1
            , Border.rounded 5
            , paddingXY 16 8
            , spacing 10
            , width fill
            ]

        listAttrs =
            [ Border.width 1
            , Border.roundEach { topLeft = 0, topRight = 0, bottomLeft = 5, bottomRight = 5 }
            , width fill
            , spacing 5
            ]

        itemToPrompt item =
            text item

        itemToElement selected highlighted i =
            let
                bgColor =
                    if highlighted then
                        Palette.sred

                    else if selected then
                        Palette.red

                    else
                        Palette.white
            in
            el
                [ Background.color bgColor
                , padding 8
                , spacing 10
                , width fill
                ]
                (text i)
    in
    Dropdown.basic dropdownMsg itemPickedMsg itemToPrompt itemToElement
        |> Dropdown.withContainerAttributes containerAttrs
        |> Dropdown.withSelectAttributes selectAttrs
        |> Dropdown.withListAttributes listAttrs


categoryDropdownConfig =
    dropdownConfig CategoryDropdownMsg PickedAmountClaimedCategory


statusDropdownConfig =
    dropdownConfig StatusDropdownMsg PickedStatus


judgementDropdownConfig =
    dropdownConfig JudgementDropdownMsg PickedJudgement


viewStatus : Form -> Element Msg
viewStatus form =
    column [ width fill ]
        [ Dropdown.view statusDropdownConfig form.statusDropdown statusOptions
            |> el []
        ]


viewPlaintiffSearch : FormOptions -> Form -> Element Msg
viewPlaintiffSearch options form =
    row [ width fill ]
        [ SearchBox.input []
            { onChange = ChangedPlaintiffSearchBox
            , text = form.plaintiff.text
            , selected = form.plaintiff.person
            , options = Just options.plaintiffs
            , label = Input.labelHidden "Select Plaintiff"
            , placeholder = Just <| Input.placeholder [] (text "Plaintiff")
            , toLabel = \person -> person.name
            , filter = \query option -> True
            , state = form.plaintiff.searchBox
            }
        ]


viewPlaintiffAttorneySearch : FormOptions -> Form -> Element Msg
viewPlaintiffAttorneySearch options form =
    column [ width fill ]
        [ SearchBox.input []
            { onChange = ChangedPlaintiffAttorneySearchBox
            , text = form.plaintiffAttorney.text
            , selected = form.plaintiffAttorney.person
            , options = Just options.attorneys
            , label = Input.labelHidden "Select Plaintiff Attorney"
            , placeholder = Just <| Input.placeholder [] (text "Plaintiff Attorney")
            , toLabel = \person -> person.name
            , filter = \query option -> True
            , state = form.plaintiffAttorney.searchBox
            }
        ]


viewCourtDate : Form -> Element Msg
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


viewCourtroom : FormOptions -> Form -> Element Msg
viewCourtroom options form =
    column [ width fill ]
        [ SearchBox.input []
            { onChange = ChangedCourtroomSearchBox
            , text = form.courtroom.text
            , selected = form.courtroom.selection
            , options = Just options.courtrooms
            , label =
                Input.labelHidden "Select Courtroom"
            , placeholder = Just <| Input.placeholder [] (text "Courtroom")
            , toLabel = .name
            , filter = \query option -> True
            , state = form.courtroom.searchBox
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
            , label = Input.labelHidden "Select Presiding Judge"
            , placeholder = Just <| Input.placeholder [] (text "Presiding Judge")
            , toLabel = \person -> person.name
            , filter = \query option -> True
            , state = form.presidingJudge.searchBox
            }
        ]


viewAmountClaimed form =
    column [ width fill ]
        [ Input.text []
            { onChange = ChangedAmountClaimed
            , text = form.amountClaimed
            , label = Input.labelHidden "Amount Claimed"
            , placeholder = Just <| Input.placeholder [] (text "Amount Claimed ($)")
            }
        ]


viewAmountClaimedCategory : Form -> Element Msg
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


viewNonpayment : Form -> Element Msg
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


viewAddress : Form -> Element Msg
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


viewDefendants : Form -> Element Msg
viewDefendants form =
    row [ width (fill |> maximum 1000) ]
        [ column [ width fill, spacing 10 ]
            ([ paragraph [ Font.center, centerX ] [ text "Defendants" ] ]
                ++ List.indexedMap viewDefendantForm form.defendants
                ++ [ Input.button [] { onPress = Just AddDefendant, label = text "Add Defendant" } ]
            )
        ]


viewJudgement : Form -> Element Msg
viewJudgement form =
    column [ width fill ]
        [ Dropdown.view judgementDropdownConfig form.judgementDropdown judgementOptions
            |> el []
        ]


viewNotes : Form -> Element Msg
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
    row
        [ spacing 10
        , padding 10
        , width fill
        ]
        group


tile : List (Element Msg) -> Element Msg
tile groups =
    column
        [ spacing 10
        , padding 10
        , width fill
        , Border.rounded 3
        , Border.color Palette.grayLight
        , Border.width 1
        , Border.shadow { offset = ( 0, 10 ), size = 1, blur = 30, color = Palette.grayLight }
        ]
        groups


submitButton : Element Msg
submitButton =
    Input.button
        [ Background.color Palette.sred
        , Font.color Palette.white
        , Font.size 20
        , padding 10
        , Border.rounded 3
        ]
        { onPress = Just SubmitForm, label = text "Submit" }


viewForm : FormOptions -> FormStatus -> Element Msg
viewForm options formStatus =
    case formStatus of
        Initializing ->
            column [] [ text "Initializing" ]

        Ready form ->
            column [ centerX, spacing 25 ]
                [ tile
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
                        , viewCourtroom options form
                        , viewPresidingJudgeSearch options form
                        ]
                    ]
                , tile
                    [ formGroup
                        [ viewAmountClaimed form
                        , viewAmountClaimedCategory form
                        ]
                    , formGroup
                        [ viewCares form
                        , viewLegacy form
                        , viewNonpayment form
                        ]
                    ]
                , tile
                    [ viewAddress form
                    , viewDefendants form
                    ]
                , tile
                    [ formGroup
                        [ viewJudgement form
                        , viewNotes form
                        ]
                    ]
                , row [ centerX ] [ submitButton ]
                ]


formOptions : Model -> FormOptions
formOptions model =
    { plaintiffs = model.plaintiffs
    , attorneys = model.attorneys
    , judges = model.judges
    , courtrooms = model.courtrooms
    }


viewProblem : Problem -> Element Msg
viewProblem problem =
    paragraph []
        [ text
            (case problem of
                InvalidEntry _ value ->
                    value

                ServerError err ->
                    "something went wrong: " ++ err
            )
        ]


viewProblems : List Problem -> Element Msg
viewProblems problems =
    row [] [ column [] (List.map viewProblem problems) ]


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
                [ Dropdown.onOutsideClick form.statusDropdown StatusDropdownMsg
                , Dropdown.onOutsideClick form.categoryDropdown CategoryDropdownMsg
                , Dropdown.onOutsideClick form.judgementDropdown JudgementDropdownMsg
                ]



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
validate : FormStatus -> Result (List Problem) TrimmedForm
validate formStatus =
    case formStatus of
        Initializing ->
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
        { form
            | docketId = String.trim form.docketId
            , amountClaimed = String.trim form.amountClaimed
            , address = String.trim form.address
            , notes = String.trim form.notes
        }


type alias DefendantFormData =
    { id : Maybe Int
    , firstName : String
    , middleName : Maybe String
    , lastName : String
    , suffix : Maybe String
    }


type alias PlaintiffFormData =
    { id : Maybe Int
    , name : String
    , attorneyId : Maybe Int
    }


type alias AttorneyFormData =
    { id : Maybe Int
    , name : String
    }


type alias JudgeFormData =
    { id : Maybe Int
    , name : String
    }


type alias CourtroomFormData =
    { id : Maybe Int
    , name : String
    }


type alias ApiForms =
    { detainerWarrant : DetainerWarrantEdit
    , defendants : List DefendantFormData
    , plaintiff : Maybe PlaintiffFormData
    , attorney : Maybe AttorneyFormData
    , judge : Maybe JudgeFormData
    , courtroom : Maybe CourtroomFormData
    }


toDefendantData : DefendantForm -> DefendantFormData
toDefendantData defendant =
    { id = defendant.id
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
    }


toDetainerWarrant : TrimmedForm -> ApiForms
toDetainerWarrant (Trimmed form) =
    { detainerWarrant =
        { docketId = form.docketId
        , fileDate = Maybe.withDefault "10-10-2222" <| Maybe.map Date.toIsoString form.fileDate.date
        , status = form.status
        , plaintiffId = Maybe.map .id form.plaintiff.person
        , courtDate = Maybe.map Date.toIsoString form.courtDate.date
        , courtroomId = Maybe.map .id form.courtroom.selection
        , presidingJudgeId = Maybe.map .id form.presidingJudge.person
        , isCares = form.isCares
        , isLegacy = form.isLegacy
        , nonpayment = form.isNonpayment
        , amountClaimed = String.toFloat form.amountClaimed
        , amountClaimedCategory = form.amountClaimedCategory
        , defendants = List.filterMap .id form.defendants
        , judgement = form.judgement
        , notes =
            if String.isEmpty form.notes then
                Nothing

            else
                Just form.notes
        }
    , defendants = List.map toDefendantData form.defendants
    , plaintiff =
        case form.plaintiff.person of
            Just plaintiff ->
                Just { id = Just plaintiff.id, name = plaintiff.name, attorneyId = Maybe.map .id plaintiff.attorney }

            Nothing ->
                Nothing
    , attorney =
        case form.plaintiffAttorney.person of
            Just attorney ->
                Just { id = Just attorney.id, name = attorney.name }

            Nothing ->
                Nothing
    , judge =
        case form.presidingJudge.person of
            Just judge ->
                Just { id = Just judge.id, name = judge.name }

            Nothing ->
                Nothing
    , courtroom =
        case form.courtroom.selection of
            Just courtroom ->
                Just { id = Just courtroom.id, name = courtroom.name }

            Nothing ->
                Nothing
    }


updateDetainerWarrant : Maybe Cred -> DetainerWarrantEdit -> Cmd Msg
updateDetainerWarrant maybeCred form =
    let
        conditional fieldName fn field =
            Maybe.withDefault [] <| Maybe.map (\f -> [ ( fieldName, fn f ) ]) field

        detainerWarrant =
            Encode.object
                ([ ( "docket_id", Encode.string form.docketId )
                 , ( "file_date", Encode.string form.fileDate )
                 , ( "status", Encode.string (DetainerWarrant.statusText form.status) )
                 , ( "defendants", Encode.list Encode.int form.defendants )
                 ]
                    ++ conditional "plaintiff_id" Encode.int form.plaintiffId
                    ++ conditional "court_date" Encode.string form.courtDate
                    ++ conditional "courtroom_id" Encode.int form.courtroomId
                    ++ conditional "presiding_judge_id" Encode.int form.presidingJudgeId
                    ++ conditional "is_cares" Encode.bool form.isCares
                    ++ conditional "is_legacy" Encode.bool form.isLegacy
                    ++ conditional "nonpayment" Encode.bool form.nonpayment
                    ++ conditional "amount_claimed" Encode.float form.amountClaimed
                    ++ conditional "amount_claimed_category" Encode.string (Maybe.map DetainerWarrant.amountClaimedCategoryText form.amountClaimedCategory)
                    ++ conditional "judgement" Encode.string (Maybe.map DetainerWarrant.judgementText form.judgement)
                    ++ conditional "notes" Encode.string form.notes
                )

        body =
            Encode.object [ ( "data", detainerWarrant ) ]
                |> Http.jsonBody
    in
    Api.itemDecoder DetainerWarrant.editDecoder
        |> Api.put (Endpoint.editDetainerWarrant form.docketId) maybeCred body CreatedDetainerWarrant
