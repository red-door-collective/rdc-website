module Page.Blank exposing (view)

import Element exposing (Element)


view : { title : String, content : Element msg }
view =
    { title = ""
    , content = Element.text ""
    }
