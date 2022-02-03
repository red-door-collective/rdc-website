module Page.Admin.DetainerWarrants.Edit exposing (Data, Model, Msg, page)

import Attorney exposing (Attorney, AttorneyForm)
import Browser.Navigation as Nav
import Courtroom exposing (Courtroom)
import DataSource exposing (DataSource)
import Date exposing (Date)
import Date.Extra
import DatePicker exposing (ChangeEvent(..))
import DetainerWarrant exposing (DetainerWarrant, DetainerWarrantEdit, Status)
import Dict
import Element exposing (Element, centerX, column, el, fill, height, inFront, maximum, minimum, padding, paddingEach, paddingXY, paragraph, px, row, spacing, text, width)
import Element.Border as Border
import Element.Font as Font
import Element.Input as Input
import FeatherIcons
import Field
import Form.State exposing (DatePickerState)
import Head
import Head.Seo as Seo
import Hearing exposing (Hearing)
import Html
import Html.Attributes
import Http
import Json.Encode as Encode
import Judge exposing (Judge)
import List.Extra as List
import Log
import Logo
import Mask
import Maybe.Extra
import Page exposing (StaticPayload)
import Pages.PageUrl exposing (PageUrl)
import Path exposing (Path)
import Plaintiff exposing (Plaintiff, PlaintiffForm)
import QueryParams
import RemoteData exposing (RemoteData(..))
import Rest exposing (Cred)
import Rest.Endpoint as Endpoint exposing (toQueryArgs)
import Rollbar exposing (Rollbar)
import Runtime
import SearchBox
import Session exposing (Session)
import Shared
import SplitButton
import Sprite
import Time.Utils
import UI.Button as Button exposing (Button)
import UI.Dropdown as Dropdown
import UI.Effects as Effects
import UI.Icon as Icon
import UI.Link as Link
import UI.Palette as Palette
import UI.RenderConfig exposing (RenderConfig)
import UI.Size
import UI.Tables.Stateless as Stateless
import UI.TextField as TextField
import Url
import Url.Builder
import User exposing (NavigationOnSuccess(..))
import View exposing (View)


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
    , showDocument : Maybe Bool
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
    , claimsPossession : Maybe Bool
    , claimsPossessionDropdown : Dropdown.State (Maybe Bool)
    , address : String
    , hearings : List Hearing
    , notes : String
    , saveButtonState : SplitButton.State NavigationOnSuccess
    }


type Problem
    = InvalidEntry ValidatedField String
    | ServerError String


type SaveState
    = SavingRelatedModels { attorney : Bool, plaintiff : Bool }
    | SavingWarrant
    | Done


