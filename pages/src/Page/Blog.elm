module Page.Blog exposing (Data, Model, Msg, page)

import Article
import DataSource
import Date
import Element exposing (Color, Element, alignBottom, alignLeft, alignRight, centerX, column, fill, height, image, maximum, padding, paddingXY, paragraph, px, rgb255, row, spacing, text, textColumn, width)
import Element.Background as Background
import Element.Border as Border
import Element.Events
import Element.Font as Font
import Head
import Head.Seo as Seo
import Html
import Html.Attributes as Attr
import List.Extra
import Page exposing (Page, PageWithState, StaticPayload)
import Pages.PageUrl exposing (PageUrl)
import Pages.Url
import Path
import Route exposing (Route)
import Shared
import View exposing (View)


type Msg
    = MouseEnteredPost String
    | MouseLeftPost


page : Page.PageWithState RouteParams Data Model Msg
page =
    Page.single
        { head = head
        , data = data
        }
        |> Page.buildWithLocalState
            { view = view
            , init = \_ _ staticPayload -> ( { hoveringOn = Nothing }, Cmd.none )
            , update = update
            , subscriptions =
                \maybePageUrl routeParams path model ->
                    Sub.none
            }


update : a -> b -> c -> d -> Msg -> Model -> ( Model, Cmd msg )
update _ maybeNavigationKey sharedModel static msg model =
    case msg of
        MouseEnteredPost title ->
            ( { model | hoveringOn = Just title }, Cmd.none )

        MouseLeftPost ->
            ( { model | hoveringOn = Nothing }, Cmd.none )


data : DataSource.DataSource Data
data =
    Article.allMetadata


type alias Data =
    List ( Route, Article.ArticleMetadata )


type alias RouteParams =
    {}


type alias Model =
    { hoveringOn : Maybe String }


cardRow =
    row
        [ centerX
        , width fill
        , spacing 60
        , width fill
        , height fill
        ]


blogGrid model articles =
    let
        rows =
            List.map (cardRow << List.map (blogCard model)) (List.Extra.greedyGroupsOf 2 <| List.reverse articles)
    in
    column
        [ centerX
        , width fill
        , spacing 50
        ]
        rows


red =
    rgb255 236 31 39


sortByPublished articles =
    List.sortWith (\( _, a ) ( _, b ) -> Date.compare a.published b.published) articles


view :
    Maybe PageUrl
    -> Shared.Model
    -> Model
    -> StaticPayload Data RouteParams
    -> View Msg
view maybeUrl sharedModel model staticPayload =
    { title = "Red Door Collective Blog"
    , body =
        [ column
            [ width fill
            , padding 40
            , spacing 60
            , Font.color (rgb255 50 50 50)
            , Font.family
                [ Font.typeface "styrene b"
                , Font.sansSerif
                ]
            ]
            [ row [ centerX ]
                [ textColumn [ spacing 20 ]
                    [ paragraph [ Font.size 30, Font.bold, Font.center ] [ text "Red Door Collective" ]
                    , paragraph [ Font.center, Font.size 20 ] [ text blogDescription ]
                    ]
                ]
            , row [ width fill, centerX ]
                [ blogGrid model (sortByPublished staticPayload.data) ]
            ]
        ]
    }


head : StaticPayload Data {} -> List Head.Tag
head staticPayload =
    Seo.summary
        { canonicalUrlOverride = Nothing
        , siteName = "reddoormidtn"
        , image =
            { url = [ "images", "red-door-logo.png" ] |> Path.join |> Pages.Url.fromPath
            , alt = "Red Door Collective logo"
            , dimensions = Just { width = 300, height = 300 }
            , mimeType = Just "png"
            }
        , description = blogDescription
        , locale = Just "en-us"
        , title = "Red Door Collective Blog"
        }
        |> Seo.website


link : Route.Route -> List (Element.Attribute msg) -> { url : String, label : Element msg } -> Element msg
link route attrs children =
    Route.toLink
        (\anchorAttrs ->
            Element.link
                (List.map Element.htmlAttribute anchorAttrs ++ attrs)
                children
        )
        route


blogCard : Model -> ( Route, Article.ArticleMetadata ) -> Element Msg
blogCard model ( route, info ) =
    let
        absPath =
            route |> Route.toPath |> Path.toAbsolute |> Pages.Url.toAbsoluteUrl
    in
    link route
        ([ centerX
         , width (px 465)
         , height (px 300)
         , Element.Events.onMouseEnter (MouseEnteredPost info.title)
         , Element.Events.onMouseLeave MouseLeftPost

         -- , padding 10
         ]
            ++ (if model.hoveringOn == Just info.title then
                    [ Element.htmlAttribute (Attr.style "filter" "brightness(1.25)") ]

                else
                    []
               )
        )
        { url = route |> Route.toPath |> Path.toAbsolute
        , label =
            column
                [ spacing 10
                , Font.center
                , width fill
                , height fill
                ]
                [ image
                    [ width fill
                    , Element.inFront
                        (column [ height fill ]
                            [ row
                                [ Font.size 14
                                , Font.color (Element.rgb255 255 255 255)
                                , alignRight
                                ]
                                [ paragraph [ padding 10, alignRight ]
                                    [ text (info.published |> Date.format "MMMM ddd, yyyy") ]
                                ]
                            , paragraph
                                [ Font.color (rgb255 255 255 255)
                                , Font.size 32
                                , Font.bold
                                , Font.alignLeft
                                , alignBottom
                                , paddingXY 20 20
                                ]
                                [ text info.title ]
                            ]
                        )
                    ]
                    { src = absPath info.image
                    , description = "Article thumbnail"
                    }
                ]
        }


blogDescription : String
blogDescription =
    "Unionizing Nashville tenants"
