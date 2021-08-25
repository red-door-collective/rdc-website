module Page.Slug_ exposing (Data, Model, Msg, page)

import Article
import Cloudinary
import Data.Author as Author exposing (Author)
import DataSource exposing (DataSource)
import Date exposing (Date)
import Element exposing (Element, alignTop, centerX, centerY, column, el, fill, fillPortion, height, padding, paddingXY, paragraph, px, row, spacing, text, textColumn, width)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Head
import Head.Seo as Seo
import Html
import Html.Styled exposing (..)
import Html.Styled.Attributes as Attr exposing (css)
import Markdown.Html
import MarkdownCodec
import MarkdownRenderer
import OptimizedDecoder
import Page exposing (Page, StaticPayload)
import Pages.PageUrl exposing (PageUrl)
import Pages.Url exposing (Url)
import Path
import Shared
import Site
import StructuredData
import Tailwind.Breakpoints as Bp
import Tailwind.Utilities as Tw
import View exposing (View)


type alias Model =
    ()


type alias Msg =
    Never


type alias RouteParams =
    { slug : String }


page : Page RouteParams Data
page =
    Page.prerender
        { data = data
        , head = head
        , routes = routes
        }
        |> Page.buildNoState { view = view }


routes : DataSource.DataSource (List RouteParams)
routes =
    Article.blogPostsGlob
        |> DataSource.map
            (List.map
                (\globData ->
                    { slug = globData.slug }
                )
            )


view :
    Maybe PageUrl
    -> Shared.Model
    -> StaticPayload Data RouteParams
    -> View Msg
view maybeUrl sharedModel static =
    { title = static.data.metadata.title
    , body =
        let
            author =
                case static.data.metadata.author of
                    "Greg Ziegan" ->
                        Author.greg

                    "Jack Marr" ->
                        Author.jack

                    _ ->
                        Author.redDoor
        in
        [ row [ width fill ]
            [ column [ width (px 800), centerX, spacing 10, paddingXY 0 10 ]
                [ row [ width fill, padding 10, spacing 10 ]
                    [ column [ centerX ] [ Element.html <| Html.Styled.toUnstyled <| authorView author static.data ]
                    ]
                , row [ width fill ]
                    [ column [ width fill ] static.data.body
                    ]
                ]
            ]
        ]
    }


absPath url =
    Pages.Url.toString url


authorView : Author -> Data -> Html msg
authorView author static =
    div
        [ css
            [ Tw.flex
            , Tw.mb_16

            --, Tw.flex_shrink_0
            ]
        ]
        [ img
            [ Attr.src (author.avatar |> Pages.Url.toString)
            , css
                [ Tw.rounded_full
                , Tw.h_20
                , Tw.w_20
                ]
            ]
            []
        , div
            [ css [ Tw.ml_3 ]
            ]
            [ div
                [ css
                    []
                ]
                [ p
                    [ css
                        [ Tw.font_medium
                        , Tw.text_gray_900
                        ]
                    ]
                    [ span
                        []
                        [ Html.Styled.text author.name ]
                    ]
                ]
            , div
                [ css
                    [ Tw.flex
                    , Tw.space_x_1
                    , Tw.text_sm
                    , Tw.text_gray_500
                    , Tw.text_gray_400
                    ]
                ]
                [ time
                    [ Attr.datetime "2020-03-16"
                    ]
                    [ Html.Styled.text (static.metadata.published |> Date.format "MMMM ddd, yyyy") ]
                ]
            ]
        ]



-- avatarView : Url -> Element msg
-- avatarView src =
--     Element.el
--         [ width (px 200)
--         , height (px 200)
--         , Background.color (Element.rgb255 255 255 255)
--         , Border.rounded 100
--         , Border.width 1
--         , Element.behindContent
--             (Element.image
--                 [ width (px 200)
--                 , height (px 200)
--                 , Element.inFront
--                     (el
--                         [ Border.rounded 100
--                         , Border.width 10
--                         , width (px 200)
--                         , height (px 200)
--                         ]
--                         Element.none
--                     )
--                 ]
--                 { src = absPath src, description = "Headshot of the author, Jack Marr" }
--             )
--         ]
--         Element.none
-- authorView : Author -> Data -> Element msg
-- authorView author static =
--     column [ padding 10, spacing 10 ]
--         [ avatarView author.avatar
--         , paragraph [] [ text author.name ]
--         ]


head :
    StaticPayload Data RouteParams
    -> List Head.Tag
head static =
    let
        metadata =
            static.data.metadata
    in
    Head.structuredData
        (StructuredData.article
            { title = metadata.title
            , description = metadata.description
            , author = StructuredData.person { name = Author.jack.name }
            , publisher = StructuredData.person { name = Author.jack.name }
            , url = Site.config.canonicalUrl ++ Path.toAbsolute static.path
            , imageUrl = metadata.image
            , datePublished = Date.toIsoString metadata.published
            , mainEntityOfPage =
                StructuredData.softwareSourceCode
                    { codeRepositoryUrl = "https://github.com/thebritican/eviction-tracker"
                    , description = "A free website that keeps the people informed about housing and evictions."
                    , author = "Greg Ziegan"
                    , programmingLanguage = StructuredData.elmLang
                    }
            }
        )
        :: (Seo.summaryLarge
                { canonicalUrlOverride = Nothing
                , siteName = "elm-pages"
                , image =
                    { url = metadata.image
                    , alt = metadata.description
                    , dimensions = Nothing
                    , mimeType = Nothing
                    }
                , description = metadata.description
                , locale = Nothing
                , title = metadata.title
                }
                |> Seo.article
                    { tags = []
                    , section = Nothing
                    , publishedTime = Just (Date.toIsoString metadata.published)
                    , modifiedTime = Nothing
                    , expirationTime = Nothing
                    }
           )