type alias Model =
    { warrant : Maybe DetainerWarrant
    , cursor : Maybe String
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
    , showDocument : Maybe Bool
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
    , claimsPossession = warrant.claimsPossession
    , claimsPossessionDropdown = Dropdown.init "claims-possession-dropdown"
    , address = Maybe.withDefault "" warrant.address
    , hearings = warrant.hearings
    , notes = Maybe.withDefault "" warrant.notes
    , saveButtonState = SplitButton.init "save-button"
    }


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
    , claimsPossession = Nothing
    , claimsPossessionDropdown = Dropdown.init "claims-possession-dropdown"
    , address = ""
    , hearings = []
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
      , navigationOnSuccess = RemoteData.withDefault Remain <| RemoteData.map .preferredNavigation sharedModel.profile
      , showDocument = Nothing
      }
    , Cmd.batch
        [ case docketId of
            Just id ->
                getWarrant domain id maybeCred

            _ ->
                Cmd.none
        , Rest.get (Endpoint.courtrooms domain []) maybeCred GotCourtrooms (Rest.collectionDecoder Courtroom.decoder)
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
    | PickedClaimsPossession (Maybe (Maybe Bool))
    | ClaimsPossessionDropdownMsg (Dropdown.Msg (Maybe Bool))
    | CaresDropdownMsg (Dropdown.Msg (Maybe Bool))
    | PickedCares (Maybe (Maybe Bool))
    | LegacyDropdownMsg (Dropdown.Msg (Maybe Bool))
    | PickedLegacy (Maybe (Maybe Bool))
    | NonpaymentDropdownMsg (Dropdown.Msg (Maybe Bool))
    | PickedNonpayment (Maybe (Maybe Bool))
    | ChangedAddress String
    | ChangedNotes String
    | ToggleOpenDocument
    | SplitButtonMsg (SplitButton.Msg NavigationOnSuccess)
    | PickedSaveOption (Maybe NavigationOnSuccess)
    | Save
    | UpsertedPlaintiff (Result Http.Error (Rest.Item Plaintiff))
    | UpsertedAttorney (Result Http.Error (Rest.Item Attorney))
    | CreatedDetainerWarrant (Result Http.Error (Rest.Item DetainerWarrant))
    | GotPlaintiffs (Result Http.Error (Rest.Collection Plaintiff))
    | GotAttorneys (Result Http.Error (Rest.Collection Attorney))
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

        PickedClaimsPossession option ->
            updateForm
                (\form ->
                    { form
                        | claimsPossession = Maybe.andThen identity option
                    }
                )
                model

        ClaimsPossessionDropdownMsg subMsg ->
            updateFormNarrow
                (\form ->
                    let
                        ( newState, newCmd ) =
                            Dropdown.update cfg subMsg (claimsPossessionDropdown form)
                    in
                    ( { form | claimsPossessionDropdown = newState }, Effects.perform newCmd )
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

        ChangedNotes notes ->
            updateForm
                (\form -> { form | notes = notes })
                model

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
            , Cmd.none
            )

        Save ->
            submitForm today domain sharedModel session model

        UpsertedPlaintiff (Ok plaintiffItem) ->
            nextStepSave
                today
                domain
                sharedModel
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

        UpsertedAttorney (Ok attorney) ->
            nextStepSave
                today
                domain
                sharedModel
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
                sharedModel
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

        GotCourtrooms (Ok courtroomsPage) ->
            ( { model | courtrooms = courtroomsPage.data }, Cmd.none )

        GotCourtrooms (Err httpError) ->
            ( model, logHttpError httpError )

        NoOp ->
            ( model, Cmd.none )


error : Rollbar -> String -> Cmd Msg
error rollbar report =
    Log.error rollbar (\_ -> NoOp) report


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

        _ ->
            False


submitForm : Date -> String -> Shared.Model -> Session -> Model -> ( Model, Cmd Msg )
submitForm today domain sharedModel session model =
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
                        }

                updatedModel =
                    { model
                        | problems = []
                        , saveState = savingRelatedModels
                    }
            in
            if doneSavingRelatedModels apiForms savingRelatedModels then
                nextStepSave today domain sharedModel session updatedModel

            else
                ( updatedModel
                , Cmd.batch
                    (List.concat
                        [ apiForms.attorney
                            |> Maybe.map (List.singleton << upsertAttorney domain maybeCred)
                            |> Maybe.withDefault []
                        , Maybe.withDefault [] <| Maybe.map (List.singleton << upsertPlaintiff domain maybeCred) apiForms.plaintiff
                        , List.singleton <| fetchAdjacentDetainerWarrant domain maybeCred model
                        ]
                    )
                )

        Err problems ->
            ( { model | problems = problems }
            , Cmd.none
            )


