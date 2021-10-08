module MultiInput exposing
    ( ViewConfig, UpdateConfig
    , Msg(..), State, init, update, subscriptions, view
    )

{-| A component to input multiple items and display/manage them comfortably.
You can completely customize the type of items it accepts or the way different items are split up. Examples are an input for multiple item (as in an item client's FROM field), or a tag input (as in Github's repository topics). It allows pasting in bulk, removing existing items and ammending the last typed item.
For a better feel of what you can do with this component, visit the [demo here](https://larribas.github.io/elm-multi-input/)


# Custom Configuration

@docs ViewConfig, UpdateConfig


# Main workflow

@docs Msg, State, init, update, subscriptions, view

-}

import Browser.Dom as Dom
import Browser.Events
import Element exposing (Element, alpha, column, el, fill, height, minimum, padding, paddingXY, paragraph, px, rgb255, row, spacing, text, transparent, width)
import Element.Background as Background
import Element.Border as Border
import Element.Events exposing (onMouseDown)
import Element.Font as Font
import Element.Input as Input
import Html
import Html.Attributes as Attr
import Html.Events as Ev
import Json.Decode as Json
import Regex exposing (Regex)
import Set
import String
import Task


{-| Internal messages to manage the component's state.
-}
type Msg
    = FocusElement
    | TextareaBlurred String
    | KeyDown Int
    | RemoveItem String
    | InputChanged String


{-| Component's internal state.
-}
type alias State =
    { nextItem : String
    , id : String
    , needsRefocus : Bool
    }


{-| Specific settings for the component's update function.
You can specify a list of strings that act as separators for the different items.
{ separators = [ "\\n", "\\t", ",", " " ] }
-}
type alias UpdateConfig =
    { separators : List String
    }


{-| Specific settings for the component's view function.
`isValid` determines whether a typed item is correct (and give visual feedback to the user)
`toOuterMsg` turns the internal messages for the component into messages from the outer page/component
{ placeholder = "Write your email here"
, isValid = \\x -> String.contains "@"
, toOuterMsg = MultiInputMsg
}
-}
type alias ViewConfig msg =
    { placeholder : String
    , isValid : String -> Bool
    , toOuterMsg : Msg -> msg
    }


{-| Initialize the component's state.
It needs a unique ID supplied by the user, in case there are several inputs like this on the same document. By default, we begin with an empty textarea.
-}
init : String -> State
init id =
    { nextItem = ""
    , id = id
    , needsRefocus = False
    }


{-| Updates the component's state and a supplied list of items.
Given a particular change on the input (e.g. a series of items have been pasted, the component has lost focus, a special key has been pressed...) it will update the list of distinct items and the current state of the component.
-}
update : UpdateConfig -> Msg -> State -> List String -> ( State, List String, Cmd Msg )
update conf msg state items =
    let
        nextItemIsEmpty =
            state.nextItem == ""

        noChanges =
            ( state, items, Cmd.none )
    in
    case msg of
        FocusElement ->
            ( { state | needsRefocus = False }
            , items
            , if state.needsRefocus then
                Task.attempt (\_ -> FocusElement) (Dom.focus state.id)

              else
                Cmd.none
            )

        KeyDown key ->
            case toSpecialKey key of
                Tab ->
                    if nextItemIsEmpty then
                        noChanges

                    else
                        ( { state | nextItem = "", needsRefocus = True }, dropDuplicates (items ++ [ state.nextItem ]), Cmd.none )

                Backspace ->
                    if nextItemIsEmpty then
                        case items |> List.reverse |> List.head of
                            Just previousEmail ->
                                ( { state | nextItem = previousEmail, needsRefocus = True }, items |> List.take (List.length items - 1), Cmd.none )

                            Nothing ->
                                noChanges

                    else
                        noChanges

                Other ->
                    noChanges

        InputChanged text ->
            let
                separatorRegex =
                    conf.separators
                        |> String.join "|"
                        |> Regex.fromString
                        |> Maybe.withDefault Regex.never

                allItems =
                    text |> Regex.split separatorRegex

                ( newItems, nextItem ) =
                    ( allItems |> List.take (List.length allItems - 1) |> List.filter (not << String.isEmpty)
                    , allItems |> List.drop (List.length allItems - 1) |> List.head |> Maybe.withDefault ""
                    )
            in
            ( { state | nextItem = nextItem, needsRefocus = True }, dropDuplicates (items ++ newItems), Cmd.none )

        RemoveItem item ->
            ( state, List.filter ((/=) item) items, Cmd.none )

        TextareaBlurred item ->
            if item /= "" then
                ( { state | nextItem = "" }, dropDuplicates (items ++ [ item ]), Cmd.none )

            else
                noChanges


{-| Subscribes to relevant events for the input
This allows the component to control the input focus properly, subscribing to the Browser's animation frame sequence.
The subscription is managed only when strictly needed, so it does not have an impact on performance.
-}
subscriptions : State -> Sub Msg
subscriptions state =
    if state.needsRefocus then
        Browser.Events.onAnimationFrame (always FocusElement)

    else
        Sub.none


bullet attrs =
    row ([] ++ attrs)


{-| Renders the component visually.
MultiInput.view MultiInputMsg [] "Write a placeholder here" model.inputItems model.inputItemsState
See README for actual examples.
-}
view : ViewConfig msg -> List (Element.Attribute msg) -> List String -> State -> Element msg
view conf customAttributes items state =
    column
        [ Background.color (rgb255 255 255 255)
        , padding 2
        , width fill
        ]
        [ row
            [ width fill
            , onMouseDown (conf.toOuterMsg FocusElement)
            , Background.color
                (rgb255 255 255 255)
            , padding 5
            , Border.width 1
            , Border.rounded 3
            , Border.color <| Element.rgb255 60 60 60
            , spacing 10
            , width (fill |> minimum 400)
            ]
            ((items |> List.map (viewItem conf state))
                ++ [ bullet [ width fill ] [ viewExpandingTextArea conf customAttributes state ]
                   ]
            )
        ]


pre attrs =
    column ([] ++ attrs)


{-| Renders an expanding text area (that is, a textarea element inspired by [this article](https://alistapart.com/article/expanding-text-areas-made-elegant)) used to hold the next item
-}
viewExpandingTextArea : ViewConfig msg -> List (Element.Attribute msg) -> State -> Element msg
viewExpandingTextArea conf customAttributes state =
    Input.multiline
        ([ Element.htmlAttribute <|
            Attr.id state.id
         , Element.htmlAttribute <| Ev.onBlur (conf.toOuterMsg <| TextareaBlurred state.nextItem)
         , Element.htmlAttribute <|
            onKeyDown (conf.toOuterMsg << KeyDown)
         , Border.width 0
         , width (fill |> Element.maximum 600)
         , paddingXY 5 10
         , Element.focused [ Border.innerGlow (Element.rgb255 255 255 255) 0 ]

         --  , Element.inFront
         --     (el
         --         [ -- transparent True
         --           padding 2
         --         ]
         --         (text <|
         --             if state.nextItem /= "" then
         --                 state.nextItem
         --             else
         --                 conf.placeholder
         --         )
         --     )
         ]
            ++ customAttributes
        )
        { onChange = conf.toOuterMsg << InputChanged
        , text = state.nextItem
        , placeholder = Just <| Input.placeholder [] (text conf.placeholder)
        , label = Input.labelHidden "Plaintiff aliases"
        , spellcheck = False
        }


{-| Describes a separate item (usually visualized as a capsule)
-}
viewItem : ViewConfig msg -> State -> String -> Element msg
viewItem conf state item =
    row
        [ padding 10
        , Background.color (rgb255 222 231 248)
        , Border.rounded 10
        , spacing 5
        ]
        [ text item
        , Input.button
            [ Element.paddingXY 5 0
            , Element.centerY
            , Font.center
            , Border.widthEach { bottom = 0, left = 1, right = 0, top = 0 }
            ]
            { onPress = Just <| conf.toOuterMsg <| RemoveItem item
            , label = el [ Element.centerY, Font.center ] (text "x")
            }
        ]


type SpecialKey
    = Tab
    | Backspace
    | Other


toSpecialKey : Int -> SpecialKey
toSpecialKey keyCode =
    case keyCode of
        8 ->
            Backspace

        9 ->
            Tab

        _ ->
            Other


onKeyDown : (Int -> msg) -> Html.Attribute msg
onKeyDown toMsg =
    Ev.on "keydown" <| Json.map toMsg Ev.keyCode


{-| Drop the duplicates in a list. It preserves the original order, keeping only the first
-}
dropDuplicates : List comparable -> List comparable
dropDuplicates xs =
    let
        step next ( set, acc ) =
            if Set.member next set then
                ( set, acc )

            else
                ( Set.insert next set, next :: acc )
    in
    List.foldl step ( Set.empty, [] ) xs |> Tuple.second |> List.reverse
