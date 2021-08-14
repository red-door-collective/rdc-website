module Search exposing (Cursor(..), DetainerWarrants, Search, detainerWarrantsArgs, detainerWarrantsDefault, detainerWarrantsQuery)

import Api.Endpoint exposing (toQueryArgs)
import Url.Builder


type Cursor
    = NewSearch
    | After String
    | End


type alias DetainerWarrants =
    { docketId : Maybe String
    , fileDate : Maybe String
    , courtDate : Maybe String
    , plaintiff : Maybe String
    , plaintiffAttorney : Maybe String
    , defendant : Maybe String
    , address : Maybe String
    }


type alias Search filters =
    { filters : filters
    , cursor : Cursor
    , previous : Maybe filters
    }


detainerWarrantsDefault : DetainerWarrants
detainerWarrantsDefault =
    { docketId = Nothing
    , fileDate = Nothing
    , courtDate = Nothing
    , plaintiff = Nothing
    , plaintiffAttorney = Nothing
    , defendant = Nothing
    , address = Nothing
    }


detainerWarrantsArgs : DetainerWarrants -> List ( String, String )
detainerWarrantsArgs filters =
    let
        toPair key field =
            case field of
                Just value ->
                    if value /= "" then
                        [ ( key, value ) ]

                    else
                        []

                Nothing ->
                    []
    in
    toPair "docket_id" filters.docketId
        ++ toPair "file_date" filters.fileDate
        ++ toPair "court_date" filters.courtDate
        ++ toPair "plaintiff" filters.plaintiff
        ++ toPair "plaintiff_attorney" filters.plaintiffAttorney
        ++ toPair "defendant_name" filters.defendant
        ++ toPair "address" filters.address


detainerWarrantsQuery : DetainerWarrants -> String
detainerWarrantsQuery filters =
    Url.Builder.toQuery (toQueryArgs (detainerWarrantsArgs filters))
