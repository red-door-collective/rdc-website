module Hearing exposing (Hearing, decoder)

import Attorney exposing (Attorney)
import Courtroom exposing (Courtroom)
import Json.Decode as Decode exposing (Decoder, bool, float, int, nullable, string)
import Json.Decode.Pipeline exposing (custom, optional, required)
import Judgment exposing (Judgment)
import Plaintiff exposing (Plaintiff)
import Time exposing (Posix)
import Time.Utils exposing (posixDecoder)


type alias Hearing =
    { id : Int
    , courtDate : Posix
    , courtroom : Maybe Courtroom
    , plaintiff : Maybe Plaintiff
    , plaintiffAttorney : Maybe Attorney
    , defendantAttorney : Maybe Attorney
    , judgment : Maybe Judgment
    }


decoder : Decoder Hearing
decoder =
    Decode.succeed Hearing
        |> required "id" int
        |> required "court_date" posixDecoder
        |> required "courtroom" (nullable Courtroom.decoder)
        |> required "plaintiff" (nullable Plaintiff.decoder)
        |> required "plaintiff_attorney" (nullable Attorney.decoder)
        |> required "defendant_attorney" (nullable Attorney.decoder)
        |> required "judgment" (nullable Judgment.decoder)
