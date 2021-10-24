module Search exposing (Attorneys, Cursor(..), DetainerWarrants, Judges, Plaintiffs, Search, attorneysArgs, attorneysDefault, attorneysFromString, detainerWarrantsArgs, detainerWarrantsDefault, detainerWarrantsFilterArgs, dwFromString, judgesArgs, judgesDefault, judgesFromString, plaintiffsArgs, plaintiffsDefault, plaintiffsFromString)

import Dict
import Iso8601
import QueryParams
import Time exposing (Posix)
import Time.Utils


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


type alias Attorneys =
    Plaintiffs


type alias Judges =
    Plaintiffs


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


attorneysFromString : String -> Attorneys
attorneysFromString =
    plaintiffsFromString


judgesFromString : String -> Judges
judgesFromString =
    plaintiffsFromString


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


attorneysDefault : Attorneys
attorneysDefault =
    plaintiffsDefault


judgesDefault : Judges
judgesDefault =
    plaintiffsDefault


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


posixToString =
    String.fromInt << Time.posixToMillis


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


detainerWarrantsFilterArgs : DetainerWarrants -> List ( String, String )
detainerWarrantsFilterArgs filters =
    toPair "docket_id" filters.docketId
        ++ toPair "file_date" (Maybe.map Time.Utils.toIsoString filters.fileDate)
        ++ toPair "court_date" (Maybe.map Time.Utils.toIsoString filters.courtDate)
        ++ toPair "plaintiff" filters.plaintiff
        ++ toPair "plaintiff_attorney" filters.plaintiffAttorney
        ++ toPair "defendant_name" filters.defendant
        ++ toPair "address" filters.address
        ++ toPair "free_text" filters.freeText


plaintiffsArgs : Plaintiffs -> List ( String, String )
plaintiffsArgs filters =
    toPair "name" filters.name
        ++ toPair "aliases" filters.aliases


attorneysArgs : Attorneys -> List ( String, String )
attorneysArgs =
    plaintiffsArgs


judgesArgs : Judges -> List ( String, String )
judgesArgs =
    plaintiffsArgs
