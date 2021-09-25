module Page.Blog exposing (Data, Model, Msg, page)

import Article
import DataSource
import Date
import Element exposing (Color, Element, alignBottom, alignLeft, alignRight, centerX, column, fill, height, image, maximum, minimum, padding, paddingXY, paragraph, px, rgb255, row, spacing, spacingXY, text, textColumn, width, wrappedRow)
import Element.Background as Background
import Element.Border as Border
import Element.Events
import Element.Font as Font
import Head
import Head.Seo as Seo
import Html
import Html.Attributes as Attr
import List.Extra
import Logo
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



-- cardRow =
--     row
--         [ centerX
--         , width fill
--         , spacing 60
--         , width fill
--         , height fill
--         ]


blogColumn model articles =
    column
        [ width (fill |> maximum 375)
        ]
        (List.indexedMap (blogTile model) (List.reverse articles))


blogTile : Model -> Int -> ( Route, Article.ArticleMetadata ) -> Element Msg
blogTile model index ( route, info ) =
    let
        absPath =
            route |> Route.toPath |> Path.toAbsolute |> Pages.Url.toAbsoluteUrl
    in
    column
        ([ centerX
         , width (fill |> maximum 375)
         , paddingXY 10 0
         ]
            ++ (if model.hoveringOn == Just info.title then
                    [ Element.htmlAttribute (Attr.style "filter" "brightness(1.25)") ]

                else
                    []
               )
            ++ (if modBy 3 (index + 2) == 0 then
                    [ Border.widthXY 1 0
                    , Border.color (rgb255 235 235 235)
                    ]

                else
                    []
               )
        )
        [ row
            [ width fill
            ]
            [ link route
                [ width fill ]
                { url = route |> Route.toPath |> Path.toAbsolute
                , label =
                    image
                        [ width (fill |> maximum 180)
                        , Element.Events.onMouseEnter (MouseEnteredPost info.title)
                        , Element.Events.onMouseLeave MouseLeftPost
                        ]
                        { src = absPath info.image
                        , description = "Article thumbnail"
                        }
                }
            ]
        , row
            [ width fill
            , padding 10
            ]
            [ textColumn [ width fill, spacing 10 ]
                [ paragraph
                    [ Font.size 22
                    , Font.bold
                    ]
                    [ link route [] { url = route |> Route.toPath |> Path.toAbsolute, label = text info.title } ]
                , paragraph
                    [ Font.size 17 ]
                    [ text info.description ]
                , paragraph
                    [ Font.size 14
                    ]
                    [ text (info.author ++ " - " ++ (info.published |> Date.format "MMMM ddd, yyyy")) ]
                ]
            ]
        ]


blogGrid model articles =
    wrappedRow
        [ centerX
        , width (fill |> minimum 950 |> maximum 1260)
        , spacingXY 0 60
        ]
        (List.indexedMap (blogCard model) (List.reverse articles))


red =
    rgb255 236 31 39


sortByPublished articles =
    List.sortWith (\( _, a ) ( _, b ) -> Date.compare a.published b.published) articles


title =
    "Red Door Collective | Blog"


view :
    Maybe PageUrl
    -> Shared.Model
    -> Model
    -> StaticPayload Data RouteParams
    -> View Msg
view maybeUrl sharedModel model staticPayload =
    { title = title
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
                [ textColumn [ spacing 20, width fill ]
                    [ paragraph
                        [ Font.size 30
                        , Font.bold
                        , Font.center
                        ]
                        [ text "Red Door Collective" ]
                    , paragraph
                        [ Font.center
                        , Font.size 20
                        , Element.htmlAttribute (Attr.class "responsive-desktop")
                        ]
                        [ text blogDescription
                        ]
                    , paragraph
                        [ Font.center
                        , Font.size 20
                        , Element.htmlAttribute (Attr.class "responsive-mobile")
                        , width (fill |> maximum 375)
                        ]
                        [ text blogDescription
                        ]
                    ]
                ]
            , row
                [ Element.htmlAttribute (Attr.class "responsive-desktop")
                , width fill
                , centerX
                ]
                [ blogGrid model (sortByPublished staticPayload.data) ]
            , row
                [ Element.htmlAttribute (Attr.class "responsive-mobile")
                , width fill
                , centerX
                ]
                [ blogColumn model (sortByPublished staticPayload.data) ]
            ]
        ]
    }


head : StaticPayload Data {} -> List Head.Tag
head staticPayload =
    Seo.summary
        { canonicalUrlOverride = Nothing
        , siteName = "Red Door Collective"
        , image = Logo.smallImage
        , description = blogDescription
        , locale = Just "en-us"
        , title = title
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


blogCard : Model -> Int -> ( Route, Article.ArticleMetadata ) -> Element Msg
blogCard model index ( route, info ) =
    let
        absPath =
            route |> Route.toPath |> Path.toAbsolute |> Pages.Url.toAbsoluteUrl
    in
    column
        ([ centerX
         , width (fill |> minimum 300 |> maximum 420)
         , height (fill |> minimum 255 |> maximum 600)
         , paddingXY 10 0
         ]
            ++ (if model.hoveringOn == Just info.title then
                    [ Element.htmlAttribute (Attr.style "filter" "brightness(1.25)") ]

                else
                    []
               )
            ++ (if modBy 3 (index + 2) == 0 then
                    [ Border.widthXY 1 0
                    , Border.color (rgb255 235 235 235)
                    ]

                else
                    []
               )
        )
        [ row
            [ width fill
            ]
            [ link route
                [ width fill ]
                { url = route |> Route.toPath |> Path.toAbsolute
                , label =
                    image
                        [ width fill
                        , Element.Events.onMouseEnter (MouseEnteredPost info.title)
                        , Element.Events.onMouseLeave MouseLeftPost
                        ]
                        { src = absPath info.image
                        , description = "Article thumbnail"
                        }
                }
            ]
        , row
            [ width fill
            , padding 10
            ]
            [ textColumn [ width fill, spacing 20 ]
                [ paragraph
                    [ Font.size 22
                    , Font.bold
                    ]
                    [ link route [] { url = route |> Route.toPath |> Path.toAbsolute, label = text info.title } ]
                , paragraph
                    [ Font.size 17 ]
                    [ text info.description ]
                , paragraph
                    [ Font.size 14
                    ]
                    [ text (info.author ++ " - " ++ (info.published |> Date.format "MMMM ddd, yyyy")) ]
                ]
            ]
        ]


blogDescription : String
blogDescription =
    "Stories from the tenant organizing front."
