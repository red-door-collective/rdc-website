module Page.About exposing (Model, Msg, init, subscriptions, toSession, update, view)

import Element exposing (Element, fill)
import Element.Border as Border
import Element.Font as Font
import Palette
import Session exposing (Session)


type alias Model =
    { session : Session }


init : Session -> ( Model, Cmd Msg )
init session =
    ( { session = session }, Cmd.none )


type Msg
    = NoOp


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none )


view : Model -> { title : String, content : Element Msg }
view model =
    { title = "About", content = viewAbout }


header =
    [ Font.size 24, Font.bold, Font.color Palette.blackLight ]


viewAbout : Element Msg
viewAbout =
    Element.textColumn [ Element.centerX, Element.width (fill |> Element.maximum 675 |> Element.minimum 400), Element.spacing 20, Font.size 18, Element.padding 20 ]
        [ Element.paragraph header [ Element.text "Hello neighbor!" ]
        , Element.paragraph [] [ Element.text "We are a grassroots network of Nashville residents striving to build power in our local communities and bring Nashville together in a time of crisis. The Red Door Collective creates resources collectively to combat some of the struggles we are experiencing together due to the current economic and political climate. Some of the projects we’re developing include:" ]
        , Element.paragraph header [ Element.text "Community Health" ]
        , Element.paragraph [] [ Element.text "At this time we are focusing on making sure our neighbors have everything they need to stay healthy during the Covid-19 pandemic. If there is a lack of food, cleaning materials, medicine, social interaction (to be provided digitally to observe social distancing measures) we will connect those with need to those with an ability to help out. Safety is our number one priority, so all materials are properly sanitized before exchange." ]
        , Element.image [ Element.width fill ] { src = "/static/images/talk-about-socialism.png", description = "Two people talking about socialism" }
        , Element.paragraph header [ Element.text "Protection from unwanted development" ]
        , Element.paragraph [] [ Element.text "In times of crisis, some landlords and developers will take the opportunity to repossess property for development. Many neighborhoods in Nashville have experienced gentrification by such means. One of the first steps in combating unwanted development is communication and organization with neighbors who may also be affected." ]
        , Element.paragraph header [ Element.text "Community Gatherings" ]
        , Element.paragraph [] [ Element.text "Sometimes a passing hello is the most we interact with our neighbors. Folks in the Red Door Collective will plan block parties and potlucks so that neighbors have more opportunities to catch up with each other. For the time being, gatherings may have to be digital; we will work together to build social solidarity while being physically distant." ]
        , Element.image [ Element.width fill ] { src = "/static/images/people-talking2.png", description = "Two more people talking about socialism." }
        , Element.textColumn [ Element.padding 10, Border.widthEach { top = 1, bottom = 0, left = 0, right = 0 } ]
            [ Element.paragraph [ Font.center, Font.italic, Font.size 20 ] [ Element.text "We as workers cannot rely on external assistance like governments, non-profits and charities. We must build power for ourselves, by ourselves by uniting to become more than ourselves. We are all we got, but WE are all we need, because together we can weather any storm." ]
            , Element.paragraph [ Font.center, Font.italic, Font.size 20 ] [ Element.text "As Dr. King said, \"We may have all come on different ships, but we are in the same boat now.\"" ]
            ]
        ]


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- EXPORT


toSession : Model -> Session
toSession model =
    model.session
