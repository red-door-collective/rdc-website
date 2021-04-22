module DetainerWarrant exposing (AmountClaimedCategory(..), Attorney, Courtroom, DetainerWarrant, DetainerWarrantEdit, Judge, Judgement(..), Plaintiff, Status(..), amountClaimedCategoryOptions, amountClaimedCategoryText, attorneyDecoder, courtroomDecoder, dateDecoder, decoder, judgeDecoder, judgementOptions, judgementText, plaintiffDecoder, statusOptions, statusText, ternaryOptions)

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
    { id : Int, name : String }


type alias Courtroom =
    { id : Int, name : String }


type Judgement
    = NonSuit
    | Poss
    | PossAndPayment
    | Dismissed
    | FeesOnly
    | NotAvailable


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
    , judgement : Judgement
    , notes : Maybe String
    }


type alias Related =
    { id : Int }


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
    , judgement : Judgement
    , notes : Maybe String
    }


ternaryOptions : List (Maybe Bool)
ternaryOptions =
    [ Nothing, Just True, Just False ]


statusOptions : List Status
statusOptions =
    [ Pending, Closed ]


amountClaimedCategoryOptions : List AmountClaimedCategory
amountClaimedCategoryOptions =
    [ NotApplicable, Possession, Fees, Both ]


judgementOptions : List Judgement
judgementOptions =
    [ NotAvailable, NonSuit, Poss, PossAndPayment, Dismissed, FeesOnly ]


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
            "POSS + PAYMENT"

        Dismissed ->
            "DISMISSED"

        NotAvailable ->
            "N/A"

        FeesOnly ->
            "FEES ONLY"



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
                    "NON-SUIT" ->
                        Decode.succeed NonSuit

                    "POSS" ->
                        Decode.succeed Poss

                    "POSS + PAYMENT" ->
                        Decode.succeed PossAndPayment

                    "DISMISSED" ->
                        Decode.succeed Dismissed

                    "FEES ONLY" ->
                        Decode.succeed FeesOnly

                    "N/A" ->
                        Decode.succeed NotAvailable

                    _ ->
                        Decode.succeed NotAvailable
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
        |> required "judgement" judgementDecoder
        |> required "notes" (nullable string)
