module DetainerWarrant exposing (AmountClaimedCategory(..), ConditionOption(..), Conditions(..), DatePickerState, DetainerWarrant, DetainerWarrantEdit, DismissalBasis(..), DismissalConditions, Entrance(..), Interest(..), Judgement, JudgementEdit, JudgementForm, OwedConditions, Status(..), amountClaimedCategoryOptions, amountClaimedCategoryText, conditionText, conditionsOptions, decoder, dismissalBasisOption, dismissalBasisOptions, editFromForm, judgementDecoder, mostRecentCourtDate, statusFromText, statusOptions, statusText, tableColumns, ternaryOptions, toTableCover, toTableDetails, toTableRow)

import Attorney exposing (Attorney)
import Courtroom exposing (Courtroom)
import Date exposing (Date)
import DatePicker
import Defendant exposing (Defendant)
import Json.Decode as Decode exposing (Decoder, bool, float, int, list, nullable, string)
import Json.Decode.Pipeline exposing (custom, optional, required)
import Judge exposing (Judge, JudgeForm)
import Maybe
import Plaintiff exposing (Plaintiff)
import String.Extra
import Time exposing (Posix)
import Time.Utils
import UI.Button exposing (Button)
import UI.Dropdown as Dropdown
import UI.Tables.Common as Common exposing (Row, cellFromButton, cellFromText, columnWidthPixels, columnsEmpty, rowCellButton, rowCellText, rowEmpty)
import UI.Tables.Stateful exposing (detailShown, detailsEmpty)
import UI.Text as Text
import UI.Utils.TypeNumbers as T


type alias DatePickerState =
    { date : Maybe Date
    , dateText : String
    , pickerModel : DatePicker.Model
    }


type Status
    = Closed
    | Pending


type AmountClaimedCategory
    = Possession
    | Fees
    | Both
    | NotApplicable


type Entrance
    = Default
    | AgreementOfParties
    | TrialInCourt


type DismissalBasis
    = FailureToProsecute
    | FindingInFavorOfDefendant
    | NonSuitByPlaintiff


type Interest
    = WithRate Float
    | FollowsSite


type alias OwedConditions =
    { awardsFees : Maybe Float
    , awardsPossession : Bool
    , interest : Maybe Interest
    }


type alias DismissalConditions =
    { basis : DismissalBasis
    , withPrejudice : Bool
    }


type Conditions
    = PlaintiffConditions OwedConditions
    | DefendantConditions DismissalConditions


type alias Judgement =
    { id : Int
    , notes : Maybe String
    , courtDate : Maybe Posix
    , courtroom : Maybe Courtroom
    , enteredBy : Entrance
    , judge : Maybe Judge
    , conditions : Maybe Conditions
    }


type alias DetainerWarrant =
    { docketId : String
    , fileDate : Maybe Posix
    , status : Maybe Status
    , plaintiff : Maybe Plaintiff
    , plaintiffAttorney : Maybe Attorney
    , amountClaimed : Maybe Float
    , amountClaimedCategory : AmountClaimedCategory
    , isCares : Maybe Bool
    , isLegacy : Maybe Bool
    , nonpayment : Maybe Bool
    , defendants : List Defendant
    , judgements : List Judgement
    , notes : Maybe String
    }


type alias Related =
    { id : Int }


type alias JudgementEdit =
    { id : Maybe Int
    , notes : Maybe String
    , enteredBy : Maybe String
    , courtDate : Maybe String
    , inFavorOf : Maybe String
    , judge : Maybe Judge

    -- Plaintiff Favor
    , awardsFees : Maybe Float
    , awardsPossession : Maybe Bool
    , hasInterest : Bool
    , interestRate : Maybe Float
    , interestFollowsSite : Maybe Bool

    -- Tenant Favor
    , dismissalBasis : Maybe String
    , withPrejudice : Maybe Bool
    }


type alias JudgementForm =
    { id : Maybe Int
    , conditionsDropdown : Dropdown.State (Maybe ConditionOption)
    , condition : Maybe ConditionOption
    , enteredBy : Entrance
    , courtDate : DatePickerState
    , courtroom : Maybe Courtroom
    , courtroomDropdown : Dropdown.State (Maybe Courtroom)
    , notes : String
    , awardsFees : String
    , awardsPossession : Bool
    , hasInterest : Bool
    , interestRate : String
    , interestFollowsSite : Bool
    , dismissalBasisDropdown : Dropdown.State DismissalBasis
    , dismissalBasis : DismissalBasis
    , withPrejudice : Bool
    , judge : JudgeForm
    }


