module Judgement exposing (ConditionOption(..), Conditions(..), DismissalBasis(..), DismissalConditions, Entrance(..), Interest(..), Judgement, JudgementEdit, JudgementForm, OwedConditions, conditionText, conditionsOptions, decoder, dismissalBasisOption, dismissalBasisOptions, editFromForm)

import Attorney exposing (Attorney, AttorneyForm)
import Courtroom exposing (Courtroom)
import Date exposing (Date)
import Form.State exposing (DatePickerState)
import Json.Decode as Decode exposing (Decoder, bool, float, int, nullable, string)
import Json.Decode.Pipeline exposing (custom, optional, required)
import Judge exposing (Judge, JudgeForm)
import Plaintiff exposing (Plaintiff, PlaintiffForm)
import String.Extra
import Time exposing (Posix)
import Time.Utils exposing (posixDecoder)
import UI.Dropdown as Dropdown


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


type alias JudgementEdit =
    { id : Maybe Int
    , notes : Maybe String
    , enteredBy : Maybe String
    , courtDate : Maybe String
    , inFavorOf : Maybe String
    , plaintiff : Maybe Plaintiff
    , plaintiffAttorney : Maybe Attorney
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
    , plaintiff : PlaintiffForm
    , plaintiffAttorney : AttorneyForm
    , judge : JudgeForm
    }


type alias Judgement =
    { id : Int
    , notes : Maybe String
    , courtDate : Maybe Posix
    , courtroom : Maybe Courtroom
    , enteredBy : Entrance
    , plaintiff : Maybe Plaintiff
    , plaintiffAttorney : Maybe Attorney
    , judge : Maybe Judge
    , conditions : Maybe Conditions
    }


type ConditionOption
    = PlaintiffOption
    | DefendantOption


conditionsOptions : List (Maybe ConditionOption)
conditionsOptions =
    [ Nothing, Just PlaintiffOption, Just DefendantOption ]


dismissalBasisOptions : List DismissalBasis
dismissalBasisOptions =
    [ FailureToProsecute, FindingInFavorOfDefendant, NonSuitByPlaintiff ]


conditionText : ConditionOption -> String
conditionText option =
    case option of
        PlaintiffOption ->
            "Plaintiff"

        DefendantOption ->
            "Defendant"


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
    , plaintiff =
        form.plaintiff.person
    , plaintiffAttorney =
        form.plaintiffAttorney.person
    , judge =
        form.judge.person
    }


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
        |> required "plaintiff" (nullable Plaintiff.decoder)
        |> required "plaintiff_attorney" (nullable Attorney.decoder)
        |> required "judge" (nullable Judge.decoder)
        |> custom (Decode.succeed conditions)


decoder : Decoder Judgement
decoder =
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
