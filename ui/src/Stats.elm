module Stats exposing
    ( DetainerWarrantsPerMonth
    , EvictionHistory
    , PlantiffAttorneyWarrantCount
    , TopEvictor
    , detainerWarrantsPerMonthDecoder
    , evictionHistoryDecoder
    , plantiffAttorneyWarrantCountDecoder
    , topEvictorDecoder
    )

import Api exposing (posix)
import Json.Decode as Decode exposing (Decoder, Value, bool, float, int, list, nullable, string)
import Json.Decode.Pipeline exposing (optional, required)
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


type alias PlantiffAttorneyWarrantCount =
    { warrantCount : Int
    , plantiffAttorneyName : String
    , startDate : Time.Posix
    , endDate : Time.Posix
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
        |> required "totalWarrants" int


plantiffAttorneyWarrantCountDecoder : Decoder PlantiffAttorneyWarrantCount
plantiffAttorneyWarrantCountDecoder =
    Decode.succeed PlantiffAttorneyWarrantCount
        |> required "warrant_count" int
        |> required "plantiff_attorney_name" string
        |> required "start_date" posix
        |> required "end_date" posix
