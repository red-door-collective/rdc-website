port module Rest exposing (Collection, Cred(..), Error, HttpError(..), Item, PageMeta, Window, collectionDecoder, detainerWarrantApiDecoder, errorToString, get, httpErrorToSpec, httpErrorToStrings, itemDecoder, login, logout, patch, post, storeCred, throwaway, viewerChanges)

{-| This module is responsible for communicating to the API.

It exposes an opaque Endpoint type which is guaranteed to point to the correct URL.

-}

import DetainerWarrant exposing (DetainerWarrant)
import Http exposing (Body, Expect, Metadata, Response(..), expectBytesResponse, expectStringResponse)
import Json.Decode as Decode exposing (Decoder, Value, bool, int, list, nullable, string)
import Json.Decode.Pipeline exposing (required)
import Json.Encode as Encode
import RemoteData exposing (RemoteData)
import Rest.Endpoint as Endpoint exposing (Endpoint)



-- CRED


{-| The authentication credentials for the Viewer (that is, the currently logged-in user.)

This includes:

  - The cred's authentication token

By design, there is no way to access the token directly as a String.
It can be encoded for persistence, and it can be added to a header
to a HttpBuilder for a request, but that's it.

This token should never be rendered to the end user, and with this API, it
can't be!

-}
type Cred
    = Cred String


credHeaders : Cred -> List Http.Header
credHeaders (Cred str) =
    [ Http.header "authorization" ("Bearer " ++ str)
    , Http.header "authentication-token" str
    ]


{-| It's important that this is never exposed!
We expose `login` and `application` instead, so we can be certain that if anyone
ever has access to a `Cred` value, it came from either the login API endpoint
or was passed in via flags.
-}
credDecoder : Decoder Cred
credDecoder =
    Decode.succeed Cred
        |> required "authentication_token" Decode.string



-- PERSISTENCE


port onStoreChange : (Value -> msg) -> Sub msg


viewerChanges : (Maybe viewer -> msg) -> Decoder (Cred -> viewer) -> Sub msg
viewerChanges toMsg decoder =
    onStoreChange (\value -> toMsg (decodeFromChange decoder value))


decodeFromChange : Decoder (Cred -> viewer) -> Value -> Maybe viewer
decodeFromChange viewerDecoder val =
    -- It's stored in localStorage as a JSON String;
    -- first decode the Value as a String, then
    -- decode that String as JSON.
    Decode.decodeValue (storageDecoder viewerDecoder) val
        |> Result.toMaybe


storageDecoder : Decoder (Cred -> viewer) -> Decoder viewer
storageDecoder viewerDecoder =
    Decode.field "user" (decoderFromCred viewerDecoder)


storeCred : Cred -> Cmd msg
storeCred (Cred token) =
    let
        json =
            Encode.object
                [ ( "user"
                  , Encode.object
                        [ ( "authentication_token", Encode.string token )
                        ]
                  )
                ]
    in
    storeCache (Just json)


logout : String -> Maybe Cred -> (Result HttpError () -> msg) -> Cmd msg
logout domain cred toMsg =
    Cmd.batch
        [ throwaway (Endpoint.logout domain) cred toMsg
        , storeCache Nothing
        ]


port storeCache : Maybe Value -> Cmd msg



-- APPLICATION


type alias Window =
    { width : Int, height : Int }


type alias Error =
    { code : Int
    , title : String
    , details : String
    }


errorToString err =
    err.title ++ " (code #" ++ String.fromInt err.code ++ ")" ++ "\n" ++ err.details


type HttpError
    = BadUrl String
    | Timeout
    | NetworkError
    | BadStatus Metadata (List Error)
    | BadBody Metadata (List Error)


errorDecoder : Decoder Error
errorDecoder =
    Decode.map3 Error
        (Decode.field "code" Decode.int)
        (Decode.field "title" Decode.string)
        (Decode.field "details" Decode.string)


decodePair : Int -> ( String, List String ) -> Error
decodePair code ( k, v ) =
    Error code k (String.join " " v)


loginErrorsDecoder : Decoder (List Error)
loginErrorsDecoder =
    Decode.at [ "meta", "code" ] Decode.int
        |> Decode.andThen loginErrorsDecoderHelp


loginErrorsDecoderHelp code =
    Decode.at [ "response", "errors" ]
        (Decode.keyValuePairs (Decode.list Decode.string))
        |> Decode.map (List.map (decodePair code))


errorsDecoder : Decoder (List Error)
errorsDecoder =
    Decode.oneOf
        [ Decode.field "errors" (Decode.list errorDecoder)
        , loginErrorsDecoder
        ]


defaultErrorDetails =
    List.singleton
        { code = 0
        , title = "Unknown Error"
        , details = "Something went wrong. The website admin has been alerted. Email reddoormidtn@gmail.com if you need timely assistance."
        }


resolve : (body -> Result (List Error) a) -> Response body -> Result HttpError a
resolve toResult response =
    case response of
        BadUrl_ url ->
            Err (BadUrl url)

        Timeout_ ->
            Err Timeout

        NetworkError_ ->
            Err NetworkError

        BadStatus_ metadata body ->
            Err (BadStatus metadata [])

        GoodStatus_ metadata body ->
            case toResult body of
                Ok data ->
                    Ok data

                Err err ->
                    Err (BadBody metadata err)


expectWhatever : (Result HttpError () -> msg) -> Expect msg
expectWhatever toMsg =
    expectBytesResponse toMsg (resolve (\_ -> Ok ()))


