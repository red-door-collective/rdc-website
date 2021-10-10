module Form.State exposing (DatePickerState)

import Date exposing (Date)
import DatePicker


type alias DatePickerState =
    { date : Maybe Date
    , dateText : String
    , pickerModel : DatePicker.Model
    }