entranceText : Entrance -> String
entranceText entrance =
    case entrance of
        Default ->
            "DEFAULT"

        AgreementOfParties ->
            "AGREEMENT_OF_PARTIES"

        TrialInCourt ->
            "TRIAL_IN_COURT"


dismissalBasisOption : DismissalBasis -> String
dismissalBasisOption basis =
    basis
        |> dismissalBasisText
        |> String.replace "_" " "
        |> String.toLower
        |> String.Extra.toSentenceCase


dismissalBasisText : DismissalBasis -> String
dismissalBasisText basis =
    case basis of
        FailureToProsecute ->
            "FAILURE_TO_PROSECUTE"

        FindingInFavorOfDefendant ->
            "FINDING_IN_FAVOR_OF_DEFENDANT"

        NonSuitByPlaintiff ->
            "NON_SUIT_BY_PLAINTIFF"


editFromForm : Date -> JudgementForm -> JudgementEdit
editFromForm today form =
    let
        rate =
            String.toFloat <| String.replace "%" "" form.interestRate
    in
    { id = form.id
    , notes =
        if String.isEmpty form.notes then
            Nothing

        else
            Just form.notes
    , courtDate =
        form.courtDate.date
            |> Maybe.map Date.toIsoString
    , enteredBy = Just <| entranceText form.enteredBy
    , inFavorOf =
        Maybe.map
            (\option ->
                case option of
                    PlaintiffOption ->
                        "PLAINTIFF"

                    DefendantOption ->
                        "DEFENDANT"
            )
            form.condition
    , awardsFees =
        if form.awardsFees == "" then
            Nothing

        else
            String.toFloat <| String.replace "," "" form.awardsFees
    , awardsPossession =
        if form.condition == Just DefendantOption then
            Nothing

        else
            Just form.awardsPossession
    , hasInterest = form.hasInterest
    , interestRate =
        if form.hasInterest && not form.interestFollowsSite then
            rate

        else
            Nothing
    , interestFollowsSite =
        if form.hasInterest && form.interestFollowsSite then
            Just form.interestFollowsSite

        else
            Nothing
    , dismissalBasis =
        if form.condition == Just DefendantOption then
            Just (dismissalBasisText form.dismissalBasis)

        else
            Nothing
    , withPrejudice =
        if form.condition == Just DefendantOption then
            Just form.withPrejudice

        else
            Nothing
    , judge =
        form.judge.person
    }


type alias DetainerWarrantEdit =
    { docketId : String
    , fileDate : Maybe String
    , status : Maybe Status
    , plaintiff : Maybe Related
    , plaintiffAttorney : Maybe Related
    , amountClaimed : Maybe Float
    , amountClaimedCategory : AmountClaimedCategory
    , isCares : Maybe Bool
    , isLegacy : Maybe Bool
    , nonpayment : Maybe Bool
    , defendants : List Related
    , notes : Maybe String
    }


conditionText : ConditionOption -> String
conditionText option =
    case option of
        PlaintiffOption ->
            "Plaintiff"

        DefendantOption ->
            "Defendant"


ternaryOptions : List (Maybe Bool)
ternaryOptions =
    [ Nothing, Just True, Just False ]


statusOptions : List (Maybe Status)
statusOptions =
    [ Nothing, Just Pending, Just Closed ]


amountClaimedCategoryOptions : List AmountClaimedCategory
amountClaimedCategoryOptions =
    [ NotApplicable, Possession, Fees, Both ]


dismissalBasisOptions : List DismissalBasis
dismissalBasisOptions =
    [ FailureToProsecute, FindingInFavorOfDefendant, NonSuitByPlaintiff ]


type ConditionOption
    = PlaintiffOption
    | DefendantOption


conditionsOptions : List (Maybe ConditionOption)
conditionsOptions =
    [ Nothing, Just PlaintiffOption, Just DefendantOption ]


statusText : Status -> String
statusText status =
    case status of
        Closed ->
            "CLOSED"

        Pending ->
            "PENDING"


amountClaimedCategoryText : AmountClaimedCategory -> String
amountClaimedCategoryText category =
    case category of
        Possession ->
            "POSS"

        Fees ->
            "FEES"

        Both ->
            "BOTH"

        NotApplicable ->
            "N/A"