expectJson : (Result HttpError a -> msg) -> Decoder a -> Expect msg
expectJson toMsg decoder =
    expectStringResponse toMsg <|
        \response ->
            case response of
                Http.BadUrl_ url ->
                    Err (BadUrl url)

                Http.Timeout_ ->
                    Err Timeout

                Http.NetworkError_ ->
                    Err NetworkError

                Http.BadStatus_ metadata body ->
                    Err (BadStatus metadata (Result.withDefault defaultErrorDetails <| Decode.decodeString errorsDecoder body))

                Http.GoodStatus_ metadata body ->
                    case Decode.decodeString decoder body of
                        Ok value ->
                            Ok value

                        Err err ->
                            Err (BadBody metadata (Result.withDefault defaultErrorDetails <| Decode.decodeString errorsDecoder body))


get : Endpoint -> Maybe Cred -> (Result HttpError a -> msg) -> Decoder a -> Cmd msg
get url maybeCred toMsg decoder =
    Endpoint.request
        { method = "GET"
        , url = url
        , expect = expectJson toMsg decoder
        , headers =
            case maybeCred of
                Just cred ->
                    credHeaders cred

                Nothing ->
                    []
        , body = Http.emptyBody
        , timeout = Nothing
        , tracker = Nothing
        }


throwaway : Endpoint -> Maybe Cred -> (Result HttpError () -> msg) -> Cmd msg
throwaway url maybeCred toMsg =
    Endpoint.request
        { method = "POST"
        , url = url
        , expect = expectWhatever toMsg
        , headers =
            case maybeCred of
                Just cred ->
                    credHeaders cred

                Nothing ->
                    []
        , body = Http.emptyBody
        , timeout = Nothing
        , tracker = Nothing
        }


patch : Endpoint -> Maybe Cred -> Body -> (Result HttpError a -> msg) -> Decoder a -> Cmd msg
patch url maybeCred body toMsg decoder =
    Endpoint.request
        { method = "PATCH"
        , url = url
        , expect = expectJson toMsg decoder
        , headers =
            case maybeCred of
                Just cred ->
                    credHeaders cred

                Nothing ->
                    []
        , body = body
        , timeout = Nothing
        , tracker = Nothing
        }


post : Endpoint -> Maybe Cred -> Body -> (Result HttpError a -> msg) -> Decoder a -> Cmd msg
post url maybeCred body toMsg decoder =
    Endpoint.request
        { method = "POST"
        , url = url
        , expect = expectJson toMsg decoder
        , headers =
            case maybeCred of
                Just cred ->
                    credHeaders cred

                Nothing ->
                    []
        , body = body
        , timeout = Nothing
        , tracker = Nothing
        }


login : String -> Http.Body -> (Result HttpError a -> msg) -> Decoder (Cred -> a) -> Cmd msg
login domain body toMsg decoder =
    post (Endpoint.login domain) Nothing body toMsg (Decode.field "response" (Decode.field "user" (decoderFromCred decoder)))


decoderFromCred : Decoder (Cred -> a) -> Decoder a
decoderFromCred decoder =
    Decode.map2 (\fromCred cred -> fromCred cred)
        decoder
        credDecoder



-- LOCALSTORAGE KEYS


type alias PageMeta =
    { afterCursor : Maybe String
    , hasNextPage : Bool
    , totalMatches : Int
    }


type alias Collection data =
    { data : List data
    , meta : PageMeta
    }


type alias ItemMeta =
    { cursor : String }


type alias Item data =
    { data : data
    , meta : ItemMeta
    }


pageMetaDecoder : Decoder PageMeta
pageMetaDecoder =
    Decode.succeed PageMeta
        |> required "after_cursor" (nullable string)
        |> required "has_next_page" bool
        |> required "total_matches" int


detainerWarrantApiDecoder : Decoder (Collection DetainerWarrant)
detainerWarrantApiDecoder =
    Decode.succeed Collection
        |> required "data" (list DetainerWarrant.decoder)
        |> required "meta" pageMetaDecoder


collectionDecoder : Decoder a -> Decoder (Collection a)
collectionDecoder dataDecoder =
    Decode.succeed Collection
        |> required "data" (list dataDecoder)
        |> required "meta" pageMetaDecoder


itemMetaDecoder : Decoder ItemMeta
itemMetaDecoder =
    Decode.map ItemMeta (Decode.field "cursor" string)


itemDecoder : Decoder a -> Decoder (Item a)
itemDecoder dataDecoder =
    Decode.succeed Item
        |> required "data" dataDecoder
        |> required "meta" itemMetaDecoder


httpErrorToStrings : HttpError -> List String
httpErrorToStrings error =
    case error of
        BadUrl url ->
            [ url ]

        Timeout ->
            [ "Connection timed out." ]

        NetworkError ->
            [ "Network error." ]

        BadStatus metadata body ->
            List.map errorToString body

        BadBody _ body ->
            List.map errorToString body


httpErrorToSpec : HttpError -> List Error
httpErrorToSpec error =
    case error of
        BadUrl url ->
            [ { code = 458, title = "Bad URL", details = url } ]

        Timeout ->
            [ { code = 459, title = "Connection Timeout", details = "Connection timed out." } ]

        NetworkError ->
            [ { code = 460, title = "Network Error", details = "" } ]

        BadStatus metadata body ->
            body

        BadBody _ body ->
            body
