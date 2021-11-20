module SplitButton exposing (Config, Msg, State, init, update, view)

import Element exposing (Element, fill, height, row, spacing, width)
import UI.Button as Button
import UI.Dropdown as Dropdown exposing (Dropdown)
import UI.Effects as Effects
import UI.RenderConfig exposing (RenderConfig)


type alias Config item msg =
    { itemToText : item -> String
    , dropdownMsg : Msg item -> msg
    , onSelect : Maybe item -> msg
    , onEnter : msg
    , renderConfig : RenderConfig
    }


type State item
    = State { dropdown : Dropdown.State item }


init : String -> State item
init id =
    State { dropdown = Dropdown.init id }


dropdown : Config item msg -> Dropdown.State item -> Dropdown item msg
dropdown config state =
    Dropdown.basic
        { dropdownMsg = DropdownMsg >> config.dropdownMsg
        , onSelectMsg = config.onSelect
        , state = state
        }


type Msg item
    = DropdownMsg (Dropdown.Msg item)


update : Config item msg -> Msg item -> State item -> ( State item, Cmd msg )
update config msg (State state) =
    case msg of
        DropdownMsg subMsg ->
            let
                ( newState, newCmd ) =
                    Dropdown.update config.renderConfig subMsg (dropdown config state.dropdown)
            in
            ( State { state | dropdown = newState }, Effects.perform newCmd )


view : Config item msg -> item -> List item -> State item -> Element msg
view config selected items (State state) =
    row [ width fill, height fill, spacing 5 ]
        [ Button.fromLabel (config.itemToText selected)
            |> Button.cmd config.onEnter Button.primary
            -- |> Button.withSize UI.Size.small
            |> Button.renderElement config.renderConfig
        , dropdown config state.dropdown
            |> Dropdown.withItems (List.filter ((/=) selected) items)
            |> Dropdown.withItemToText config.itemToText
            |> Dropdown.withMaximumListHeight 200
            |> Dropdown.withListWidth 200
            |> Dropdown.renderElement config.renderConfig
        ]
