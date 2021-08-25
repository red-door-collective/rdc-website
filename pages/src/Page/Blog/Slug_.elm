module Page.Blog.Slug_ exposing (Data, Model, Msg, page)

import Article
import Cloudinary
import Data.Author as Author exposing (Author)
import DataSource exposing (DataSource)
import Date exposing (Date)
import Element exposing (Element, centerX, column, fill, paragraph, px, row, text, width)
import Head
import Head.Seo as Seo
import Html
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
            [ column [ width (px 642), centerX ]
                [ authorView author static.data
                , column [ width fill ] static.data.body
                ]
            ]
        ]
    }


authorView : Author -> Data -> Element msg
authorView author static =
    column []
        [ paragraph [] [ text author.name ] ]


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


data : RouteParams -> DataSource Data
data route =
    MarkdownCodec.withFrontmatter Data
        frontmatterDecoder
        MarkdownRenderer.renderer
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
