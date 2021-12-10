module Hearing exposing (Hearing, decoder, tableColumns, toTableRow, toTableRowView)

import Attorney exposing (Attorney)
import Courtroom exposing (Courtroom)
import Date
import Json.Decode as Decode exposing (Decoder, int, nullable)
import Json.Decode.Pipeline exposing (required)
import Judgment exposing (Judgment)
import Plaintiff exposing (Plaintiff)
import Time exposing (Posix)
import Time.Utils exposing (posixDecoder)
import UI.Button exposing (Button)
import UI.Tables.Common as Common exposing (Row, cellFromButton, cellFromText, columnWidthPixels, columnsEmpty, rowCellButton, rowCellText, rowEmpty)
import UI.Tables.Stateless
import UI.Text as Text
import UI.Utils.TypeNumbers as T


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


tableColumns =
    columnsEmpty
        |> Common.column "Court date" (columnWidthPixels 150)
        |> Common.column "Plaintiff" (columnWidthPixels 240)
        |> Common.column "Pltf. Attorney" (columnWidthPixels 240)
        |> Common.column "" (columnWidthPixels 100)


toTableRow : (Hearing -> Button msg) -> { toKey : Hearing -> String, view : Hearing -> Row msg T.Four }
toTableRow toEditButton =
    { toKey = String.fromInt << .id
    , view = toTableRowView toEditButton
    }


toTableRowView : (Hearing -> Button msg) -> Hearing -> Row msg T.Four
toTableRowView toEditButton ({ plaintiff, plaintiffAttorney } as hearing) =
    rowEmpty
        |> rowCellText (Text.body2 (Time.Utils.toIsoString hearing.courtDate))
        |> rowCellText (Text.body2 (Maybe.withDefault "" <| Maybe.map .name plaintiff))
        |> rowCellText (Text.body2 (Maybe.withDefault "" <| Maybe.map .name plaintiffAttorney))
        |> rowCellButton (toEditButton hearing)



-- toTableDetails toEditButton ({ plaintiff, plaintiffAttorney } as hearing) =
--     detailsEmpty
--         |> detailShown
--             { label = "Court date"
--             , content = cellFromText <| Text.body2 (Time.Utils.toIsoString hearing.courtDate)
--             }
--         |> detailShown
--             { label = "Plaintiff"
--             , content = cellFromText <| Text.body2 (Maybe.withDefault "" <| Maybe.map .name plaintiff)
--             }
--         |> detailShown
--             { label = "Pltf. Attorney"
--             , content = cellFromText <| Text.body2 (Maybe.withDefault "" <| Maybe.map .name plaintiffAttorney)
--             }
--         |> detailShown
--             { label = "Edit"
--             , content = cellFromButton (toEditButton hearing)
--             }
-- toTableCover { courtDate } =
--     { title = Date.format "MMMM ddd, yyyy" courtDate, caption = Nothing }
