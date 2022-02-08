module Page.ConfirmError exposing (Data, Model, Msg, page)

import DataSource exposing (DataSource)
import Dict
import Element exposing (centerX, column, fill, height, padding, paragraph, px, row, spacing, text, textColumn, width)
import Element.Font
import Head
import Head.Seo as Seo
import Logo
import Page exposing (Page, StaticPayload)
import Pages.PageUrl exposing (PageUrl)
import QueryParams exposing (QueryParams)
import Shared
import Sprite
import UI.Button as Button
import UI.Icon as Icon
import UI.Link as Link
import UI.Size
import View exposing (View)


type alias Model =
    ()


type alias Msg =
    Never


type alias RouteParams =
    {}


page : Page RouteParams Data
page =
    Page.single
        { head = head
        , data = data
        }
        |> Page.buildNoState { view = view }


type alias Data =
    ()


data : DataSource Data
data =
    DataSource.succeed ()


title =
    "Red Door Collective | Confirmation Error"


head :
    StaticPayload Data RouteParams
    -> List Head.Tag
head static =
    Seo.summary
        { canonicalUrlOverride = Nothing
        , siteName = "Red Door Collective"
        , image = Logo.smallImage
        , description = "Organize Nashville tenants for dignified housing with us."
        , locale = Nothing
        , title = title
        }
        |> Seo.website


notFound =
    row [ centerX ] [ text "Page Not Found" ]


view :
    Maybe PageUrl
    -> Shared.Model
    -> StaticPayload Data RouteParams
    -> View Msg
view maybeUrl sharedModel static =
    let
        cfg =
            sharedModel.renderConfig
    in
    { title = title
    , body =
        [ Element.el [ width (px 0), height (px 0) ] (Element.html Sprite.all)
        , column [ width fill, padding 20 ]
            [ case sharedModel.queryParams of
                Just queryString ->
                    let
                        params =
                            QueryParams.toDict (QueryParams.fromString queryString)

                        maybeEmail =
                            Maybe.andThen List.head <| Dict.get "email" params

                        maybeInfoMsg =
                            Dict.get "info" params
                                |> Maybe.andThen List.head
                                |> Maybe.map (String.replace "+" " ")
                    in
                    case ( maybeEmail, maybeInfoMsg ) of
                        ( Just email, Just infoMsg ) ->
                            row [ centerX ]
                                [ textColumn [ width fill, spacing 10 ]
                                    [ paragraph [ Element.Font.size 34 ] [ text "Email confirmation failed." ]
                                    , paragraph [] [ text email ]
                                    , paragraph [] [ text infoMsg ]
                                    ]
                                ]

                        ( _, _ ) ->
                            notFound

                Nothing ->
                    notFound
            ]
        ]
    }
