module Page.Organize.Dashboard exposing (Model, Msg, init, subscriptions, toSession, update, view)

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
    , campaigns : List Campaign
    }


init : Session -> ( Model, Cmd Msg )
init session =
    let
        maybeCred =
            Session.cred session
    in
    ( { session = session
      , campaigns = []
      }
    , getCampaigns maybeCred
    )


getCampaigns : Maybe Cred -> Cmd Msg
getCampaigns maybeCred =
    Api.get Endpoint.campaigns maybeCred GotCampaigns Api.campaignApiDecoder


type Msg
    = GotCampaigns (Result Http.Error (Api.Collection Campaign))


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GotCampaigns result ->
            case result of
                Ok campaignsPage ->
                    ( { model | campaigns = campaignsPage.data }, Cmd.none )

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


viewCampaign : Campaign -> Element Msg
viewCampaign campaign =
    row [ width fill, spacing 10 ]
        [ paragraph [] [ text campaign.name ]
        , paragraph [ Font.semiBold ] [ text ((String.fromInt <| List.length campaign.events) ++ " events") ]
        , link
            [ Background.color Palette.sred
            , Font.color Palette.white
            , Border.rounded 3
            , padding 10
            ]
            { url = Route.href (Route.CampaignOverview campaign.id), label = text "View Campaign" }
        ]


view : Settings -> Model -> { title : String, content : Element Msg }
view settings model =
    { title = "Admin - Dashboard"
    , content =
        row [ centerX, padding 10, Font.size 20, width (fill |> maximum 1000 |> minimum 400) ]
            [ column [ centerX, spacing 10 ]
                ([ row [ centerX ]
                    [ paragraph [] [ text "Current campaigns" ]
                    ]
                 ]
                    ++ List.map viewCampaign model.campaigns
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