statusFromText : String -> Result String Status
statusFromText str =
    case str of
        "CLOSED" ->
            Result.Ok Closed

        "PENDING" ->
            Result.Ok Pending

        _ ->
            Result.Err "Invalid Status"


statusDecoder : Decoder Status
statusDecoder =
    Decode.string
        |> Decode.andThen
            (\str ->
                case statusFromText str of
                    Ok status ->
                        Decode.succeed status

                    Err msg ->
                        Decode.fail msg
            )


amountClaimedCategoryDecoder : Decoder AmountClaimedCategory
amountClaimedCategoryDecoder =
    Decode.string
        |> Decode.andThen
            (\str ->
                case str of
                    "POSS" ->
                        Decode.succeed Possession

                    "FEES" ->
                        Decode.succeed Fees

                    "BOTH" ->
                        Decode.succeed Both

                    "N/A" ->
                        Decode.succeed NotApplicable

                    somethingElse ->
                        Decode.fail <| "Unknown amount claimed category:" ++ somethingElse
            )


interestConditionsDecoder : Decoder Interest
interestConditionsDecoder =
    Decode.field "interest_rate" (nullable float)
        |> Decode.andThen
            (\rate ->
                Decode.succeed <|
                    case rate of
                        Nothing ->
                            FollowsSite

                        Just someRate ->
                            WithRate someRate
            )


interestDecoder : Decoder (Maybe Interest)
interestDecoder =
    Decode.field "interest" (nullable bool)
        |> Decode.andThen
            (\maybeHasInterest ->
                maybeHasInterest
                    |> Maybe.map
                        (\hasInterest ->
                            if hasInterest then
                                Decode.map Just interestConditionsDecoder

                            else
                                Decode.succeed Nothing
                        )
                    |> Maybe.withDefault (Decode.succeed Nothing)
            )


owedConditionsDecoder : Decoder OwedConditions
owedConditionsDecoder =
    Decode.succeed OwedConditions
        |> required "awards_fees" (nullable float)
        |> required "awards_possession" bool
        |> custom interestDecoder


dismissalBasisDecoder : Decoder DismissalBasis
dismissalBasisDecoder =
    Decode.string
        |> Decode.andThen
            (\str ->
                case str of
                    "FAILURE_TO_PROSECUTE" ->
                        Decode.succeed FailureToProsecute

                    "FINDING_IN_FAVOR_OF_DEFENDANT" ->
                        Decode.succeed FindingInFavorOfDefendant

                    "NON_SUIT_BY_PLAINTIFF" ->
                        Decode.succeed NonSuitByPlaintiff

                    _ ->
                        Decode.fail "oops"
            )


dismissalConditionsDecoder : Decoder DismissalConditions
dismissalConditionsDecoder =
    Decode.succeed DismissalConditions
        |> optional "dismissal_basis" dismissalBasisDecoder FailureToProsecute
        |> optional "with_prejudice" bool False


entranceDecoder : Decoder Entrance
entranceDecoder =
    Decode.string
        |> Decode.andThen
            (\str ->
                case str of
                    "DEFAULT" ->
                        Decode.succeed Default

                    "AGREEMENT_OF_PARTIES" ->
                        Decode.succeed AgreementOfParties

                    "TRIAL_IN_COURT" ->
                        Decode.succeed TrialInCourt

                    _ ->
                        Decode.fail "oops"
            )


fromConditions : Maybe Conditions -> Decoder Judgement
fromConditions conditions =
    Decode.succeed Judgement
        |> required "id" int
        |> required "notes" (nullable string)
        |> required "court_date" (nullable posixDecoder)
        |> required "courtroom" (nullable Courtroom.decoder)
        |> required "entered_by" entranceDecoder
        |> required "judge" (nullable Judge.decoder)
        |> custom (Decode.succeed conditions)


judgementDecoder : Decoder Judgement
judgementDecoder =
    Decode.field "in_favor_of" (nullable string)
        |> Decode.andThen
            (\maybeStr ->
                case maybeStr of
                    Just "PLAINTIFF" ->
                        Decode.map (Just << PlaintiffConditions) owedConditionsDecoder

                    Just "DEFENDANT" ->
                        Decode.map (Just << DefendantConditions) dismissalConditionsDecoder

                    _ ->
                        Decode.succeed Nothing
            )
        |> Decode.andThen fromConditions


posixDecoder : Decoder Posix
posixDecoder =
    Decode.map Time.millisToPosix Decode.int


