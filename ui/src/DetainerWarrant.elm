module DetainerWarrant exposing (AmountClaimedCategory(..), Attorney, ConditionOption(..), Conditions(..), Courtroom, DatePickerState, DetainerWarrant, DetainerWarrantEdit, DismissalBasis(..), DismissalConditions, Entrance(..), Interest(..), Judge, JudgeForm, Judgement, JudgementEdit, JudgementForm, OwedConditions, Plaintiff, Status(..), amountClaimedCategoryOptions, amountClaimedCategoryText, attorneyDecoder, conditionText, conditionsOptions, courtroomDecoder, dateDecoder, decoder, dismissalBasisOption, dismissalBasisOptions, dismissalBasisText, editFromForm, judgeDecoder, plaintiffDecoder, statusOptions, statusText, ternaryOptions)

import Date exposing (Date)
import DatePicker exposing (ChangeEvent(..))
import Defendant exposing (Defendant)
import Dropdown
import Json.Decode as Decode exposing (Decoder, Value, bool, float, int, list, nullable, string)
import Json.Decode.Pipeline exposing (custom, hardcoded, optional, required)
import SearchBox
import String.Extra
import Time exposing (Month(..))


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


type alias Judge =
    { id : Int, name : String }


type alias Attorney =
    { id : Int, name : String }


type alias Plaintiff =
    { id : Int, name : String }


type alias Courtroom =
    { id : Int, name : String }


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
    { claimsFees : Maybe Float
    , claimsPossession : Bool
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
    , fileDate : Date
    , enteredBy : Entrance
    , judge : Maybe Judge
    , conditions : Conditions
    }


type alias DetainerWarrant =
    { docketId : String
    , fileDate : Date
    , status : Status
    , plaintiff : Maybe Plaintiff
    , plaintiffAttorney : Maybe Attorney
    , courtDate : Maybe Date
    , courtroom : Maybe Courtroom
    , presidingJudge : Maybe Judge
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
    , fileDate : String
    , inFavorOf : String
    , judge : Maybe Judge

    -- Plaintiff Favor
    , claimsFees : Maybe Float
    , claimsPossession : Maybe Bool
    , hasInterest : Bool
    , interestRate : Maybe Float
    , interestFollowsSite : Maybe Bool

    -- Tenant Favor
    , dismissalBasis : Maybe String
    , withPrejudice : Maybe Bool
    }


type alias JudgeForm =
    { person : Maybe Judge
    , text : String
    , searchBox : SearchBox.State
    }


type alias JudgementForm =
    { id : Maybe Int
    , conditionsDropdown : Dropdown.State ConditionOption
    , condition : ConditionOption
    , enteredBy : Entrance
    , fileDate : DatePickerState
    , notes : String
    , claimsFees : String
    , claimsPossession : Bool
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
    , fileDate =
        form.fileDate.date
            |> Maybe.withDefault today
            |> Date.toIsoString
    , enteredBy = Just <| entranceText form.enteredBy
    , inFavorOf =
        case form.condition of
            PlaintiffOption ->
                "PLAINTIFF"

            DefendantOption ->
                "DEFENDANT"
    , claimsFees =
        if form.claimsFees == "" then
            Nothing

        else
            String.toFloat <| String.replace "," "" form.claimsFees
    , claimsPossession =
        if form.condition == DefendantOption then
            Nothing

        else
            Just form.claimsPossession
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
        if form.condition == DefendantOption then
            Just (dismissalBasisText form.dismissalBasis)

        else
            Nothing
    , withPrejudice =
        if form.condition == DefendantOption then
            Just form.withPrejudice

        else
            Nothing
    , judge =
        form.judge.person
    }


