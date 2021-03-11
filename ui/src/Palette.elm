module Palette exposing
    ( pink, blue, gold, red, green, cyan, teal, purple, rust, strongBlue
    , pinkLight, blueLight, goldLight, redLight, greenLight, cyanLight, tealLight, purpleLight
    , black, gray, grayLight, grayLightest
    , transparent
    )

{-|

@docs pink, blue, gold, red, green, cyan, teal, purple, rust, strongBlue


## Light

@docs pinkLight, blueLight, goldLight, redLight, greenLight, cyanLight, tealLight, purpleLight


## Gray scale

@docs black, gray, grayLight, grayLightest


## Other

@docs transparent

-}

import Element


{-| -}
pink : Element.Color
pink =
    Element.rgb255 245 105 215


{-| -}
pinkLight : Element.Color
pinkLight =
    Element.rgb255 244 143 177


{-| -}
gold : Element.Color
gold =
    Element.rgb255 205 145 60


{-| -}
goldLight : Element.Color
goldLight =
    Element.rgb255 255 204 128


{-| -}
blue : Element.Color
blue =
    Element.rgb255 3 169 244


{-| -}
blueLight : Element.Color
blueLight =
    Element.rgb255 128 222 234


{-| -}
green : Element.Color
green =
    Element.rgb255 67 160 71


{-| -}
greenLight : Element.Color
greenLight =
    Element.rgb255 197 225 165


{-| -}
red : Element.Color
red =
    Element.rgb255 216 27 96


{-| -}
redLight : Element.Color
redLight =
    Element.rgb255 239 154 154


{-| -}
rust : Element.Color
rust =
    Element.rgb255 205 102 51


{-| -}
purple : Element.Color
purple =
    Element.rgb255 156 39 176


{-| -}
purpleLight : Element.Color
purpleLight =
    Element.rgb255 206 147 216


{-| -}
cyan : Element.Color
cyan =
    Element.rgb255 0 229 255


{-| -}
cyanLight : Element.Color
cyanLight =
    Element.rgb255 128 222 234


{-| -}
teal : Element.Color
teal =
    Element.rgb255 29 233 182


{-| -}
tealLight : Element.Color
tealLight =
    Element.rgb255 128 203 196


{-| -}
strongBlue : Element.Color
strongBlue =
    Element.rgb255 89 51 204



-- GRAY SCALE


{-| -}
black : Element.Color
black =
    Element.rgb255 0 0 0


{-| -}
gray : Element.Color
gray =
    Element.rgb255 163 163 163


{-| -}
grayLight : Element.Color
grayLight =
    Element.rgb255 211 211 211


{-| -}
grayLightest : Element.Color
grayLightest =
    Element.rgb255 243 243 243


{-| -}
transparent : Element.Color
transparent =
    Element.rgba 0 0 0 0