decoder : Decoder DetainerWarrant
decoder =
    Decode.succeed DetainerWarrant
        |> required "docket_id" string
        |> required "file_date" (nullable posixDecoder)
        |> required "status" (nullable statusDecoder)
        |> required "plaintiff" (nullable Plaintiff.decoder)
        |> required "plaintiff_attorney" (nullable Attorney.decoder)
        |> required "amount_claimed" (nullable float)
        |> required "amount_claimed_category" amountClaimedCategoryDecoder
        |> required "is_cares" (nullable bool)
        |> required "is_legacy" (nullable bool)
        |> required "nonpayment" (nullable bool)
        |> required "defendants" (list Defendant.decoder)
        |> required "judgements" (list judgementDecoder)
        |> required "notes" (nullable string)


tableColumns =
    columnsEmpty
        |> Common.column "Docket ID" (columnWidthPixels 150)
        |> Common.column "File date" (columnWidthPixels 150)
        |> Common.column "Court date" (columnWidthPixels 150)
        |> Common.column "Plaintiff" (columnWidthPixels 240)
        |> Common.column "Pltf. Attorney" (columnWidthPixels 240)
        |> Common.column "Defendant" (columnWidthPixels 240)
        |> Common.column "Address" (columnWidthPixels 240)
        |> Common.column "" (columnWidthPixels 100)


toTableRow : (DetainerWarrant -> Button msg) -> { toKey : DetainerWarrant -> String, view : DetainerWarrant -> Row msg T.Eight }
toTableRow toEditButton =
    { toKey = .docketId, view = toTableRowView toEditButton }


mostRecentCourtDate : DetainerWarrant -> Maybe Posix
mostRecentCourtDate warrant =
    Maybe.andThen .courtDate <| List.head warrant.judgements


toTableRowView : (DetainerWarrant -> Button msg) -> DetainerWarrant -> Row msg T.Eight
toTableRowView toEditButton ({ docketId, fileDate, plaintiff, plaintiffAttorney, defendants } as warrant) =
    rowEmpty
        |> rowCellText (Text.body2 docketId)
        |> rowCellText (Text.body2 (Maybe.withDefault "" <| Maybe.map Time.Utils.toIsoString fileDate))
        |> rowCellText (Text.body2 (Maybe.withDefault "" <| Maybe.map Time.Utils.toIsoString (mostRecentCourtDate warrant)))
        |> rowCellText (Text.body2 (Maybe.withDefault "" <| Maybe.map .name plaintiff))
        |> rowCellText (Text.body2 (Maybe.withDefault "" <| Maybe.map .name plaintiffAttorney))
        |> rowCellText (Text.body2 (Maybe.withDefault "" <| Maybe.map .name <| List.head defendants))
        |> rowCellText (Text.body2 (Maybe.withDefault "" <| Maybe.map .address <| List.head defendants))
        |> rowCellButton (toEditButton warrant)


toTableDetails toEditButton ({ docketId, fileDate, plaintiff, plaintiffAttorney, defendants } as warrant) =
    detailsEmpty
        |> detailShown
            { label = "Docket ID"
            , content = cellFromText <| Text.body2 docketId
            }
        |> detailShown
            { label = "File date"
            , content = cellFromText <| Text.body2 (Maybe.withDefault "" <| Maybe.map Time.Utils.toIsoString fileDate)
            }
        |> detailShown
            { label = "Court date"
            , content = cellFromText <| Text.body2 (Maybe.withDefault "" <| Maybe.map Time.Utils.toIsoString (mostRecentCourtDate warrant))
            }
        |> detailShown
            { label = "Plaintiff"
            , content = cellFromText <| Text.body2 (Maybe.withDefault "" <| Maybe.map .name plaintiff)
            }
        |> detailShown
            { label = "Pltf. Attorney"
            , content = cellFromText <| Text.body2 (Maybe.withDefault "" <| Maybe.map .name plaintiffAttorney)
            }
        |> detailShown
            { label = "Defendant"
            , content = cellFromText <| Text.body2 (Maybe.withDefault "" <| Maybe.map .name <| List.head defendants)
            }
        |> detailShown
            { label = "Address"
            , content = cellFromText <| Text.body2 (Maybe.withDefault "" <| Maybe.map .address <| List.head defendants)
            }
        |> detailShown
            { label = "Edit"
            , content = cellFromButton (toEditButton warrant)
            }


toTableCover { docketId, defendants } =
    { title = docketId, caption = Maybe.map .address <| List.head defendants }
