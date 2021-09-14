module Rest.Static exposing
    ( AmountAwardedMonth
    , DetainerWarrantsPerMonth
    , EvictionHistory
    , PlaintiffAttorneyWarrantCount
    , RollupMetadata
    , TopEvictor
    , amountAwardedMonthDecoder
    , api
    , detainerWarrantsPerMonthDecoder
    , evictionHistoryDecoder
    , plaintiffAttorneyWarrantCountDecoder
    , rollupMetadataDecoder
    , storageDecoder
    , topEvictorDecoder
    )

import OptimizedDecoder as Decode exposing (Decoder, Value, bool, float, int, list, nullable, string)
import OptimizedDecoder.Pipeline exposing (optional, required)
import Rest exposing (Cred(..))
import Time
import Url.Builder


type alias RollupMetadata =
    { lastWarrantUpdatedAt : Time.Posix }


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


api : String -> String -> String
api domain path =
    Url.Builder.crossOrigin domain [ "api", "v1", "rollup", path ] []


{-| It's important that this is never exposed!
We expose `login` and `application` instead, so we can be certain that if anyone
ever has access to a `Cred` value, it came from either the login API endpoint
or was passed in via flags.
-}
credDecoder : Decoder Cred
credDecoder =
    Decode.succeed Cred
        |> required "authentication_token" Decode.string


decoderFromCred : Decoder (Cred -> a) -> Decoder a
decoderFromCred decoder =
    Decode.map2 (\fromCred cred -> fromCred cred)
        decoder
        credDecoder


storageDecoder : Decoder (Cred -> viewer) -> Decoder viewer
storageDecoder viewerDecoder =
    Decode.field "user" (decoderFromCred viewerDecoder)


posix : Decoder Time.Posix
posix =
    Decode.map Time.millisToPosix int


rollupMetadataDecoder : Decoder RollupMetadata
rollupMetadataDecoder =
    Decode.succeed RollupMetadata
        |> required "last_detainer_warrant_update" posix


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
