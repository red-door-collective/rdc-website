module MarkdownRenderer exposing (renderer)

import Colors exposing (grayFont, redFont)
import Element
    exposing
        ( Color
        , Element
        , alignTop
        , centerX
        , centerY
        , clip
        , column
        , el
        , fill
        , height
        , link
        , padding
        , paddingEach
        , paddingXY
        , paragraph
        , rgb255
        , rgba
        , row
        , spacing
        , spacingXY
        , text
        , width
        )
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Input as Input
import Element.Region as Region
import Html
import Html.Attributes
import Markdown.Block as Block exposing (ListItem(..), Task(..))
import Markdown.Html
import Markdown.Renderer


type alias Colors =
    { largeHeaderFont : Color
    , largeHeaderBackground : Color
    , mediumHeaderFont : Color
    , mediumHeaderBackground : Color
    , smallHeaderFont : Color
    , smallHeaderBackground : Color
    , paragraph : Color
    }


renderer : Maybe Colors -> Markdown.Renderer.Renderer (Element msg)
renderer maybeColors =
    let
        colors =
            Maybe.withDefault Colors.default maybeColors
    in
    { heading = heading colors
    , paragraph =
        paragraph
            [ width fill
            , spacingXY 0 10
            , padding 10
            ]
    , thematicBreak = Element.none
    , text = \value -> paragraph [ width fill ] [ text value ]
    , strong = \content -> paragraph [ width fill, Font.bold, Font.color grayFont ] content
    , emphasis = \content -> paragraph [ width fill, Font.italic ] content
    , strikethrough = \content -> paragraph [ width fill, Font.strike ] content
    , codeSpan = code
    , link =
        \{ destination } body ->
            Element.newTabLink []
                { url = destination
                , label =
                    paragraph
                        [ Font.color (rgb255 0 0 255)
                        , Element.htmlAttribute (Html.Attributes.style "overflow-wrap" "break-word")
                        , Element.htmlAttribute (Html.Attributes.style "word-break" "break-word")
                        ]
                        body
                }
    , hardLineBreak = Html.br [] [] |> Element.html
    , image =
        \image ->
            case image.title of
                Just title ->
                    column [ width fill ]
                        [ paragraph [ Font.bold, Font.center, Font.color grayFont ] [ text title ]
                        , Element.image [ width fill ] { src = image.src, description = image.alt }
                        ]

                Nothing ->
                    Element.image [ width fill ] { src = image.src, description = image.alt }
    , blockQuote =
        \children ->
            paragraph
                [ Border.widthEach { top = 0, right = 0, bottom = 0, left = 10 }
                , padding 10
                , Border.color (rgb255 145 145 145)
                , Background.color (rgb255 245 245 245)
                , width fill
                ]
                children
    , unorderedList =
        \items ->
            column [ spacingXY 0 10, width fill, paddingXY 0 10 ]
                (items
                    |> List.map
                        (\(ListItem task children) ->
                            paragraph [ spacing 5 ]
                                [ paragraph
                                    [ alignTop ]
                                    ((case task of
                                        IncompleteTask ->
                                            Input.defaultCheckbox False

                                        CompletedTask ->
                                            Input.defaultCheckbox True

                                        NoTask ->
                                            text "•"
                                     )
                                        :: text " "
                                        :: children
                                    )
                                ]
                        )
                )
    , orderedList =
        \startingIndex items ->
            column [ spacingXY 0 10, width fill ]
                (items
                    |> List.indexedMap
                        (\index itemBlocks ->
                            paragraph [ spacing 5 ]
                                [ paragraph [ alignTop ]
                                    (text (String.fromInt (index + startingIndex) ++ " ") :: itemBlocks)
                                ]
                        )
                )
    , codeBlock = codeBlock
    , table = column [ width fill ]
    , tableHeader =
        column
            [ Font.bold
            , width fill
            , Font.center
            ]
    , tableBody = column [ width fill ]
    , tableRow =
        row
            [ height fill
            , width fill
            ]
    , tableHeaderCell =
        \_ children ->
            paragraph
                tableBorder
                children
    , tableCell =
        \_ children ->
            paragraph
                tableBorder
                children
    , html = Markdown.Html.oneOf []
    }


tableBorder =
    [ Border.color (rgb255 223 226 229)
    , Border.width 1
    , Border.solid
    , paddingXY 6 13
    , height fill
    , Font.color grayFont
    , Font.size 8
    , clip
    ]


rawTextToId : String -> String
rawTextToId rawText =
    rawText
        |> String.split " "
        |> String.join "-"
        |> String.toLower


heading : Colors -> { level : Block.HeadingLevel, rawText : String, children : List (Element msg) } -> Element msg
heading colors { level, rawText, children } =
    let
        attrs =
            [ Font.size 20
            , Font.bold
            , Font.family [ Font.typeface "system" ]
            , Region.heading (Block.headingLevelToInt level)
            , Element.htmlAttribute
                (Html.Attributes.attribute "name" (rawTextToId rawText))
            , Element.htmlAttribute
                (Html.Attributes.id (rawTextToId rawText))
            , paddingXY 10 15
            , Font.color colors.smallHeaderFont
            , width fill
            ]
    in
    column
        [ width fill
        , paddingEach { top = 15, bottom = 0, left = 0, right = 0 }
        ]
        [ case level of
            Block.H1 ->
                paragraph
                    (attrs
                        ++ [ Background.color colors.largeHeaderBackground
                           , Font.color colors.largeHeaderFont
                           , Font.center
                           , centerX
                           , centerY
                           , Font.size 40
                           ]
                    )
                    [ link
                        [ width fill ]
                        { url = "#" ++ rawTextToId rawText
                        , label = paragraph [ width fill ] children
                        }
                    ]

            Block.H2 ->
                paragraph
                    (attrs
                        ++ [ Background.color colors.mediumHeaderBackground
                           , Font.color colors.mediumHeaderFont
                           , paddingXY 10 15
                           , Font.size 36
                           ]
                    )
                    [ link
                        [ width fill ]
                        { url = "#" ++ rawTextToId rawText
                        , label = paragraph [ width fill ] children
                        }
                    ]

            Block.H3 ->
                paragraph (attrs ++ [ Font.size 26 ])
                    [ link
                        [ width fill ]
                        { url = "#" ++ rawTextToId rawText
                        , label = paragraph [ width fill ] children
                        }
                    ]

            Block.H4 ->
                paragraph (attrs ++ [ Font.color grayFont ]) children

            _ ->
                paragraph attrs children
        ]


code : String -> Element msg
code snippet =
    el
        [ Background.color
            (rgba 0 0 0 0.04)
        , Border.rounded 2
        , paddingXY 5 3
        , Font.family
            [ Font.external
                { url = "https://fonts.googleapis.com/css?family=Source+Code+Pro"
                , name = "Source Code Pro"
                }
            ]
        ]
        (text snippet)


codeBlock : { body : String, language : Maybe String } -> Element msg
codeBlock details =
    paragraph
        [ Background.color (rgba 0 0 0 0.03)
        , Element.htmlAttribute (Html.Attributes.style "white-space" "pre")
        , Element.htmlAttribute (Html.Attributes.style "overflow-wrap" "break-word")
        , Element.htmlAttribute (Html.Attributes.style "word-break" "break-word")
        , padding 20
        , Font.family
            [ Font.external
                { url = "https://fonts.googleapis.com/css?family=Source+Code+Pro"
                , name = "Source Code Pro"
                }
            ]
        ]
        [ text details.body ]
