module Page.Admin.Dashboard exposing (Data, Model, Msg, page)

import Browser.Navigation as Nav
import Campaign exposing (Campaign)
import DataSource exposing (DataSource)
import Element exposing (Element, centerX, column, fill, height, maximum, minimum, padding, paragraph, px, row, spacing, text, width)
import Element.Font as Font
import Head
import Head.Seo as Seo
import Http
import Logo
import Page exposing (StaticPayload)
import Pages.PageUrl exposing (PageUrl)
import Path exposing (Path)
import Rest exposing (Cred)
import Rest.Endpoint as Endpoint
import Runtime
import Session
import Shared
import Sprite
import UI.Button as Button
import UI.Link as Link
import UI.RenderConfig exposing (RenderConfig)
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

                Err _ ->
                    ( model, Cmd.none )


viewCampaign : RenderConfig -> Campaign -> Element Msg
viewCampaign cfg campaign =
    row [ width fill, spacing 10 ]
        [ Element.el [ width (px 0), height (px 0) ] (Element.html Sprite.all)
        , paragraph [] [ text campaign.name ]
        , paragraph [ Font.semiBold ] [ text ((String.fromInt <| List.length campaign.events) ++ " events") ]
        , Button.fromLabel "View campaign"
            |> Button.redirect (Link.link <| "/admin/campaigns/" ++ String.fromInt campaign.id) Button.primary
            |> Button.renderElement cfg
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
    let
        cfg =
            sharedModel.renderConfig
    in
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
                    ++ List.map (viewCampaign cfg) model.campaigns
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
