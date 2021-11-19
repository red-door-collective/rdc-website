module DetainerWarrant exposing (DetainerWarrant, DetainerWarrantEdit, Status(..), decoder, mostRecentCourtDate, statusFromText, statusOptions, statusText, tableColumns, ternaryOptions, toTableCover, toTableDetails, toTableRow)

import Attorney exposing (Attorney)
import Defendant exposing (Defendant)
import Json.Decode as Decode exposing (Decoder, bool, float, list, nullable, string)
import Json.Decode.Pipeline exposing (required)
import Judgment exposing (Judgment)
import Maybe
import Plaintiff exposing (Plaintiff)
import Time exposing (Posix)
import Time.Utils exposing (posixDecoder)
import UI.Button exposing (Button)
import UI.Tables.Common as Common exposing (Row, cellFromButton, cellFromText, columnWidthPixels, columnsEmpty, rowCellButton, rowCellText, rowEmpty)
import UI.Tables.Stateful exposing (detailShown, detailsEmpty)
import UI.Text as Text
import UI.Utils.TypeNumbers as T


type Status
    = Closed
    | Pending


type alias DetainerWarrant =
    { docketId : String
    , fileDate : Maybe Posix
    , status : Maybe Status
    , plaintiff : Maybe Plaintiff
    , plaintiffAttorney : Maybe Attorney
    , amountClaimed : Maybe Float
    , claimsPossession : Maybe Bool
    , isCares : Maybe Bool
    , isLegacy : Maybe Bool
    , nonpayment : Maybe Bool
    , defendants : List Defendant
    , judgments : List Judgment
    , notes : Maybe String
    }


type alias Related =
    { id : Int }


type alias DetainerWarrantEdit =
    { docketId : String
    , fileDate : Maybe Posix
    , status : Maybe Status
    , plaintiff : Maybe Related
    , plaintiffAttorney : Maybe Related
    , amountClaimed : Maybe Float
    , claimsPossession : Maybe Bool
    , isCares : Maybe Bool
    , isLegacy : Maybe Bool
    , nonpayment : Maybe Bool
    , defendants : List Related
    , notes : Maybe String
    }


ternaryOptions : List (Maybe Bool)
ternaryOptions =
    [ Nothing, Just True, Just False ]


statusOptions : List (Maybe Status)
statusOptions =
    [ Nothing, Just Pending, Just Closed ]


statusText : Status -> String
statusText status =
    case status of
        Closed ->
            "CLOSED"

        Pending ->
            "PENDING"


statusFromText : String -> Result String Status
statusFromText str =
    case str of
        "CLOSED" ->
            Result.Ok Closed

        "PENDING" ->
            Result.Ok Pending

        _ ->
            Result.Err "Invalid Status"


statusDecoder : Decoder Status
statusDecoder =
    Decode.string
        |> Decode.andThen
            (\str ->
                case statusFromText str of
                    Ok status ->
                        Decode.succeed status

                    Err msg ->
                        Decode.fail msg
            )


decoder : Decoder DetainerWarrant
decoder =
    Decode.succeed DetainerWarrant
        |> required "docket_id" string
        |> required "file_date" (nullable posixDecoder)
        |> required "status" (nullable statusDecoder)
        |> required "plaintiff" (nullable Plaintiff.decoder)
        |> required "plaintiff_attorney" (nullable Attorney.decoder)
        |> required "amount_claimed" (nullable float)
        |> required "claims_possession" (nullable bool)
        |> required "is_cares" (nullable bool)
        |> required "is_legacy" (nullable bool)
        |> required "nonpayment" (nullable bool)
        |> required "defendants" (list Defendant.decoder)
        |> required "judgments" (list Judgment.decoder)
        |> required "notes" (nullable string)


tableColumns =
    columnsEmpty
        |> Common.column "Docket ID" (columnWidthPixels 150)
        |> Common.column "File date" (columnWidthPixels 150)
        |> Common.column "Court date" (columnWidthPixels 150)
        |> Common.column "Plaintiff" (columnWidthPixels 240)
        |> Common.column "Pltf. Attorney" (columnWidthPixels 240)
        |> Common.column "Defendant" (columnWidthPixels 240)
        |> Common.column "Address" (columnWidthPixels 240)
        |> Common.column "" (columnWidthPixels 100)


toTableRow : (DetainerWarrant -> Button msg) -> { toKey : DetainerWarrant -> String, view : DetainerWarrant -> Row msg T.Eight }
toTableRow toEditButton =
    { toKey = .docketId, view = toTableRowView toEditButton }


mostRecentCourtDate : DetainerWarrant -> Maybe Posix
mostRecentCourtDate warrant =
    Maybe.andThen .courtDate <| List.head warrant.judgments


toTableRowView : (DetainerWarrant -> Button msg) -> DetainerWarrant -> Row msg T.Eight
toTableRowView toEditButton ({ docketId, fileDate, plaintiff, plaintiffAttorney, defendants } as warrant) =
    rowEmpty
        |> rowCellText (Text.body2 docketId)
        |> rowCellText (Text.body2 (Maybe.withDefault "" <| Maybe.map Time.Utils.toIsoString fileDate))
        |> rowCellText (Text.body2 (Maybe.withDefault "" <| Maybe.map Time.Utils.toIsoString (mostRecentCourtDate warrant)))
        |> rowCellText (Text.body2 (Maybe.withDefault "" <| Maybe.map .name plaintiff))
        |> rowCellText (Text.body2 (Maybe.withDefault "" <| Maybe.map .name plaintiffAttorney))
        |> rowCellText (Text.body2 (Maybe.withDefault "" <| Maybe.map .name <| List.head defendants))
        |> rowCellText (Text.body2 (Maybe.withDefault "" <| Maybe.map .address <| List.head defendants))
        |> rowCellButton (toEditButton warrant)


toTableDetails toEditButton ({ docketId, fileDate, plaintiff, plaintiffAttorney, defendants } as warrant) =
    detailsEmpty
        |> detailShown
            { label = "Docket ID"
            , content = cellFromText <| Text.body2 docketId
            }
        |> detailShown
            { label = "File date"
            , content = cellFromText <| Text.body2 (Maybe.withDefault "" <| Maybe.map Time.Utils.toIsoString fileDate)
            }
        |> detailShown
            { label = "Court date"
            , content = cellFromText <| Text.body2 (Maybe.withDefault "" <| Maybe.map Time.Utils.toIsoString (mostRecentCourtDate warrant))
            }
        |> detailShown
            { label = "Plaintiff"
            , content = cellFromText <| Text.body2 (Maybe.withDefault "" <| Maybe.map .name plaintiff)
            }
        |> detailShown
            { label = "Pltf. Attorney"
            , content = cellFromText <| Text.body2 (Maybe.withDefault "" <| Maybe.map .name plaintiffAttorney)
            }
        |> detailShown
            { label = "Defendant"
            , content = cellFromText <| Text.body2 (Maybe.withDefault "" <| Maybe.map .name <| List.head defendants)
            }
        |> detailShown
            { label = "Address"
            , content = cellFromText <| Text.body2 (Maybe.withDefault "" <| Maybe.map .address <| List.head defendants)
            }
        |> detailShown
            { label = "Edit"
            , content = cellFromButton (toEditButton warrant)
            }


toTableCover { docketId, defendants } =
    { title = docketId, caption = Maybe.map .address <| List.head defendants }
