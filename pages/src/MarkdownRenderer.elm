module MarkdownRenderer exposing (renderer)

import Css
import Element exposing (Element, el, height, link, paragraph, rgb255, table, width)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Input
import Html.Styled as Html
import Html.Styled.Attributes as Attr exposing (css)
import Markdown.Block as Block
import Markdown.Html
import Markdown.Renderer
import SyntaxHighlight


renderer : Markdown.Renderer.Renderer (Element msg)
renderer =
    { heading = heading
    , paragraph = paragraph [] []
    , thematicBreak = Html.hr [] []
    , text = Html.text
    , strong = \content -> el [ Font.bold ] content
    , emphasis = \content -> el [ Font.italic ] content
    , blockQuote = paragraph [] []
    , codeSpan = code
    , link =
        \{ destination } body ->
            link
                []
                { url = destination, label = text body }
    , hardLineBreak = paragraph [] [ text "\n" ]
    , image =
        \image ->
            case image.title of
                Just _ ->
                    image [] { src = image.src, label = image.alt }

                Nothing ->
                    image [] { src = image.src, label = image.alt }
    , unorderedList =
        \items ->
            column []
                (items
                    |> List.map
                        (\item ->
                            case item of
                                Block.ListItem task children ->
                                    let
                                        checkbox =
                                            case task of
                                                Block.NoTask ->
                                                    text ""

                                                Block.IncompleteTask ->
                                                    Element.Input.checkbox
                                                        []
                                                        { checked = False
                                                        , label = text ""
                                                        , onChange = Nothing
                                                        , icon = Element.Input.defaultCheckbox
                                                        }

                                                Block.CompletedTask ->
                                                    Element.Input.checkbox
                                                        []
                                                        { checked = False
                                                        , label = text ""
                                                        , onChange = Nothing
                                                        , icon = Element.Input.defaultCheckbox
                                                        }
                                    in
                                    row [] (checkbox :: children)
                        )
                )
    , orderedList =
        \startingIndex items ->
            Html.ol
                (case startingIndex of
                    1 ->
                        [ Attr.start startingIndex ]

                    _ ->
                        []
                )
                (items
                    |> List.map
                        (\itemBlocks ->
                            Html.li []
                                itemBlocks
                        )
                )
    , html = Markdown.Html.oneOf []
    , codeBlock = codeBlock

    --\{ body, language } ->
    --    let
    --        classes =
    --            -- Only the first word is used in the class
    --            case Maybe.map String.words language of
    --                Just (actualLanguage :: _) ->
    --                    [ Attr.class <| "language-" ++ actualLanguage ]
    --
    --                _ ->
    --                    []
    --    in
    --    Html.pre []
    --        [ Html.code classes
    --            [ Html.text body
    --            ]
    --        ]
    , table = table []
    , tableHeader = row [] []
    , tableBody = table
    , tableRow = row [] []
    , strikethrough =
        \children -> paragraph [ Font.strike ] children
    , tableHeaderCell =
        \maybeAlignment ->
            let
                attrs =
                    maybeAlignment
                        |> Maybe.map
                            (\alignment ->
                                case alignment of
                                    Block.AlignLeft ->
                                        "left"

                                    Block.AlignCenter ->
                                        "center"

                                    Block.AlignRight ->
                                        "right"
                            )
                        |> Maybe.map Attr.align
                        |> Maybe.map List.singleton
                        |> Maybe.withDefault []
            in
            Html.th attrs
    , tableCell =
        \maybeAlignment ->
            let
                attrs =
                    maybeAlignment
                        |> Maybe.map
                            (\alignment ->
                                case alignment of
                                    Block.AlignLeft ->
                                        "left"

                                    Block.AlignCenter ->
                                        "center"

                                    Block.AlignRight ->
                                        "right"
                            )
                        |> Maybe.map Attr.align
                        |> Maybe.map List.singleton
                        |> Maybe.withDefault []
            in
            Html.td attrs
    }


rawTextToId : String -> String
rawTextToId rawText =
    rawText
        |> String.split " "
        |> String.join "-"
        |> String.toLower


heading : { level : Block.HeadingLevel, rawText : String, children : List (Element msg) } -> Element msg
heading { level, rawText, children } =
    case level of
        Block.H1 ->
            paragraph
                [ Font.size 36
                ]
                children

        Block.H2 ->
            paragraph
                [ Element.htmlAttribute <| Attr.id (rawTextToId rawText)
                , Element.htmlAttribute <| "name" (rawTextToId rawText)
                , Font.size 32
                ]
                [ link
                    []
                    { url = "#" ++ rawTextToId rawText
                    , label =
                        paragraph []
                            (children
                                ++ [ el
                                        []
                                        [ Html.text "#" ]
                                   ]
                            )
                    }
                ]

        _ ->
            (case level of
                Block.H1 ->
                    paragraph []

                Block.H2 ->
                    paragraph []

                Block.H3 ->
                    paragraph []

                Block.H4 ->
                    paragraph []

                Block.H5 ->
                    paragraph []

                Block.H6 ->
                    paragraph []
            )
                []
                children


code : String -> Element msg
code snippet =
    Element.el
        [ Background.color
            (Element.rgba255 50 50 50 0.07)
        , Border.rounded 2
        , Element.paddingXY 5 3
        , Font.family [ Font.typeface "Roboto Mono", Font.monospace ]
        ]
        (Element.text snippet)


codeBlock : { body : String, language : Maybe String } -> Html.Html msg
codeBlock details =
    SyntaxHighlight.elm details.body
        |> Result.map (SyntaxHighlight.toBlockHtml (Just 1))
        |> Result.map Html.fromUnstyled
        |> Result.withDefault (Html.pre [] [ Html.code [] [ Html.text details.body ] ])
