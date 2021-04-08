module DetainerWarrant exposing (AmountClaimedCategory(..), Attorney, Courtroom, DetainerWarrant, DetainerWarrantEdit, Judge, Judgement(..), Plaintiff, Status(..), amountClaimedCategoryText, attorneyDecoder, courtroomDecoder, decoder, editDecoder, judgeDecoder, judgementText, plaintiffDecoder, statusText)

import Date exposing (Date)
import Defendant exposing (Defendant)
import Json.Decode as Decode exposing (Decoder, Value, bool, float, int, list, nullable, string)
import Json.Decode.Pipeline exposing (optional, required)
import Time exposing (Month(..))


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
    { id : Int, name : String, attorney : Maybe Attorney }


type alias Courtroom =
    { id : Int, name : String }


type Judgement
    = NonSuit
    | Poss
    | PossAndPayment
    | Dismissed


type alias DetainerWarrant =
    { docketId : String
    , fileDate : Date
    , status : Status
    , plaintiff : Maybe Plaintiff
    , courtDate : Maybe Date
    , courtroom : Maybe Courtroom
    , presidingJudge : Maybe Judge
    , amountClaimed : Maybe Float
    , amountClaimedCategory : Maybe AmountClaimedCategory
    , isCares : Maybe Bool
    , isLegacy : Maybe Bool
    , nonpayment : Maybe Bool
    , defendants : List Defendant
    , judgement : Maybe Judgement
    , notes : Maybe String
    }


type alias DetainerWarrantEdit =
    { docketId : String
    , fileDate : String
    , status : Status
    , plaintiffId : Maybe Int
    , courtDate : Maybe String
    , courtroomId : Maybe Int
    , presidingJudgeId : Maybe Int
    , amountClaimed : Maybe Float
    , amountClaimedCategory : Maybe AmountClaimedCategory
    , isCares : Maybe Bool
    , isLegacy : Maybe Bool
    , nonpayment : Maybe Bool
    , defendants : List Int
    , judgement : Maybe Judgement
    , notes : Maybe String
    }


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


judgementText : Judgement -> String
judgementText judgement =
    case judgement of
        NonSuit ->
            "Non-suit"

        Poss ->
            "POSS"

        PossAndPayment ->
            "POSS + Payment"

        Dismissed ->
            "Dismissed"



-- SERIALIZATION


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


judgementDecoder : Decoder Judgement
judgementDecoder =
    Decode.string
        |> Decode.andThen
            (\str ->
                case str of
                    "Non-suit" ->
                        Decode.succeed NonSuit

                    "POSS" ->
                        Decode.succeed Poss

                    "POSS + Payment" ->
                        Decode.succeed PossAndPayment

                    "Dismissed" ->
                        Decode.succeed Dismissed

                    _ ->
                        Decode.succeed Dismissed
            )


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
        |> required "attorney" (nullable attorneyDecoder)


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
        |> required "court_date" (nullable dateDecoder)
        |> required "courtroom" (nullable courtroomDecoder)
        |> required "presiding_judge" (nullable judgeDecoder)
        |> required "amount_claimed" (nullable float)
        |> required "amount_claimed_category" (nullable amountClaimedCategoryDecoder)
        |> required "is_cares" (nullable bool)
        |> required "is_legacy" (nullable bool)
        |> required "nonpayment" (nullable bool)
        |> required "defendants" (list Defendant.decoder)
        |> required "judgement" (nullable judgementDecoder)
        |> required "notes" (nullable string)


editDecoder : Decoder DetainerWarrantEdit
editDecoder =
    Decode.succeed DetainerWarrantEdit
        |> required "docket_id" string
        |> required "file_date" string
        |> required "status" statusDecoder
        |> required "plaintiff_id" (nullable int)
        |> required "court_date" (nullable string)
        |> required "courtroom_id" (nullable int)
        |> required "presiding_judge_id" (nullable int)
        |> required "amount_claimed" (nullable float)
        |> required "amount_claimed_category" (nullable amountClaimedCategoryDecoder)
        |> required "is_cares" (nullable bool)
        |> required "is_legacy" (nullable bool)
        |> required "nonpayment" (nullable bool)
        |> required "defendants" (list int)
        |> required "judgement" (nullable judgementDecoder)
        |> required "notes" (nullable string)
