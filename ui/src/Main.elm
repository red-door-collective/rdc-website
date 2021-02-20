module Main exposing (main)

import Browser
import Json.Decode as Decode exposing (Decoder, Value)
import Html

type Page = Welcome

type Msg = SearchWarrants

update : Msg -> Page -> ( Page, Cmd Msg )
update msg page =
    case page of
        Welcome ->
            ( Welcome, Cmd.none )

viewPage : Page -> Browser.Document Msg
viewPage page =
    case page of
        Welcome ->
            { title = "Welcome", body = [ Html.text "Find your Detainer Warrant case" ] }

subscriptions : Page -> Sub Msg
subscriptions page =
    case page of
        Welcome ->
            Sub.none

main : Program Value Page Msg
main =
    Browser.document
        { init =
            \_ -> (Welcome, Cmd.none)

        , view = viewPage
        , update = update
        , subscriptions = subscriptions
        }
