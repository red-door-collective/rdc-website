module Session exposing (Session, changes, cred, currentViewer, fromViewer, isLoggedIn, navKey, profile, updateProfile)

import Browser.Navigation as Nav
import Rest exposing (Cred)
import User exposing (User)
import Viewer exposing (Viewer)



-- TYPES


type Session
    = LoggedIn (Maybe Nav.Key) Viewer
    | Guest (Maybe Nav.Key)



-- INFO


cred : Session -> Maybe Cred
cred session =
    case session of
        LoggedIn _ val ->
            Just (Viewer.cred val)

        Guest _ ->
            Nothing


navKey : Session -> Maybe Nav.Key
navKey session =
    case session of
        LoggedIn key _ ->
            key

        Guest key ->
            key


isLoggedIn : Session -> Bool
isLoggedIn session =
    case session of
        LoggedIn _ _ ->
            True

        Guest _ ->
            False


profile : Session -> Maybe User
profile session =
    case session of
        LoggedIn _ viewer ->
            Just <| Viewer.profile viewer

        Guest _ ->
            Nothing


currentViewer : Session -> Maybe Viewer
currentViewer session =
    case session of
        LoggedIn _ viewer ->
            Just viewer

        Guest _ ->
            Nothing



-- CHANGES


updateProfile : User -> Session -> Session
updateProfile user session =
    case session of
        LoggedIn nav viewer ->
            LoggedIn nav (Viewer.updateProfile user viewer)

        Guest nav ->
            Guest nav


changes : (Session -> msg) -> Maybe Nav.Key -> Sub msg
changes toMsg key =
    Rest.viewerChanges (\maybeViewer -> toMsg (fromViewer key maybeViewer)) Viewer.decoder


fromViewer : Maybe Nav.Key -> Maybe Viewer -> Session
fromViewer key maybeViewer =
    -- It's stored in localStorage as a JSON String;
    -- first decode the Value as a String, then
    -- decode that String as JSON.
    case maybeViewer of
        Just viewerVal ->
            LoggedIn key viewerVal

        Nothing ->
            Guest key
