module Cloudinary exposing (url, urlSquare, urlTint)

import MimeType
import Pages.Url


album =
    "v1628629255"


url :
    String
    -> Maybe MimeType.MimeImage
    -> Int
    -> Pages.Url.Url
url asset format width =
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
            , "q_auto"
            , "f_" ++ fetch_format
            ]
                |> String.join ","
    in
    Pages.Url.external (base ++ "/" ++ transforms ++ "/" ++ asset)


urlTint :
    String
    -> Maybe MimeType.MimeImage
    -> Int
    -> Int
    -> Pages.Url.Url
urlTint asset format width height =
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
            -- [ "c_pad"
            [ "q_auto"
            , "w_" ++ String.fromInt width
            , "h_" ++ String.fromInt height
            , "f_" ++ fetch_format
            , "f_auto"
            , "c_fill"
            ]
                |> String.join ","

        filters =
            [ "e_grayscale"
            , "e_tint:65:red"
            , "e_brightness:-20"
            ]
                |> String.join "/"
    in
    Pages.Url.external (base ++ "/" ++ transforms ++ "/" ++ filters ++ "/" ++ asset)


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
            -- [ "c_pad"
            -- , "w_" ++ String.fromInt width
            -- , "h_" ++ String.fromInt width
            [ "q_auto"

            -- , "f_" ++ fetch_format
            , "f_auto"
            ]
                |> String.join ","

        filters =
            [ "e_grayscale"
            , "e_tint:50:red"
            ]
                |> String.join "/"
    in
    Pages.Url.external (base ++ "/" ++ transforms ++ "/" ++ filters ++ "/" ++ asset)
