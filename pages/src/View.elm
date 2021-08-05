module View exposing (View, map, placeholder)

import Element exposing (Element)


type alias View msg =
    { title : String
    , body : List (Element msg)
    }


map : (msg1 -> msg2) -> View msg1 -> View msg2
map fn view =
    { title = view.title
    , body = List.map (Element.map fn) view.body
    }


placeholder : String -> View msg
placeholder moduleName =
    { title = "Placeholder"
    , body = [ Element.text moduleName ]
    }
