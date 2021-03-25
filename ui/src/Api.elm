port module Api exposing (ApiMeta, ApiPage, Cred, Flags, RollupMetadata, Window, addServerError, apiMetaDecoder, application, decodeErrors, delete, detainerWarrantApiDecoder, get, login, logout, onStoreChange, posix, post, put, rollupMetadataDecoder, storeCache, storeCredWith, viewerChanges)

{-| This module is responsible for communicating to the API.

It exposes an opaque Endpoint type which is guaranteed to point to the correct URL.

-}

import Api.Endpoint as Endpoint exposing (Endpoint)
import Browser
import Browser.Navigation as Nav
import DetainerWarrant exposing (DetainerWarrant)
import Html exposing (a)
import Http exposing (Body, Error, Expect)
import Json.Decode as Decode exposing (Decoder, Value, bool, decodeString, field, int, list, nullable, string)
import Json.Decode.Pipeline as Pipeline exposing (optional, required)
import Json.Encode as Encode
import Time
import Url exposing (Url)



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
    [ Http.header "authorization" ("Bearer " ++ str), Http.header "authentication-token" str ]


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


decode : Decoder (Cred -> viewer) -> Value -> Result Decode.Error viewer
decode decoder value =
    -- It's stored in localStorage as a JSON String;
    -- first decode the Value as a String, then
    -- decode that String as JSON.
    Decode.decodeValue Decode.string value
        |> Result.andThen (\str -> Decode.decodeString (Decode.field "user" (decoderFromCred decoder)) str)


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


storeCredWith : Cred -> Cmd msg
storeCredWith (Cred token) =
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


logout : Maybe Cred -> (Result Http.Error () -> msg) -> Cmd msg
logout cred toMsg =
    Cmd.batch [ throwaway Endpoint.logout cred toMsg, storeCache Nothing ]


port storeCache : Maybe Value -> Cmd msg



-- APPLICATION


type alias Window =
    { width : Int, height : Int }


type alias Flags viewer =
    { window : Window, viewer : Maybe viewer }


windowDecoder : Decoder Window
windowDecoder =
    Decode.succeed Window
        |> required "width" int
        |> required "height" int


application :
    Decoder (Cred -> viewer)
    ->
        { init : Flags viewer -> Url -> Nav.Key -> ( model, Cmd msg )
        , onUrlChange : Url -> msg
        , onUrlRequest : Browser.UrlRequest -> msg
        , subscriptions : model -> Sub msg
        , update : msg -> model -> ( model, Cmd msg )
        , view : model -> Browser.Document msg
        }
    -> Program Value model msg
application viewerDecoder config =
    let
        init flags url navKey =
            let
                window =
                    flags
                        |> Decode.decodeValue (Decode.field "window" windowDecoder)
                        |> Result.withDefault { width = 0, height = 0 }

                maybeViewer =
                    Decode.decodeValue (Decode.field "viewer" string) flags
                        |> Result.andThen (Decode.decodeString (storageDecoder viewerDecoder))
                        |> Result.toMaybe
            in
            config.init { window = window, viewer = maybeViewer } url navKey
    in
    Browser.application
        { init = init
        , onUrlChange = config.onUrlChange
        , onUrlRequest = config.onUrlRequest
        , subscriptions = config.subscriptions
        , update = config.update
        , view = config.view
        }


storageDecoder : Decoder (Cred -> viewer) -> Decoder viewer
storageDecoder viewerDecoder =
    Decode.field "user" (decoderFromCred viewerDecoder)


get : Endpoint -> Maybe Cred -> (Result Error a -> msg) -> Decoder a -> Cmd msg
get url maybeCred toMsg decoder =
    Endpoint.request
        { method = "GET"
        , url = url
        , expect = Http.expectJson toMsg decoder
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


throwaway : Endpoint -> Maybe Cred -> (Result Error () -> msg) -> Cmd msg
throwaway url maybeCred toMsg =
    Endpoint.request
        { method = "GET"
        , url = url
        , expect = Http.expectWhatever toMsg
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


put : Endpoint -> Body -> (Result Error a -> msg) -> Decoder a -> Cmd msg
put url body toMsg decoder =
    Endpoint.request
        { method = "PUT"
        , url = url
        , expect = Http.expectJson toMsg decoder
        , headers = []
        , body = body
        , timeout = Nothing
        , tracker = Nothing
        }


post : Endpoint -> Maybe Cred -> Body -> (Result Error a -> msg) -> Decoder a -> Cmd msg
post url maybeCred body toMsg decoder =
    Endpoint.request
        { method = "POST"
        , url = url
        , expect = Http.expectJson toMsg decoder
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


delete : Endpoint -> Body -> (Result Error a -> msg) -> Decoder a -> Cmd msg
delete url body toMsg decoder =
    Endpoint.request
        { method = "DELETE"
        , url = url
        , expect = Http.expectJson toMsg decoder
        , headers = []
        , body = body
        , timeout = Nothing
        , tracker = Nothing
        }


login : Http.Body -> (Result Error a -> msg) -> Decoder (Cred -> a) -> Cmd msg
login body toMsg decoder =
    post Endpoint.login Nothing body toMsg (Decode.field "response" (Decode.field "user" (decoderFromCred decoder)))


decoderFromCred : Decoder (Cred -> a) -> Decoder a
decoderFromCred decoder =
    Decode.map2 (\fromCred cred -> fromCred cred)
        decoder
        credDecoder



-- ERRORS


addServerError : List String -> List String
addServerError list =
    "Server error" :: list


{-| Many API endpoints include an "errors" field in their BadStatus responses.
-}
decodeErrors : Http.Error -> List String
decodeErrors error =
    case error of
        Http.BadStatus _ ->
            [ "Server error" ]

        err ->
            [ "Server error" ]


errorsDecoder : Decoder (List String)
errorsDecoder =
    Decode.keyValuePairs (Decode.list Decode.string)
        |> Decode.map (List.concatMap fromPair)


fromPair : ( String, List String ) -> List String
fromPair ( field, errors ) =
    List.map (\error -> field ++ " " ++ error) errors



-- LOCALSTORAGE KEYS


cacheStorageKey : String
cacheStorageKey =
    "cache"


credStorageKey : String
credStorageKey =
    "cred"


type alias ApiMeta =
    { afterCursor : Maybe String
    , hasNextPage : Bool
    }


type alias ApiPage data =
    { data : List data
    , meta : ApiMeta
    }


type alias RollupMetadata =
    { lastWarrantUpdatedAt : Time.Posix }


posix : Decoder Time.Posix
posix =
    Decode.map Time.millisToPosix int


rollupMetadataDecoder : Decoder RollupMetadata
rollupMetadataDecoder =
    Decode.succeed RollupMetadata
        |> required "last_detainer_warrant_update" posix


apiMetaDecoder : Decoder ApiMeta
apiMetaDecoder =
    Decode.succeed ApiMeta
        |> required "after_cursor" (nullable string)
        |> required "has_next_page" bool


detainerWarrantApiDecoder : Decoder (ApiPage DetainerWarrant)
detainerWarrantApiDecoder =
    Decode.succeed ApiPage
        |> required "data" (list DetainerWarrant.decoder)
        |> required "meta" apiMetaDecoder
