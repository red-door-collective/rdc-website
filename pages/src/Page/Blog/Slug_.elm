module Page.Blog.Slug_ exposing (Data, Model, Msg, page)

import Article
import Cloudinary
import Data.Author as Author exposing (Author)
import DataSource exposing (DataSource)
import Date exposing (Date)
import Element
import Head
import Head.Seo as Seo
import Html
import Html.Styled exposing (..)
import Html.Styled.Attributes as Attr exposing (css)
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
        [ Element.row [ Element.width Element.fill ]
            [ Element.column [ Element.width (Element.px 642), Element.centerX ]
                [ Element.html
                    (Html.Styled.toUnstyled
                        (div
                            [ css
                                [ Tw.min_h_screen
                                , Tw.w_full
                                , Tw.relative
                                ]
                            ]
                            [ div
                                [ css
                                    [ Tw.pt_16
                                    , Tw.pb_16
                                    , Tw.px_8
                                    , Tw.flex
                                    , Tw.flex_col
                                    ]
                                ]
                                [ div
                                    [ css
                                        [ Bp.md [ Tw.mx_auto ]
                                        ]
                                    ]
                                    [ h1
                                        [ css
                                            [ Tw.text_center
                                            , Tw.text_4xl
                                            , Tw.font_bold
                                            , Tw.tracking_tight
                                            , Tw.mt_2
                                            , Tw.mb_8
                                            ]
                                        ]
                                        [ text static.data.metadata.title
                                        ]
                                    , authorView author static.data
                                    , div
                                        [ css
                                            [ Tw.prose
                                            ]
                                        ]
                                        static.data.body
                                    ]
                                ]
                            ]
                        )
                    )
                ]
            ]
        ]
    }


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
                , Tw.h_10
                , Tw.w_10
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
                        [ Tw.text_sm
                        , Tw.font_medium
                        , Tw.text_gray_900
                        ]
                    ]
                    [ span
                        []
                        [ text author.name ]
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
                    [ text (static.metadata.published |> Date.format "MMMM ddd, yyyy") ]
                ]
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
    , body : List (Html Msg)
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
