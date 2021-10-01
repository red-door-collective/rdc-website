module Plaintiff exposing (Plaintiff, decoder, tableColumns, toTableCover, toTableDetails, toTableRow, toTableRowView)

import Json.Decode as Decode exposing (Decoder, Value, bool, float, int, list, nullable, string)
import Json.Decode.Pipeline exposing (custom, hardcoded, optional, required)
import UI.Button as Button exposing (Button)
import UI.Tables.Common as Common exposing (Columns, Row, cellFromButton, cellFromText, columnWidthPixels, columnsEmpty, rowCellButton, rowCellText, rowEmpty)
import UI.Tables.Stateful exposing (detailHidden, detailShown, detailsEmpty, filtersEmpty, localSingleTextFilter)
import UI.Text as Text
import UI.Utils.TypeNumbers as T


type alias Plaintiff =
    { id : Int
    , name : String
    , aliases : List String
    }


decoder : Decoder Plaintiff
decoder =
    Decode.succeed Plaintiff
        |> required "id" int
        |> required "name" string
        |> required "aliases" (list string)


tableColumns : Columns T.Three
tableColumns =
    columnsEmpty
        |> Common.column "Name" (columnWidthPixels 300)
        |> Common.column "Aliases" (columnWidthPixels 300)
        |> Common.column "" (columnWidthPixels 100)


toTableRow :
    (Plaintiff -> Button msg)
    ->
        { toKey : Plaintiff -> String
        , view : Plaintiff -> Row msg T.Three
        }
toTableRow toEditButton =
    { toKey = .name, view = toTableRowView toEditButton }


toTableRowView : (Plaintiff -> Button msg) -> Plaintiff -> Row msg T.Three
toTableRowView toEditButton ({ name, aliases } as plaintiff) =
    rowEmpty
        |> rowCellText (Text.body2 name)
        |> rowCellText (Text.body2 <| String.join ", " aliases)
        |> rowCellButton (toEditButton plaintiff)


toTableDetails toEditButton ({ name, aliases } as plaintiff) =
    detailsEmpty
        |> detailShown
            { label = "Name"
            , content =
                name
                    |> Text.body2
                    |> Text.withOverflow Text.ellipsize
                    |> cellFromText
            }
        |> detailShown
            { label = "Aliases"
            , content = cellFromText <| Text.body2 (String.join ", " aliases)
            }
        |> detailShown
            { label = "Edit"
            , content = cellFromButton (toEditButton plaintiff)
            }


toTableCover { name, aliases } =
    { title = name, caption = Just <| String.join ", " aliases }
