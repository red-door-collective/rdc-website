module PleadingDocument exposing (Kind, PleadingDocument, decoder, isJudgment)

import Json.Decode as Decode exposing (Decoder, nullable, string)
import Json.Decode.Pipeline exposing (required)
import Time exposing (Posix)
import Time.Utils exposing (posixDecoder)
import Url exposing (Url)


type Kind
    = DetainerWarrantDocument
    | JudgmentDocument


type alias PleadingDocument =
    { url : Url
    , kind : Maybe Kind
    , text : Maybe String
    , createdAt : Posix
    , updatedAt : Posix
    }


isJudgment : PleadingDocument -> Bool
isJudgment pleading =
    pleading.kind == Just JudgmentDocument


kindDecoder : Decoder Kind
kindDecoder =
    Decode.string
        |> Decode.andThen
            (\str ->
                case kindFromText str of
                    Ok kind ->
                        Decode.succeed kind

                    Err msg ->
                        Decode.fail msg
            )


kindFromText : String -> Result String Kind
kindFromText str =
    case str of
        "JUDGMENT" ->
            Result.Ok JudgmentDocument

        "DETAINER_WARRANT" ->
            Result.Ok DetainerWarrantDocument

        _ ->
            Result.Err "Invalid Kind"


urlDecoder : Decoder Url
urlDecoder =
    Decode.string
        |> Decode.andThen
            (\str ->
                case Url.fromString str of
                    Just url ->
                        Decode.succeed url

                    Nothing ->
                        Decode.fail "Invalid URL"
            )


decoder : Decoder PleadingDocument
decoder =
    Decode.succeed PleadingDocument
        |> required "url" urlDecoder
        |> required "kind" (nullable kindDecoder)
        |> required "text" (nullable string)
        |> required "created_at" posixDecoder
        |> required "updated_at" posixDecoder
