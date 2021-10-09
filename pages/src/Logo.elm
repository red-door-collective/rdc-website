module Logo exposing (smallImage)

import Pages.Url
import Path


smallImage =
    { url = [ "images", "red-door-logo.png" ] |> Path.join |> Pages.Url.fromPath
    , alt = "Red Door Collective logo"
    , dimensions = Just { width = 300, height = 300 }
    , mimeType = Just "png"
    }
