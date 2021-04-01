module Page.Organize.CampaignOverview exposing (Model, Msg, init, subscriptions, toSession, update, view)

import Api exposing (Cred)
import Api.Endpoint as Endpoint
import Campaign exposing (Campaign)
import Color
import DetainerWarrant exposing (DetainerWarrant)
import Element exposing (Element, centerX, column, fill, height, image, link, maximum, minimum, padding, paragraph, px, row, spacing, text, textColumn, width)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Input as Input
import Event exposing (Event(..), PhoneBankEvent)
import FeatherIcons
import Html.Events
import Http
import Json.Decode as Decode
import Palette
import Route
import Session exposing (Session)
import Settings exposing (Settings)
import User exposing (User)
import Widget
import Widget.Icon


type alias Model =
    { session : Session
    , campaign : Maybe Campaign
    }


init : Int -> Session -> ( Model, Cmd Msg )
init campaignId session =
    let
        maybeCred =
            Session.cred session
    in
    ( { session = session
      , campaign = Nothing
      }
    , getCampaign maybeCred campaignId
    )


getCampaign : Maybe Cred -> Int -> Cmd Msg
getCampaign maybeCred id =
    Api.get (Endpoint.campaign id) maybeCred GotCampaign (Api.itemDecoder Campaign.decoder)


type Msg
    = GotCampaign (Result Http.Error (Api.Item Campaign))


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GotCampaign result ->
            case result of
                Ok campaignPage ->
                    ( { model | campaign = Just <| campaignPage.data }, Cmd.none )

                Err errMsg ->
                    ( model, Cmd.none )


onEnter : msg -> Element.Attribute msg
onEnter msg =
    Element.htmlAttribute
        (Html.Events.on "keyup"
            (Decode.field "key" Decode.string
                |> Decode.andThen
                    (\key ->
                        if key == "Enter" then
                            Decode.succeed msg

                        else
                            Decode.fail "Not the enter key"
                    )
            )
        )


viewEvent : Campaign -> Campaign.ShallowEvent -> Element Msg
viewEvent campaign event =
    row [ width fill, spacing 10 ]
        [ text event.name
        , link
            [ Background.color Palette.sred
            , Font.color Palette.white
            , Border.rounded 3
            , padding 10
            ]
            { url = Route.href (Route.Event campaign.id event.id), label = text "Go to Event" }
        ]


view : Settings -> Model -> { title : String, content : Element Msg }
view settings model =
    { title = "Organize - Campaign - Overview"
    , content =
        row [ centerX, padding 10, Font.size 20, width (fill |> maximum 1000 |> minimum 400) ]
            [ column [ centerX, spacing 10 ]
                (case model.campaign of
                    Just campaign ->
                        [ row [ centerX ] [ paragraph [ Font.size 26 ] [ text campaign.name ] ]
                        ]
                            ++ List.map (viewEvent campaign) campaign.events

                    Nothing ->
                        []
                )
            ]
    }


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- EXPORT


toSession : Model -> Session
toSession model =
    model.session