type alias Data =
    { metadata : ArticleMetadata
    , body : List (Element Msg)
    }


elmUiRenderer =
    MarkdownRenderer.renderer


viewTextColumn : List (Element msg) -> Element msg
viewTextColumn renderedChildren =
    textColumn [ width fill, Element.spacing 10 ] renderedChildren


viewRow : List (Element msg) -> Element msg
viewRow renderedChildren =
    row [ width fill, Element.spacing 10, alignTop ] renderedChildren


viewColumn : String -> List (Element msg) -> Element msg
viewColumn portion renderedChildren =
    let
        fillAttr =
            width <|
                case String.toInt portion of
                    Nothing ->
                        fill

                    Just number ->
                        fillPortion number
    in
    column [ alignTop, fillAttr ] renderedChildren


viewSizedImage : Maybe String -> Maybe String -> Maybe String -> String -> String -> Element msg
viewSizedImage title widthInPx heightInPx src alt =
    let
        ( w, h ) =
            ( Maybe.andThen String.toInt widthInPx
            , Maybe.andThen String.toInt heightInPx
            )

        widthAttr =
            case w of
                Just number ->
                    width (px number)

                Nothing ->
                    width fill

        heightAttr =
            case h of
                Just number ->
                    height (px number)

                Nothing ->
                    height fill
    in
    case title of
        Just _ ->
            Element.image [ widthAttr, heightAttr ] { src = src, description = alt }

        Nothing ->
            Element.image [ alignTop, widthAttr, heightAttr ] { src = src, description = alt }


viewLegend : String -> Element msg
viewLegend title =
    column
        [ Element.padding 20
        , Element.spacing 30
        , Element.centerX
        ]
        [ Element.row [ Element.spacing 20 ]
            [ Element.el
                [ Font.bold
                , Font.size 30
                ]
                (Element.text title)
            ]
        ]


blogRenderer =
    { elmUiRenderer
        | html =
            Markdown.Html.oneOf
                [ Markdown.Html.tag "legend"
                    (\title renderedChildren ->
                        viewLegend title
                    )
                    |> Markdown.Html.withAttribute "title"
                , Markdown.Html.tag "sized-image"
                    (\title widthInPx heightInPx src alt renderedChildren ->
                        viewSizedImage title widthInPx heightInPx src alt
                    )
                    |> Markdown.Html.withOptionalAttribute "title"
                    |> Markdown.Html.withOptionalAttribute "width"
                    |> Markdown.Html.withOptionalAttribute "height"
                    |> Markdown.Html.withAttribute "src"
                    |> Markdown.Html.withAttribute "alt"
                , Markdown.Html.tag "column"
                    (\portion renderedChildren ->
                        viewColumn portion renderedChildren
                    )
                    |> Markdown.Html.withAttribute "portion"
                , Markdown.Html.tag "text-column"
                    (\renderedChildren ->
                        viewTextColumn renderedChildren
                    )
                , Markdown.Html.tag "row"
                    (\renderedChildren ->
                        viewRow renderedChildren
                    )
                ]
    }


data : RouteParams -> DataSource Data
data route =
    MarkdownCodec.withFrontmatter Data
        frontmatterDecoder
        blogRenderer
        ("content/blog/" ++ route.slug ++ ".md")


type alias ArticleMetadata =
    { title : String
    , description : String
    , author : String
    , published : Date
    , image : Pages.Url.Url
    , draft : Bool
    }


frontmatterDecoder : OptimizedDecoder.Decoder ArticleMetadata
frontmatterDecoder =
    OptimizedDecoder.map6 ArticleMetadata
        (OptimizedDecoder.field "title" OptimizedDecoder.string)
        (OptimizedDecoder.field "description" OptimizedDecoder.string)
        (OptimizedDecoder.field "author" OptimizedDecoder.string)
        (OptimizedDecoder.field "published"
            (OptimizedDecoder.string
                |> OptimizedDecoder.andThen
                    (\isoString ->
                        Date.fromIsoString isoString
                            |> OptimizedDecoder.fromResult
                    )
            )
        )
        (OptimizedDecoder.field "image" imageDecoder)
        (OptimizedDecoder.field "draft" OptimizedDecoder.bool
            |> OptimizedDecoder.maybe
            |> OptimizedDecoder.map (Maybe.withDefault False)
        )


imageDecoder : OptimizedDecoder.Decoder Pages.Url.Url
imageDecoder =
    OptimizedDecoder.string
        |> OptimizedDecoder.map (\asset -> Cloudinary.url asset Nothing 400 300)
