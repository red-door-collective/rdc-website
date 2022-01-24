module Defendant exposing (Defendant, decoder, tableColumns, toTableCover, toTableDetails, toTableRow, toTableRowView)

import Json.Decode as Decode exposing (Decoder, int, list, nullable, string)
import Json.Decode.Pipeline exposing (optional, required)
import UI.Button exposing (Button)
import UI.Tables.Common as Common exposing (Columns, Row, cellFromButton, cellFromText, columnWidthPixels, columnsEmpty, rowCellButton, rowCellText, rowEmpty)
import UI.Tables.Stateful exposing (detailShown, detailsEmpty)
import UI.Text as Text
import UI.Utils.TypeNumbers as T


type alias VerifiedPhone =
    { callerName : Maybe String
    , phoneType : Maybe String
    , nationalFormat : String
    }


type alias Defendant =
    { id : Int
    , name : String
    , firstName : String
    , middleName : Maybe String
    , lastName : String
    , suffix : Maybe String
    , aliases : List String
    , potentialPhones : Maybe String
    , verifiedPhone : Maybe VerifiedPhone
    }


verifiedPhoneDecoder : Decoder VerifiedPhone
verifiedPhoneDecoder =
    Decode.succeed VerifiedPhone
        |> required "caller_name" (nullable string)
        |> required "phone_type" (nullable string)
        |> required "national_format" string


decoder : Decoder Defendant
decoder =
    Decode.succeed Defendant
        |> required "id" int
        |> required "name" string
        |> optional "first_name" string ""
        |> required "middle_name" (nullable string)
        |> optional "last_name" string ""
        |> required "suffix" (nullable string)
        |> required "aliases" (list string)
        |> required "potential_phones" (nullable string)
        |> required "verified_phone" (nullable verifiedPhoneDecoder)


tableColumns : Columns T.Three
tableColumns =
    columnsEmpty
        |> Common.column "First name" (columnWidthPixels 300)
        |> Common.column "Last name" (columnWidthPixels 300)
        |> Common.column "" (columnWidthPixels 100)


toTableRow :
    (Defendant -> Button msg)
    ->
        { toKey : Defendant -> String
        , view : Defendant -> Row msg T.Three
        }
toTableRow toEditButton =
    { toKey = .name, view = toTableRowView toEditButton }


toTableRowView : (Defendant -> Button msg) -> Defendant -> Row msg T.Three
toTableRowView toEditButton ({ firstName, lastName } as defendant) =
    rowEmpty
        |> rowCellText (Text.body2 firstName)
        |> rowCellText (Text.body2 lastName)
        |> rowCellButton (toEditButton defendant)


toTableDetails toEditButton ({ firstName, lastName } as defendant) =
    detailsEmpty
        |> detailShown
            { label = "First name"
            , content =
                firstName
                    |> Text.body2
                    |> Text.withOverflow Text.ellipsize
                    |> cellFromText
            }
        |> detailShown
            { label = "Last name"
            , content = cellFromText <| Text.body2 lastName
            }
        |> detailShown
            { label = "Edit"
            , content = cellFromButton (toEditButton defendant)
            }


toTableCover { name } =
    { title = name, caption = Nothing }
