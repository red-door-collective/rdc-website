port module Rest exposing (Collection, Cred(..), Item, PageMeta, Window, collectionDecoder, decodeErrors, detainerWarrantApiDecoder, get, itemDecoder, login, logout, patch, post, storeCred, throwaway, viewerChanges)

{-| This module is responsible for communicating to the API.

It exposes an opaque Endpoint type which is guaranteed to point to the correct URL.

-}

import DetainerWarrant exposing (DetainerWarrant)
import Http exposing (Body, Error)
import Json.Decode as Decode exposing (Decoder, Value, bool, int, list, nullable, string)
import Json.Decode.Pipeline exposing (required)
import Json.Encode as Encode
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


logout : String -> Maybe Cred -> (Result Http.Error () -> msg) -> Cmd msg
logout domain cred toMsg =
    Cmd.batch [ throwaway (Endpoint.logout domain) cred toMsg, storeCache Nothing ]


port storeCache : Maybe Value -> Cmd msg



-- APPLICATION


type alias Window =
    { width : Int, height : Int }


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
        { method = "POST"
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


patch : Endpoint -> Maybe Cred -> Body -> (Result Error a -> msg) -> Decoder a -> Cmd msg
patch url maybeCred body toMsg decoder =
    Endpoint.request
        { method = "PATCH"
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


login : String -> Http.Body -> (Result Error a -> msg) -> Decoder (Cred -> a) -> Cmd msg
login domain body toMsg decoder =
    post (Endpoint.login domain) Nothing body toMsg (Decode.field "response" (Decode.field "user" (decoderFromCred decoder)))


decoderFromCred : Decoder (Cred -> a) -> Decoder a
decoderFromCred decoder =
    Decode.map2 (\fromCred cred -> fromCred cred)
        decoder
        credDecoder



-- ERRORS


{-| Many API endpoints include an "errors" field in their BadStatus responses.
-}
decodeErrors : Http.Error -> List String
decodeErrors error =
    case error of
        Http.BadStatus _ ->
            [ "Server error" ]

        _ ->
            [ "Server error" ]



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
