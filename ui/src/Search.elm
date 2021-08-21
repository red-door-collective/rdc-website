module Search exposing (Cursor(..), DetainerWarrants, Plaintiffs, Search, detainerWarrantsArgs, detainerWarrantsDefault, detainerWarrantsQuery, plaintiffsArgs, plaintiffsDefault, plaintiffsQuery, toPair)

import Api.Endpoint exposing (toQueryArgs)
import Date exposing (Date)
import Url.Builder


type Cursor
    = NewSearch
    | After String
    | End


type alias DetainerWarrants =
    { docketId : Maybe String
    , fileDate : Maybe Date
    , courtDate : Maybe Date
    , plaintiff : Maybe String
    , plaintiffAttorney : Maybe String
    , defendant : Maybe String
    , address : Maybe String
    }


type alias Plaintiffs =
    { name : Maybe String }


type alias Search filters =
    { filters : filters
    , cursor : Cursor
    , previous : Maybe filters
    , totalMatches : Maybe Int
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


plaintiffsDefault : Plaintiffs
plaintiffsDefault =
    { name = Nothing }


toPair : a -> Maybe String -> List ( a, String )
toPair key field =
    case field of
        Just value ->
            if value /= "" then
                [ ( key, value ) ]

            else
                []

        Nothing ->
            []


detainerWarrantsArgs : DetainerWarrants -> List ( String, String )
detainerWarrantsArgs filters =
    toPair "docket_id" filters.docketId
        ++ toPair "file_date" (Maybe.map Date.toIsoString filters.fileDate)
        ++ toPair "court_date" (Maybe.map Date.toIsoString filters.courtDate)
        ++ toPair "plaintiff" filters.plaintiff
        ++ toPair "plaintiff_attorney" filters.plaintiffAttorney
        ++ toPair "defendant_name" filters.defendant
        ++ toPair "address" filters.address


detainerWarrantsQuery : DetainerWarrants -> String
detainerWarrantsQuery filters =
    Url.Builder.toQuery (toQueryArgs (detainerWarrantsArgs filters))


plaintiffsArgs : Plaintiffs -> List ( String, String )
plaintiffsArgs filters =
    toPair "name" filters.name


plaintiffsQuery : Plaintiffs -> String
plaintiffsQuery filters =
    Url.Builder.toQuery (toQueryArgs (plaintiffsArgs filters))