type alias DetainerWarrantEdit =
    { docketId : String
    , fileDate : String
    , status : Status
    , plaintiff : Maybe Related
    , plaintiffAttorney : Maybe Related
    , courtDate : Maybe String
    , courtroom : Maybe Related
    , presidingJudge : Maybe Related
    , amountClaimed : Maybe Float
    , amountClaimedCategory : AmountClaimedCategory
    , isCares : Maybe Bool
    , isLegacy : Maybe Bool
    , nonpayment : Maybe Bool
    , defendants : List Related
    , judgements : List JudgementEdit
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


statusOptions : List Status
statusOptions =
    [ Pending, Closed ]


amountClaimedCategoryOptions : List AmountClaimedCategory
amountClaimedCategoryOptions =
    [ NotApplicable, Possession, Fees, Both ]


dismissalBasisOptions : List DismissalBasis
dismissalBasisOptions =
    [ FailureToProsecute, FindingInFavorOfDefendant, NonSuitByPlaintiff ]


type ConditionOption
    = PlaintiffOption
    | DefendantOption


conditionsOptions : List ConditionOption
conditionsOptions =
    [ PlaintiffOption, DefendantOption ]


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


statusDecoder : Decoder Status
statusDecoder =
    Decode.string
        |> Decode.andThen
            (\str ->
                case str of
                    "CLOSED" ->
                        Decode.succeed Closed

                    "PENDING" ->
                        Decode.succeed Pending

                    somethingElse ->
                        Decode.fail <| "Unknown status:" ++ somethingElse
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
        |> required "claims_fees" (nullable float)
        |> required "claims_possession" bool
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
        |> required "dismissal_basis" dismissalBasisDecoder
        |> required "with_prejudice" bool


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


fromConditions : Conditions -> Decoder Judgement
fromConditions conditions =
    Decode.succeed Judgement
        |> required "id" int
        |> required "notes" (nullable string)
        |> required "file_date" dateDecoder
        |> required "entered_by" entranceDecoder
        |> required "judge" (nullable judgeDecoder)
        |> custom (Decode.succeed conditions)


judgementDecoder : Decoder Judgement
judgementDecoder =
    Decode.field "in_favor_of" string
        |> Decode.andThen
            (\str ->
                case str of
                    "PLAINTIFF" ->
                        Decode.map PlaintiffConditions owedConditionsDecoder

                    "DEFENDANT" ->
                        Decode.map DefendantConditions dismissalConditionsDecoder

                    _ ->
                        Decode.fail "oops"
            )
        |> Decode.andThen fromConditions


attorneyDecoder : Decoder Attorney
attorneyDecoder =
    Decode.succeed Attorney
        |> required "id" int
        |> required "name" string


courtroomDecoder : Decoder Courtroom
courtroomDecoder =
    Decode.succeed Courtroom
        |> required "id" int
        |> required "name" string


judgeDecoder : Decoder Judge
judgeDecoder =
    Decode.succeed Judge
        |> required "id" int
        |> required "name" string


plaintiffDecoder : Decoder Plaintiff
plaintiffDecoder =
    Decode.succeed Plaintiff
        |> required "id" int
        |> required "name" string


dateDecoder : Decoder Date
dateDecoder =
    Decode.map (Maybe.withDefault (Date.fromCalendarDate 2021 Jan 1) << Result.toMaybe << Date.fromIsoString) Decode.string


decoder : Decoder DetainerWarrant
decoder =
    Decode.succeed DetainerWarrant
        |> required "docket_id" string
        |> required "file_date" dateDecoder
        |> required "status" statusDecoder
        |> required "plaintiff" (nullable plaintiffDecoder)
        |> required "plaintiff_attorney" (nullable attorneyDecoder)
        |> required "court_date" (nullable dateDecoder)
        |> required "courtroom" (nullable courtroomDecoder)
        |> required "presiding_judge" (nullable judgeDecoder)
        |> required "amount_claimed" (nullable float)
        |> required "amount_claimed_category" amountClaimedCategoryDecoder
        |> required "is_cares" (nullable bool)
        |> required "is_legacy" (nullable bool)
        |> required "nonpayment" (nullable bool)
        |> required "defendants" (list Defendant.decoder)
        |> required "judgements" (list judgementDecoder)
        |> required "notes" (nullable string)
