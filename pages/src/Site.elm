module Site exposing (config)

import Cloudinary
import DataSource
import Head
import MimeType
import Pages.Manifest as Manifest
import Pages.Url
import Route
import SiteConfig exposing (SiteConfig)


config : SiteConfig Data
config =
    { data = data
    , canonicalUrl = canonicalUrl
    , manifest = manifest
    , head = head
    }


type alias Data =
    ()


data : DataSource.DataSource Data
data =
    DataSource.succeed ()


head : Data -> List Head.Tag
head static =
    [ Head.icon [ ( 32, 32 ) ] MimeType.Png (cloudinaryIcon MimeType.Png 32)
    , Head.icon [ ( 16, 16 ) ] MimeType.Png (cloudinaryIcon MimeType.Png 16)
    , Head.appleTouchIcon (Just 180) (cloudinaryIcon MimeType.Png 180)
    , Head.appleTouchIcon (Just 192) (cloudinaryIcon MimeType.Png 192)
    , Head.rssLink "/blog/feed.xml"
    , Head.sitemapLink "/sitemap.xml"
    ]


canonicalUrl : String
canonicalUrl =
    "https://reddoorcollective.org"


manifest : Data -> Manifest.Config
manifest static =
    Manifest.init
        { name = "Red Door Collective"
        , description = "Red Door Collective - " ++ tagline
        , startUrl = Route.Index |> Route.toPath
        , icons =
            [ icon webp 192
            , icon webp 512
            , icon MimeType.Png 192
            , icon MimeType.Png 512
            ]
        }
        |> Manifest.withShortName "RDC"


tagline : String
tagline =
    "Grassroots tenant organizing in Nashville, Tennessee."


webp : MimeType.MimeImage
webp =
    MimeType.OtherImage "webp"


icon :
    MimeType.MimeImage
    -> Int
    -> Manifest.Icon
icon format width =
    { src = cloudinaryIcon format width
    , sizes = [ ( width, width ) ]
    , mimeType = format |> Just
    , purposes = [ Manifest.IconPurposeAny, Manifest.IconPurposeMaskable ]
    }


cloudinaryIcon :
    MimeType.MimeImage
    -> Int
    -> Pages.Url.Url
cloudinaryIcon mimeType width =
    Cloudinary.urlSquare "avatars/red-door-logo.png" (Just mimeType) width
