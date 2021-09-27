module Page.Admin.Dashboard exposing (Data, Model, Msg, page)

import Browser.Navigation as Nav
import Campaign exposing (Campaign)
import Color
import DataSource exposing (DataSource)
import DetainerWarrant exposing (DetainerWarrant)
import Element exposing (Element, centerX, column, fill, height, image, link, maximum, minimum, padding, paragraph, px, row, spacing, text, textColumn, width)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Input as Input
import Head
import Head.Seo as Seo
import Html.Events
import Http
import Json.Decode as Decode
import Logo
import Page exposing (Page, PageWithState, StaticPayload)
import Pages.PageUrl exposing (PageUrl)
import Pages.Url
import Palette
import Path exposing (Path)
import Rest exposing (Cred)
import Rest.Endpoint as Endpoint
import Runtime
import Session exposing (Session)
import Settings exposing (Settings)
import Shared
import User exposing (User)
import View exposing (View)


type alias Model =
    { campaigns : List Campaign
    }


init :
    Maybe PageUrl
    -> Shared.Model
    -> StaticPayload Data RouteParams
    -> ( Model, Cmd Msg )
init pageUrl sharedModel static =
    ( { campaigns = []
      }
    , getCampaigns (Runtime.domain static.sharedData.runtime.environment) (Session.cred sharedModel.session)
    )


getCampaigns : String -> Maybe Cred -> Cmd Msg
getCampaigns domain maybeCred =
    Rest.get (Endpoint.campaigns domain) maybeCred GotCampaigns Rest.campaignApiDecoder


type Msg
    = GotCampaigns (Result Http.Error (Rest.Collection Campaign))


update :
    PageUrl
    -> Maybe Nav.Key
    -> Shared.Model
    -> StaticPayload Data RouteParams
    -> Msg
    -> Model
    -> ( Model, Cmd Msg )
update pageUrl navKey sharedModel payload msg model =
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
            { url = "/admin/campaigns/" ++ String.fromInt campaign.id, label = text "View Campaign" }
        ]


title =
    "RDC | Admin | Dashboard"


view :
    Maybe PageUrl
    -> Shared.Model
    -> Model
    -> StaticPayload Data RouteParams
    -> View Msg
view maybeUrl sharedModel model static =
    { title = title
    , body =
        [ row
            [ centerX
            , padding 10
            , Font.size 20
            , width (fill |> maximum 1000 |> minimum 375)
            ]
            [ column [ centerX, spacing 10 ]
                ([ row [ centerX ]
                    [ paragraph [] [ text "Current campaigns" ]
                    ]
                 ]
                    ++ List.map viewCampaign model.campaigns
                )
            ]
        ]
    }


subscriptions : Maybe PageUrl -> RouteParams -> Path -> Model -> Sub Msg
subscriptions pageUrl params path model =
    Sub.none


type alias RouteParams =
    {}


page : Page.PageWithState RouteParams Data Model Msg
page =
    Page.single
        { head = head
        , data = data
        }
        |> Page.buildWithLocalState
            { init = init
            , update = update
            , view = view
            , subscriptions = subscriptions
            }


type alias Data =
    ()


data : DataSource Data
data =
    DataSource.succeed ()


head :
    StaticPayload Data RouteParams
    -> List Head.Tag
head static =
    Seo.summary
        { canonicalUrlOverride = Nothing
        , siteName = "Red Door Collective"
        , image = Logo.smallImage
        , description = "RDC at a single view"
        , locale = Nothing
        , title = title
        }
        |> Seo.website
