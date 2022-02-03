module Page.Events exposing (Data, Model, Msg, page)

import DataSource exposing (DataSource)
import Element exposing (centerX, column, fill, padding, row, width)
import Head
import Head.Seo as Seo
import Html exposing (iframe)
import Html.Attributes as Attr
import Logo
import Page exposing (Page, StaticPayload)
import Pages.PageUrl exposing (PageUrl)
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


type alias Data =
    ()


data : DataSource Data
data =
    DataSource.succeed ()


title =
    "Red Door Collective | Events"


head :
    StaticPayload Data RouteParams
    -> List Head.Tag
head static =
    Seo.summary
        { canonicalUrlOverride = Nothing
        , siteName = "Red Door Collective"
        , image = Logo.smallImage
        , description = "Organize Nashville tenants for dignified housing with us."
        , locale = Nothing
        , title = title
        }
        |> Seo.website


calendarIFrame =
    Element.html
        (iframe
            [ Attr.src "https://calendar.google.com/calendar/embed?height=600&wkst=1&bgcolor=%23ff5757&ctz=America%2FChicago&showTitle=1&showNav=1&showDate=1&showPrint=1&showTabs=1&showCalendars=1&title=Red%20Door%20Collective&src=cmVkZG9vcm1pZHRuQGdtYWlsLmNvbQ&color=%23039BE5"
            , Attr.style "border" "solid 1px #777"
            , Attr.width 800
            , Attr.height 600
            , Attr.attribute "frameborder" "0"
            , Attr.attribute "scrolling" "no"
            ]
            []
        )


view :
    Maybe PageUrl
    -> Shared.Model
    -> StaticPayload Data RouteParams
    -> View Msg
view maybeUrl sharedModel static =
    { title = title
    , body =
        [ column [ width fill, padding 20 ]
            [ row [ centerX ]
                [ calendarIFrame ]
            ]
        ]
    }