nextStepSave : Date -> String -> Shared.Model -> Session -> Model -> ( Model, Cmd Msg )
nextStepSave today domain sharedModel session model =
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
                SavingRelatedModels _ ->
                    if doneSavingRelatedModels apiForms model.saveState then
                        ( { model | saveState = SavingWarrant }
                        , updateDetainerWarrant domain maybeCred apiForms.detainerWarrant
                        )

                    else
                        ( model, Cmd.none )

                SavingWarrant ->
                    nextStepSave today domain sharedModel session { model | saveState = Done }

                Done ->
                    let
                        currentPath =
                            [ "admin", "detainer-warrants", "edit" ]
                    in
                    ( model
                    , Cmd.batch
                        ((case ( sharedModel.profile, model.navigationOnSuccess ) of
                            ( Success user, nav ) ->
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
                                Rest.patch (Endpoint.user domain user.id) maybeCred body (\_ -> NoOp) User.decoder

                            _ ->
                                Cmd.none
                         )
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
        [ Field.view options.showHelp
            { tooltip = Just DetainerWarrant.description.docketId
            , label = Nothing
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
        [ Field.view options.showHelp
            { tooltip = Just DetainerWarrant.description.fileDate
            , label = Nothing
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


claimsPossessionDropdown form =
    basicDropdown
        { config =
            { dropdownMsg = ClaimsPossessionDropdownMsg
            , onSelectMsg = PickedClaimsPossession
            , state = form.claimsPossessionDropdown
            }
        , selected = Just form.claimsPossession
        , itemToStr = ternaryText
        , items = DetainerWarrant.ternaryOptions
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
        [ Field.view options.showHelp
            { tooltip = Just DetainerWarrant.description.status
            , label = Nothing
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
        [ Field.view options.showHelp
            { tooltip = Just DetainerWarrant.description.plaintiff
            , label = Nothing
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
        [ Field.view options.showHelp
            { tooltip = Just DetainerWarrant.description.plaintiffAttorney
            , label = Nothing
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


viewAmountClaimed : FormOptions -> Form -> Element Msg
viewAmountClaimed options form =
    column [ width (fill |> maximum 215) ]
        [ Field.view options.showHelp
            { tooltip = Just DetainerWarrant.description.amountClaimed
            , label = Nothing
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


viewClaimsPossession : FormOptions -> Form -> Element Msg
viewClaimsPossession options form =
    column [ width (fill |> maximum 150) ]
        [ Field.view options.showHelp
            { tooltip = Just DetainerWarrant.description.claimsPossession
            , label = Nothing
            , children =
                [ column [ spacing 5, width fill ]
                    [ el labelAttrs (text "Claims possession")
                    , claimsPossessionDropdown form
                        |> Dropdown.renderElement options.renderConfig
                    ]
                ]
            }
        ]


viewCares : FormOptions -> Form -> Element Msg
viewCares options form =
    column [ width (fill |> maximum 150) ]
        [ Field.view options.showHelp
            { tooltip = Just DetainerWarrant.description.cares
            , label = Nothing
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
    column [ width (fill |> maximum 150) ]
        [ Field.view options.showHelp
            { tooltip = Just DetainerWarrant.description.legacy
            , label = Nothing
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
    column [ width (fill |> maximum 150) ]
        [ Field.view options.showHelp
            { tooltip = Just DetainerWarrant.description.nonpayment
            , label = Nothing
            , children =
                [ column [ spacing 5, width fill ]
                    [ el labelAttrs (text "Is nonpayment?")
                    , nonpaymentDropdown form
                        |> Dropdown.renderElement options.renderConfig
                    ]
                ]
            }
        ]


viewAddress : FormOptions -> Form -> Element Msg
viewAddress options form =
    row [ width (fill |> maximum 800) ]
        [ Field.view options.showHelp
            { tooltip = Just DetainerWarrant.description.address
            , label = Nothing
            , children =
                [ TextField.singlelineText ChangedAddress
                    "Address"
                    form.address
                    |> TextField.setLabelVisible True
                    |> TextField.withPlaceholder "123 Street Address, City, Zip Code"
                    |> TextField.withWidth TextField.widthFull
                    |> TextField.renderElement options.renderConfig
                ]
            }
        ]


viewEditJudgmentButton : Hearing -> Button Msg
viewEditJudgmentButton hearing =
    let
        judgmentId =
            Maybe.withDefault "0" <| Maybe.map (String.fromInt << .id) hearing.judgment
    in
    Button.fromIcon (Icon.edit "Go to edit judgment")
        |> Button.redirect
            (Link.link <|
                Url.Builder.absolute
                    [ "admin"
                    , "judgments"
                    , "edit"
                    ]
                    (Endpoint.toQueryArgs [ ( "id", judgmentId ) ])
            )
            Button.primary
        |> Button.withDisabledIf (hearing.judgment == Nothing)
        |> Button.withSize UI.Size.small


viewHearings : FormOptions -> Form -> Element Msg
viewHearings options form =
    column [ centerX, spacing 20, width (fill |> maximum 1000), padding 10 ]
        [ Stateless.table
            { columns = Hearing.tableColumns
            , toRow = Hearing.toTableRow viewEditJudgmentButton
            }
            |> Stateless.withWidth (Element.fill |> Element.maximum 640)
            |> Stateless.withItems form.hearings
            |> Stateless.renderElement options.renderConfig
        ]


viewNotes : FormOptions -> Form -> Element Msg
viewNotes options form =
    column [ width fill ]
        [ Field.view options.showHelp
            { tooltip = Just DetainerWarrant.description.notes
            , label = Nothing
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


viewForm : FormOptions -> FormStatus -> Element Msg
viewForm options formStatus =
    case formStatus of
        Initializing id ->
            column [] [ text ("Fetching docket " ++ id) ]

        Ready form ->
            column
                [ centerX, spacing 30 ]
                [ column
                    (tileAttrs
                        ++ (case Maybe.andThen .document options.originalWarrant of
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
                    [ paragraph [ Font.center, centerX ] [ text "Court" ]
                    , if options.showDocument == Just True then
                        case Maybe.andThen .document options.originalWarrant of
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
                        [ viewDocketId options form
                        , viewFileDate options form
                        , viewStatus options form
                        ]
                    , viewAddress options form
                    , formGroup
                        [ viewPlaintiffSearch ChangedPlaintiffSearchBox options form.plaintiff
                        , viewAttorneySearch ChangedPlaintiffAttorneySearchBox options form.plaintiffAttorney
                        ]
                    ]
                , tile
                    [ paragraph [ Font.center, centerX ] [ text "Claims" ]
                    , formGroup
                        [ viewAmountClaimed options form
                        ]
                    , formGroup
                        [ viewClaimsPossession options form
                        , viewCares options form
                        , viewLegacy options form
                        , viewNonpayment options form
                        ]
                    ]
                , tile
                    [ paragraph [ Font.center, centerX ] [ text "Hearings" ]
                    , viewHearings options form
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
    , showDocument = model.showDocument
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
    Sub.none



-- FORM


{-| Marks that we've trimmed the form's fields, so we don't accidentally send
it to the server without having trimmed it!
-}
type TrimmedForm
    = Trimmed Form


{-| When adding a variant here, add it to `fieldsToValidate` too!
-}
type ValidatedField
    = DocketId
    | FileDate


fieldsToValidate : List ValidatedField
fieldsToValidate =
    [ DocketId
    , FileDate
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
            case List.concatMap (validateField today trimmedForm) fieldsToValidate of
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
    , plaintiff : Maybe Plaintiff
    , attorney : Maybe Attorney
    }


related id =
    { id = id }


toDetainerWarrant : Date -> TrimmedForm -> ApiForms
toDetainerWarrant today (Trimmed form) =
    { detainerWarrant =
        { docketId = form.docketId
        , address =
            if form.address == "" then
                Nothing

            else
                Just form.address
        , fileDate = Maybe.andThen Date.Extra.toPosix form.fileDate.date
        , status = form.status
        , plaintiff = Maybe.map (related << .id) form.plaintiff.person
        , plaintiffAttorney = Maybe.map (related << .id) form.plaintiffAttorney.person
        , isCares = form.isCares
        , isLegacy = form.isLegacy
        , nonpayment = form.isNonpayment
        , amountClaimed = String.toFloat <| String.replace "," "" form.amountClaimed
        , claimsPossession = form.claimsPossession
        , notes =
            if String.isEmpty form.notes then
                Nothing

            else
                Just form.notes
        }
    , plaintiff =
        form.plaintiff.person
    , attorney =
        form.plaintiffAttorney.person
    }


conditional fieldName fn field =
    Maybe.withDefault [] <| Maybe.map (\f -> [ ( fieldName, fn f ) ]) field


nullable fieldName fn field =
    Maybe.withDefault [ ( fieldName, Encode.null ) ] <| Maybe.map (\f -> [ ( fieldName, fn f ) ]) field


toBody body =
    Encode.object [ ( "data", body ) ]
        |> Http.jsonBody


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


upsertPlaintiff : String -> Maybe Cred -> Plaintiff -> Cmd Msg
upsertPlaintiff domain maybeCred plaintiff =
    let
        decoder =
            Rest.itemDecoder Plaintiff.decoder

        postData =
            Encode.object
                ([ ( "name", Encode.string plaintiff.name )
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


updateDetainerWarrant : String -> Maybe Cred -> DetainerWarrantEdit -> Cmd Msg
updateDetainerWarrant domain maybeCred form =
    let
        detainerWarrant =
            Encode.object
                ([ ( "docket_id", Encode.string form.docketId )
                 ]
                    ++ nullable "claims_possession" Encode.bool form.claimsPossession
                    ++ nullable "file_date" Time.Utils.posixEncoder form.fileDate
                    ++ nullable "address" Encode.string form.address
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
