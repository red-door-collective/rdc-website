module Stats exposing
    ( AmountAwardedMonth
    , DetainerWarrantsPerMonth
    , EvictionHistory
    , PlaintiffAttorneyWarrantCount
    , TopEvictor
    , amountAwardedMonthDecoder
    , detainerWarrantsPerMonthDecoder
    , evictionHistoryDecoder
    , plaintiffAttorneyWarrantCountDecoder
    , topEvictorDecoder
    )

import Json.Decode as Decode exposing (Decoder, Value, bool, float, int, list, nullable, string)
import Json.Decode.Pipeline exposing (optional, required)
import Rest exposing (posix)
import Time


type alias EvictionHistory =
    { date : Float
    , evictionCount : Float
    }


type alias TopEvictor =
    { name : String
    , history : List EvictionHistory
    }


type alias DetainerWarrantsPerMonth =
    { time : Time.Posix
    , totalWarrants : Int
    }


type alias PlaintiffAttorneyWarrantCount =
    { warrantCount : Int
    , plaintiffAttorneyName : String
    , startDate : Time.Posix
    , endDate : Time.Posix
    }


type alias AmountAwardedMonth =
    { time : Time.Posix
    , totalAmount : Int
    }


evictionHistoryDecoder : Decoder EvictionHistory
evictionHistoryDecoder =
    Decode.succeed EvictionHistory
        |> required "date" float
        |> required "eviction_count" float


topEvictorDecoder : Decoder TopEvictor
topEvictorDecoder =
    Decode.succeed TopEvictor
        |> required "name" string
        |> required "history" (list evictionHistoryDecoder)


detainerWarrantsPerMonthDecoder : Decoder DetainerWarrantsPerMonth
detainerWarrantsPerMonthDecoder =
    Decode.succeed DetainerWarrantsPerMonth
        |> required "time" posix
        |> required "total_warrants" int


plaintiffAttorneyWarrantCountDecoder : Decoder PlaintiffAttorneyWarrantCount
plaintiffAttorneyWarrantCountDecoder =
    Decode.succeed PlaintiffAttorneyWarrantCount
        |> required "warrant_count" int
        |> required "plaintiff_attorney_name" string
        |> required "start_date" posix
        |> required "end_date" posix


amountAwardedMonthDecoder : Decoder AmountAwardedMonth
amountAwardedMonthDecoder =
    Decode.succeed AmountAwardedMonth
        |> required "time" posix
        |> required "total_amount" int
