module Page.NotFound exposing (view)

import Element exposing (Element)



-- VIEW


view : { title : String, content : Element msg }
view =
    { title = "Page Not Found"
    , content =
        Element.column []
            [ Element.row [] [ Element.text "Not Found" ]
            ]
    }
