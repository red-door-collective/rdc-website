module DetainerWarrant exposing (AmountClaimedCategory(..), Attorney, Courtroom, DetainerWarrant, Judge, Judgement(..), Plaintiff, Status(..), decoder, statusText)

import Defendant exposing (Defendant)
import Json.Decode as Decode exposing (Decoder, Value, bool, float, int, list, nullable, string)
import Json.Decode.Pipeline exposing (optional, required)


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
    , fileDate : String
    , status : Status
    , plaintiff : Maybe Plaintiff
    , courtDate : Maybe String
    , courtroom : Maybe Courtroom
    , presidingJudge : Maybe Judge
    , amountClaimed : Maybe Float
    , amountClaimedCategory : Maybe AmountClaimedCategory
    , defendants : List Defendant
    , judgement : Maybe Judgement
    }


statusText : DetainerWarrant -> String
statusText warrant =
    case warrant.status of
        Closed ->
            "Closed"

        Pending ->
            "Pending"



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


decoder : Decoder DetainerWarrant
decoder =
    Decode.succeed DetainerWarrant
        |> required "docket_id" string
        |> required "file_date" string
        |> required "status" statusDecoder
        |> required "plaintiff" (nullable plaintiffDecoder)
        |> required "court_date" (nullable string)
        |> required "courtroom" (nullable courtroomDecoder)
        |> required "presiding_judge" (nullable judgeDecoder)
        |> required "amount_claimed" (nullable float)
        |> required "amount_claimed_category" (nullable amountClaimedCategoryDecoder)
        |> required "defendants" (list Defendant.decoder)
        |> required "judgement" (nullable judgementDecoder)
