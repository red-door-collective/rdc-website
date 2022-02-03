module DetainerWarrant exposing (Description, DetainerWarrant, DetainerWarrantEdit, Status(..), decoder, description, mostRecentCourtDate, statusHumanReadable, statusOptions, statusText, tableColumns, ternaryOptions, toTableCover, toTableDetails, toTableRow)

import Attorney exposing (Attorney)
import Hearing exposing (Hearing)
import Json.Decode as Decode exposing (Decoder, bool, float, list, nullable, string)
import Json.Decode.Pipeline exposing (required)
import Maybe
import Plaintiff exposing (Plaintiff)
import PleadingDocument exposing (PleadingDocument)
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
    , address : Maybe String
    , fileDate : Maybe Posix
    , status : Maybe Status
    , plaintiff : Maybe Plaintiff
    , plaintiffAttorney : Maybe Attorney
    , amountClaimed : Maybe Float
    , claimsPossession : Maybe Bool
    , isCares : Maybe Bool
    , isLegacy : Maybe Bool
    , nonpayment : Maybe Bool
    , hearings : List Hearing
    , notes : Maybe String
    , document : Maybe PleadingDocument
    }


type alias Related =
    { id : Int }


type alias DetainerWarrantEdit =
    { docketId : String
    , address : Maybe String
    , fileDate : Maybe Posix
    , status : Maybe Status
    , plaintiff : Maybe Related
    , plaintiffAttorney : Maybe Related
    , amountClaimed : Maybe Float
    , claimsPossession : Maybe Bool
    , isCares : Maybe Bool
    , isLegacy : Maybe Bool
    , nonpayment : Maybe Bool
    , notes : Maybe String
    }


type alias Description =
    { docketId : String
    , address : String
    , fileDate : String
    , status : String
    , plaintiff : String
    , plaintiffAttorney : String
    , amountClaimed : String
    , claimsPossession : String
    , cares : String
    , legacy : String
    , nonpayment : String
    , notes : String
    }


description : Description
description =
    { docketId = "This is the unique id for a detainer warrant. Please take care when entering this."
    , address = "The address where the defendant or defendants reside."
    , fileDate = "The date the detainer warrant was created in the court system."
    , status = "The current status of the case in the court system."
    , plaintiff = "The plaintiff is typically the landlord seeking money or possession from the defendant (tenant)."
    , plaintiffAttorney = "The plaintiff attorney is the legal representation for the plaintiff in the eviction process."
    , amountClaimed = "The monetary amount the plaintiff is requesting from the defendant."
    , claimsPossession = "Plaintiffs may ask for payment, repossession, or more."
    , cares = "C.A.R.E.S. was an aid package provided during the pandemic. If a docket number has a \"Notice,\" check to see whether the property falls under the CARES act"
    , legacy = "L.E.G.A.C.Y. is a special court created for handling evictions during the pandemic. Looks up cases listed under \"LEGACY Case DW Numbers\" tab and check if the case is there or not."
    , nonpayment = "People can be evicted for a number of reasons, including non-payment of rent. We want to know if people are being evicted for this reason because those cases should go to the diversionary court. We assume cases that request $$ are for non-payment but this box is sometimes checked on eviction forms."
    , notes = "Any additional notes you have about this case go here! This is a great place to leave feedback for the form as well, perhaps there's another field or field option we need to provide."
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


statusHumanReadable : Status -> String
statusHumanReadable status =
    case status of
        Closed ->
            "Closed"

        Pending ->
            "Pending"


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
        |> required "address" (nullable string)
        |> required "file_date" (nullable posixDecoder)
        |> required "status" (nullable statusDecoder)
        |> required "plaintiff" (nullable Plaintiff.decoder)
        |> required "plaintiff_attorney" (nullable Attorney.decoder)
        |> required "amount_claimed" (nullable float)
        |> required "claims_possession" (nullable bool)
        |> required "is_cares" (nullable bool)
        |> required "is_legacy" (nullable bool)
        |> required "nonpayment" (nullable bool)
        |> required "hearings" (list Hearing.decoder)
        |> required "notes" (nullable string)
        |> required "document" (nullable PleadingDocument.decoder)


tableColumns =
    columnsEmpty
        |> Common.column "Docket ID" (columnWidthPixels 150)
        |> Common.column "File date" (columnWidthPixels 150)
        |> Common.column "Court date" (columnWidthPixels 150)
        |> Common.column "Plaintiff" (columnWidthPixels 240)
        |> Common.column "Pltf. Attorney" (columnWidthPixels 240)
        |> Common.column "Address" (columnWidthPixels 240)
        |> Common.column "" (columnWidthPixels 100)


toTableRow : (DetainerWarrant -> Button msg) -> { toKey : DetainerWarrant -> String, view : DetainerWarrant -> Row msg T.Seven }
toTableRow toEditButton =
    { toKey = .docketId, view = toTableRowView toEditButton }


mostRecentCourtDate : DetainerWarrant -> Maybe Posix
mostRecentCourtDate warrant =
    Maybe.map .courtDate <| List.head warrant.hearings


toTableRowView : (DetainerWarrant -> Button msg) -> DetainerWarrant -> Row msg T.Seven
toTableRowView toEditButton ({ docketId, fileDate, plaintiff, plaintiffAttorney, address } as warrant) =
    rowEmpty
        |> rowCellText (Text.body2 docketId)
        |> rowCellText (Text.body2 (Maybe.withDefault "" <| Maybe.map Time.Utils.toIsoString fileDate))
        |> rowCellText (Text.body2 (Maybe.withDefault "" <| Maybe.map Time.Utils.toIsoString (mostRecentCourtDate warrant)))
        |> rowCellText (Text.body2 (Maybe.withDefault "" <| Maybe.map .name plaintiff))
        |> rowCellText (Text.body2 (Maybe.withDefault "" <| Maybe.map .name plaintiffAttorney))
        |> rowCellText (Text.body2 (Maybe.withDefault "" <| address))
        |> rowCellButton (toEditButton warrant)


toTableDetails toEditButton ({ docketId, fileDate, plaintiff, plaintiffAttorney, address } as warrant) =
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
            { label = "Address"
            , content = cellFromText <| Text.body2 (Maybe.withDefault "" <| address)
            }
        |> detailShown
            { label = "Edit"
            , content = cellFromButton (toEditButton warrant)
            }


toTableCover { docketId, address } =
    { title = docketId, caption = address }
