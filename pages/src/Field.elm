module Field exposing (Field, view)

import Element exposing (Element, column, el, fill, height, maximum, padding, paddingXY, paragraph, spacingXY, text, textColumn, width)
import Element.Border as Border
import Element.Font as Font
import UI.Palette as Palette


type alias Field msg =
    { tooltip : Maybe String
    , children : List (Element msg)
    , label : Maybe String
    }


labelAttrs =
    [ Palette.toFontColor Palette.gray700, Font.size 12 ]


defaultLabel str =
    el labelAttrs (text str)


viewTooltip : String -> Element msg
viewTooltip str =
    textColumn
        [ width (fill |> maximum 280)
        , padding 10
        , Palette.toBackgroundColor Palette.blue600
        , Palette.toFontColor Palette.genericWhite
        , Border.rounded 3
        , Font.size 14
        , Border.shadow
            { offset = ( 0, 3 ), blur = 6, size = 0, color = Element.rgba 0 0 0 0.32 }
        ]
        [ paragraph [] [ text str ] ]


withTooltip : Bool -> String -> List (Element msg)
withTooltip showHelp str =
    if showHelp then
        [ viewTooltip str ]

    else
        []


view : Bool -> Field msg -> Element msg
view showHelp field =
    let
        tooltip =
            case field.tooltip of
                Just description ->
                    withTooltip showHelp description

                Nothing ->
                    []
    in
    column
        [ width fill
        , height fill
        , spacingXY 5 5
        , paddingXY 0 10
        ]
        (case field.label of
            Just label ->
                defaultLabel label :: field.children ++ tooltip

            Nothing ->
                field.children ++ tooltip
        )
