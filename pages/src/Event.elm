module Event exposing (Event(..), PhoneBankEvent)

import Defendant exposing (Defendant)


type alias PhoneBankEvent =
    { id : Int
    , name : String
    , tenants : List Defendant
    }


type Event
    = PhoneBank PhoneBankEvent
