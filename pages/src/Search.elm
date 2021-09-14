module Search exposing (Cursor(..), DetainerWarrants, Plaintiffs, Search, detainerWarrantsArgs, detainerWarrantsDefault, detainerWarrantsQuery, dwFromString, plaintiffsArgs, plaintiffsDefault, plaintiffsQuery, toPair, plaintiffsFromString)

import Api.Endpoint exposing (toQueryArgs)
import Date exposing (Date)
import Dict
import QueryParams
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

plaintiffsFromString: String -> Plaintiffs
plaintiffsFromString str =
    let
        params =
            QueryParams.fromString str
                |> QueryParams.toDict
    in
    { name = Dict.get "name" params |> Maybe.andThen List.head
    }

dwFromString : String -> DetainerWarrants
dwFromString str =
    let
        params =
            QueryParams.fromString str
                |> QueryParams.toDict
    in
    { docketId = Dict.get "docket_id" params |> Maybe.andThen List.head
    , fileDate = Dict.get "file_date" params |> Maybe.andThen List.head |> Maybe.map Date.fromIsoString |> Maybe.andThen Result.toMaybe
    , courtDate = Dict.get "court_date" params |> Maybe.andThen List.head |> Maybe.map Date.fromIsoString |> Maybe.andThen Result.toMaybe
    , plaintiff = Dict.get "plaintiff" params |> Maybe.andThen List.head
    , plaintiffAttorney = Dict.get "plaintiff_attorney" params |> Maybe.andThen List.head
    , defendant = Dict.get "defendant_name" params |> Maybe.andThen List.head
    , address = Dict.get "address" params |> Maybe.andThen List.head
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
