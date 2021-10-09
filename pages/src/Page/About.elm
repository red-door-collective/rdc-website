module Page.About exposing (Data, Model, Msg, page)

import Cloudinary
import DataSource exposing (DataSource)
import Date exposing (Date)
import Element exposing (Element, alignLeft, alignRight, alignTop, centerX, column, fill, fillPortion, height, maximum, minimum, paddingXY, px, row, spacing, textColumn, width, wrappedRow)
import Element.Font as Font
import Head
import Head.Seo as Seo
import Logo
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


data : DataSource Data
data =
    MarkdownCodec.withFrontmatter Data
        frontmatterDecoder
        blogRenderer
        "content/about.md"


head :
    StaticPayload Data RouteParams
    -> List Head.Tag
head static =
    let
        metadata =
            static.data.metadata
    in
    Head.structuredData
        (StructuredData.aboutPage
            { title = metadata.title
            , description = metadata.description
            , author = StructuredData.person { name = "Red Door Collective" }
            , publisher = StructuredData.person { name = "Red Door Collective" }
            , url = Site.config.canonicalUrl ++ Path.toAbsolute static.path
            , imageUrl = metadata.image
            , lastReviewed = Date.toIsoString metadata.lastReviewed
            , mainEntityOfPage =
                StructuredData.softwareSourceCode
                    { codeRepositoryUrl = "https://github.com/red-door-collective/eviction-tracker"
                    , description = "A free website that keeps the people informed about housing and evictions."
                    , author = "Greg Ziegan"
                    , programmingLanguage = StructuredData.elmLang
                    }
            }
        )
        :: (Seo.summary
                { canonicalUrlOverride = Nothing
                , siteName = "Red Door Collective"
                , image = Logo.smallImage
                , description = metadata.description
                , locale = Just "en-us"
                , title = metadata.title
                }
                |> Seo.website
           )


type alias Data =
    { metadata : Metadata
    , body : List (Element Msg)
    }


view :
    Maybe PageUrl
    -> Shared.Model
    -> StaticPayload Data RouteParams
    -> View Msg
view maybeUrl sharedModel static =
    { title = static.data.metadata.title
    , body =
        [ column
            [ width (fill |> minimum 300 |> maximum 750)
            , centerX
            , spacing 10
            , paddingXY 0 10
            ]
            [ row
                [ width fill ]
                [ textColumn [ width fill ] static.data.body
                ]
            ]
        ]
    }


elmUiRenderer =
    MarkdownRenderer.renderer


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
            Element.image [ centerX, widthAttr, heightAttr ] { src = src, description = alt }

        Nothing ->
            row [ width fill ] [ Element.image [ centerX, widthAttr, heightAttr ] { src = src, description = alt } ]


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


type alias Metadata =
    { title : String
    , description : String
    , lastReviewed : Date
    , image : Pages.Url.Url
    }


frontmatterDecoder : OptimizedDecoder.Decoder Metadata
frontmatterDecoder =
    OptimizedDecoder.map4 Metadata
        (OptimizedDecoder.field "title" OptimizedDecoder.string)
        (OptimizedDecoder.field "description" OptimizedDecoder.string)
        (OptimizedDecoder.field "lastReviewed"
            (OptimizedDecoder.string
                |> OptimizedDecoder.andThen
                    (\isoString ->
                        Date.fromIsoString isoString
                            |> OptimizedDecoder.fromResult
                    )
            )
        )
        (OptimizedDecoder.field "image" imageDecoder)


imageDecoder : OptimizedDecoder.Decoder Pages.Url.Url
imageDecoder =
    OptimizedDecoder.string
        |> OptimizedDecoder.map (\asset -> Cloudinary.url asset Nothing 400 300)
