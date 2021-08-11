module Page.Index exposing (Data, Model, Msg, page)

import Cloudinary
import DataSource exposing (DataSource)
import Head
import Head.Seo as Seo
import MimeType exposing (MimeType)
import Page exposing (Page, StaticPayload)
import Pages.PageUrl exposing (PageUrl)
import Pages.Url
import Path exposing (Path)
import Shared
import View exposing (View)


type alias Model =
    ()


type alias Msg =
    Never


type alias RouteParams =
    {}


page : Page RouteParams Data
page =
    Page.single
        { head = head
        , data = data
        }
        |> Page.buildNoState { view = view }


data : DataSource Data
data =
    DataSource.succeed ()


head :
    StaticPayload Data RouteParams
    -> List Head.Tag
head static =
    Seo.summary
        { canonicalUrlOverride = Nothing
        , siteName = "reddoormidtn"
        , image =
            { url = [ "images", "red-door-logo.png" ] |> Path.join |> Pages.Url.fromPath
            , alt = "Red Door Collective logo"
            , dimensions = Just { width = 300, height = 300 }
            , mimeType = Just "png"
            }
        , description = "Join the fight for dignified housing in Nashville!"
        , locale = Just "en-us"
        , title = "Red Door Collective"
        }
        |> Seo.website


type alias Data =
    ()


view :
    Maybe PageUrl
    -> Shared.Model
    -> StaticPayload Data RouteParams
    -> View Msg
view maybeUrl sharedModel static =
    View.placeholder "Index"
