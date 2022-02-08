module Page.Blog.Slug_ exposing (Data, Model, Msg, page)

import Article
import Cloudinary
import Colors
import Data.Author as Author
import DataSource exposing (DataSource)
import Date exposing (Date)
import Element exposing (Element, alignLeft, alignRight, alignTop, centerX, column, fill, fillPortion, height, maximum, minimum, padding, paddingXY, paragraph, px, rgb255, row, spacing, text, textColumn, width, wrappedRow)
import Element.Font as Font
import Head
import Head.Seo as Seo
import Html
import Html.Attributes as Attrs exposing (id)
import Markdown.Html
import MarkdownCodec
import MarkdownRenderer
import OptimizedDecoder
import Page exposing (Page, StaticPayload)
import Pages.PageUrl exposing (PageUrl)
import Pages.Url
import Path
import Shared
import Site
import StructuredData
import UI.RenderConfig as RenderConfig exposing (RenderConfig)
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


authorFromString str =
    case str of
        "Greg Ziegan" ->
            Author.greg

        "Jack Marr" ->
            Author.jack

        "Kathryn Brown" ->
            Author.kathryn

        _ ->
            Author.redDoor


viewDesktop cfg static =
    let
        authors =
            List.map authorFromString static.data.metadata.authors
    in
    column
        [ width (fill |> minimum 300 |> maximum 750)
        , centerX
        , spacing 10
        , paddingXY 0 10
        ]
        [ row
            [ width fill
            , padding 10
            , spacing 20
            ]
            (List.map
                (\author ->
                    column [ centerX ] [ authorView (List.length authors == 1) author static.data ]
                )
                authors
            )
        , if List.length authors > 1 then
            row [ width fill, Font.center ] [ viewDate static.data.metadata.published ]

          else
            Element.none
        , row
            [ width fill ]
            [ textColumn [ width fill ] static.data.body
            ]
        ]


viewMobile cfg static =
    let
        authors =
            List.map authorFromString static.data.metadata.authors
    in
    column
        [ width (fill |> minimum 300 |> maximum 750)
        , centerX
        , spacing 10
        , paddingXY 0 10
        ]
        [ column
            [ width fill
            , padding 10
            , spacing 20
            ]
            (List.map
                (\author ->
                    row [ centerX ] [ authorView (List.length authors == 1) author static.data ]
                )
                authors
            )
        , if List.length authors > 1 then
            row [ width fill, Font.center ] [ viewDate static.data.metadata.published ]

          else
            Element.none
        , row
            [ width fill ]
            [ textColumn [ width fill ] static.data.body
            ]
        ]


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
    { title = static.data.metadata.title
    , body =
        [ Element.el [ width fill, Element.htmlAttribute (Attrs.class "responsive-mobile") ]
            (if RenderConfig.isPortrait cfg then
                viewMobile cfg static

             else
                viewDesktop (RenderConfig.init { width = 800, height = 375 } RenderConfig.localeEnglish) static
            )
        , Element.el [ width fill, Element.htmlAttribute (Attrs.class "responsive-desktop") ]
            (viewDesktop cfg static)
        ]
    }


viewDate date =
    paragraph [ Font.color (rgb255 75 75 75) ] [ text (date |> Date.format "MMMM ddd, yyyy") ]


authorView withDate author static =
    row [ width fill, spacing 10 ]
        [ Html.img
            [ Attrs.src (author.avatar |> Pages.Url.toString)
            , Attrs.style "border-radius" "50%"
            , Attrs.style "max-width" "75px"
            ]
            []
            |> Element.html
            |> Element.el []
        , textColumn [ width fill, spacing 10 ]
            [ paragraph [ Font.bold ] [ text author.name ]
            , if withDate then
                viewDate static.metadata.published

              else
                Element.none
            ]
        ]


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
                    { codeRepositoryUrl = "https://github.com/red-door-collective/eviction-tracker"
                    , description = "A free website that keeps the people informed about housing and evictions."
                    , author = "Greg Ziegan"
                    , programmingLanguage = StructuredData.elmLang
                    }
            }
        )
        :: (Seo.summaryLarge
                { canonicalUrlOverride = Nothing
                , siteName = "Red Door Collective"
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


elmUiRenderer colors =
    MarkdownRenderer.renderer colors


viewAlignLeft : List (Element msg) -> Element msg
viewAlignLeft renderedChildren =
    row [ alignLeft, width (fill |> maximum 375), height fill ]
        renderedChildren


viewAlignRight : List (Element msg) -> Element msg
viewAlignRight renderedChildren =
    row [ alignRight, width (fill |> maximum 375), height fill ]
        renderedChildren


viewTextColumn : List (Element msg) -> Element msg
viewTextColumn renderedChildren =
    textColumn
        [ width fill
        , Element.spacingXY 10 10

        -- , Element.explain Debug.todo
        ]
        renderedChildren


viewRow : List (Element msg) -> Element msg
viewRow renderedChildren =
    wrappedRow
        [ width fill
        , Element.spacingXY 0 10
        , alignTop
        ]
        renderedChildren


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


blogRenderer params =
    let
        defaultColors =
            Colors.default

        colors =
            if "high-cost-of-capitalism" == params.slug then
                Just
                    { defaultColors
                        | mediumHeaderBackground = rgb255 255 235 0
                        , mediumHeaderFont = rgb255 0 0 0
                        , smallHeaderFont = rgb255 0 0 0
                    }

            else
                Nothing

        customRenderer =
            elmUiRenderer colors
    in
    { customRenderer
        | html =
            Markdown.Html.oneOf
                [ Markdown.Html.tag "legend"
                    (\title _ ->
                        viewLegend title
                    )
                    |> Markdown.Html.withAttribute "title"
                , Markdown.Html.tag "sized-image"
                    (\title widthInPx heightInPx src alt _ ->
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
                , Markdown.Html.tag "align-left"
                    (\renderedChildren ->
                        viewAlignLeft renderedChildren
                    )
                , Markdown.Html.tag "align-right"
                    (\renderedChildren ->
                        viewAlignRight renderedChildren
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
        (blogRenderer route)
        ("content/blog/" ++ route.slug ++ ".md")


type alias ArticleMetadata =
    { title : String
    , description : String
    , authors : List String
    , published : Date
    , image : Pages.Url.Url
    , draft : Bool
    }


frontmatterDecoder : OptimizedDecoder.Decoder ArticleMetadata
frontmatterDecoder =
    OptimizedDecoder.map6 ArticleMetadata
        (OptimizedDecoder.field "title" OptimizedDecoder.string)
        (OptimizedDecoder.field "description" OptimizedDecoder.string)
        (OptimizedDecoder.field "authors" (OptimizedDecoder.list OptimizedDecoder.string))
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
