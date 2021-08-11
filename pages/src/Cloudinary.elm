module Cloudinary exposing (url, urlSquare)

import MimeType
import Pages.Url


url :
    String
    -> Maybe MimeType.MimeImage
    -> Int
    -> Int
    -> Pages.Url.Url
url asset format width height =
    let
        base =
            "https://res.cloudinary.com/red-door-collective/image/upload"

        fetch_format =
            case format of
                Just MimeType.Png ->
                    "png"

                Just (MimeType.OtherImage "webp") ->
                    "webp"

                Just _ ->
                    "auto"

                Nothing ->
                    "auto"

        transforms =
            [ "c_pad"
            , "c_fill"
            , "w_" ++ String.fromInt width
            , "h_" ++ String.fromInt height
            , "q_auto"
            , "f_" ++ fetch_format
            ]
                |> String.join ","
    in
    Pages.Url.external (base ++ "/" ++ transforms ++ "/" ++ asset)


urlSquare :
    String
    -> Maybe MimeType.MimeImage
    -> Int
    -> Pages.Url.Url
urlSquare asset format width =
    let
        base =
            "https://res.cloudinary.com/red-door-collective/image/upload"

        fetch_format =
            case format of
                Just MimeType.Png ->
                    "png"

                Just (MimeType.OtherImage "webp") ->
                    "webp"

                Just _ ->
                    "auto"

                Nothing ->
                    "auto"

        transforms =
            [ "c_pad"
            , "w_" ++ String.fromInt width
            , "h_" ++ String.fromInt width
            , "q_auto"
            , "f_" ++ fetch_format
            , "f_auto"
            ]
                |> String.join ","
    in
    Pages.Url.external (base ++ "/" ++ transforms ++ "/" ++ asset)
