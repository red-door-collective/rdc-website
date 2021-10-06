module Search exposing (Cursor(..), DetainerWarrants, Plaintiffs, Search, detainerWarrantsArgs, detainerWarrantsDefault, detainerWarrantsQuery, dwFromString, plaintiffsArgs, plaintiffsDefault, plaintiffsFromString, plaintiffsQuery, toPair)

import Date exposing (Date)
import Dict
import Iso8601
import QueryParams
import Rest.Endpoint exposing (toQueryArgs)
import Time exposing (Posix)
import Url.Builder


type Cursor
    = NewSearch
    | After String
    | End


type alias DetainerWarrants =
    { docketId : Maybe String
    , fileDate : Maybe Posix
    , courtDate : Maybe Posix
    , plaintiff : Maybe String
    , plaintiffAttorney : Maybe String
    , defendant : Maybe String
    , address : Maybe String
    , freeText : Maybe String
    }


type alias Plaintiffs =
    { name : Maybe String
    , aliases : Maybe String
    }


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
    , freeText = Nothing
    }


plaintiffsFromString : String -> Plaintiffs
plaintiffsFromString str =
    let
        params =
            QueryParams.fromString str
                |> QueryParams.toDict
    in
    { name = Dict.get "name" params |> Maybe.andThen List.head
    , aliases = Dict.get "aliases" params |> Maybe.andThen List.head
    }


dwFromString : String -> DetainerWarrants
dwFromString str =
    let
        params =
            QueryParams.fromString str
                |> QueryParams.toDict
    in
    { docketId = Dict.get "docket_id" params |> Maybe.andThen List.head
    , fileDate = Dict.get "file_date" params |> Maybe.andThen List.head |> Maybe.map Iso8601.toTime |> Maybe.andThen Result.toMaybe
    , courtDate = Dict.get "court_date" params |> Maybe.andThen List.head |> Maybe.map Iso8601.toTime |> Maybe.andThen Result.toMaybe
    , plaintiff = Dict.get "plaintiff" params |> Maybe.andThen List.head
    , plaintiffAttorney = Dict.get "plaintiff_attorney" params |> Maybe.andThen List.head
    , defendant = Dict.get "defendant_name" params |> Maybe.andThen List.head
    , address = Dict.get "address" params |> Maybe.andThen List.head
    , freeText = Dict.get "free_text" params |> Maybe.andThen List.head
    }


plaintiffsDefault : Plaintiffs
plaintiffsDefault =
    { name = Nothing
    , aliases = Nothing
    }


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


posixToString posix =
    let
        millis =
            Time.posixToMillis posix
    in
    String.fromInt (round (toFloat millis / 1000))


detainerWarrantsArgs : DetainerWarrants -> List ( String, String )
detainerWarrantsArgs filters =
    toPair "docket_id" filters.docketId
        ++ toPair "file_date" (Maybe.map posixToString filters.fileDate)
        ++ toPair "court_date" (Maybe.map posixToString filters.courtDate)
        ++ toPair "plaintiff" filters.plaintiff
        ++ toPair "plaintiff_attorney" filters.plaintiffAttorney
        ++ toPair "defendant_name" filters.defendant
        ++ toPair "address" filters.address
        ++ toPair "free_text" filters.freeText


detainerWarrantsQuery : DetainerWarrants -> String
detainerWarrantsQuery filters =
    Url.Builder.toQuery (toQueryArgs (detainerWarrantsArgs filters))


plaintiffsArgs : Plaintiffs -> List ( String, String )
plaintiffsArgs filters =
    toPair "name" filters.name
        ++ toPair "aliases" filters.aliases


plaintiffsQuery : Plaintiffs -> String
plaintiffsQuery filters =
    Url.Builder.toQuery (toQueryArgs (plaintiffsArgs filters))
