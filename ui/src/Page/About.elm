module Page.About exposing (Model, Msg, init, subscriptions, toSession, update, view)

import Element exposing (Element, centerX, fill, image, maximum, minimum, padding, paragraph, px, spacing, text, textColumn, width)
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
    Element.textColumn [ centerX, width (fill |> maximum 675 |> minimum 400), spacing 20, Font.size 18, padding 20 ]
        [ Element.el [ width fill ] (image [ width (px 350), centerX ] { src = "/static/images/dsa-handdrawn-logo.png", description = "Drawing of a handshake with a rose in the background." })
        , paragraph header [ text "Hello neighbor!" ]
        , paragraph [] [ text "We are a grassroots network of Nashville residents striving to build power in our local communities and bring Nashville together in a time of crisis. The Red Door Collective creates resources collectively to combat some of the struggles we are experiencing together due to the current economic and political climate. Some of the projects we’re developing include:" ]
        , paragraph header [ text "Community Health" ]
        , paragraph [] [ text "At this time we are focusing on making sure our neighbors have everything they need to stay healthy during the Covid-19 pandemic. If there is a lack of food, cleaning materials, medicine, social interaction (to be provided digitally to observe social distancing measures) we will connect those with need to those with an ability to help out. Safety is our number one priority, so all materials are properly sanitized before exchange." ]
        , image [ width fill ] { src = "/static/images/talk-about-socialism.png", description = "Two people talking about socialism" }
        , paragraph header [ text "Protection from unwanted development" ]
        , paragraph [] [ text "In times of crisis, some landlords and developers will take the opportunity to repossess property for development. Many neighborhoods in Nashville have experienced gentrification by such means. One of the first steps in combating unwanted development is communication and organization with neighbors who may also be affected." ]
        , paragraph header [ text "Community Gatherings" ]
        , paragraph [] [ text "Sometimes a passing hello is the most we interact with our neighbors. Folks in the Red Door Collective will plan block parties and potlucks so that neighbors have more opportunities to catch up with each other. For the time being, gatherings may have to be digital; we will work together to build social solidarity while being physically distant." ]
        , image [ width fill ] { src = "/static/images/people-talking2.png", description = "Two more people talking about socialism." }
        , paragraph header [ text "Community Gardens" ]
        , paragraph [] [ text "Nashville has far fewer community gardens today than it has in the past; RDC will build garden plots to liven up the neighborhood and provide food to anyone in need." ]
        , paragraph header [ text "Transit" ]
        , paragraph [] [ text "We will demand sidewalks, more bus stops, and lowering bus fares from our city officials. We will also build benches so pedestrians can rest. " ]
        , paragraph header [ text "Community Art" ]
        , paragraph [] [ text "We want to liven up the physical spaces in our communities by painting murals for everyone to enjoy." ]
        , paragraph header [ text "Collective Power" ]
        , paragraph [] [ text "Most importantly, to safeguard ourselves and our family’s well-being, we will build collective power through tenant’s unions and associations which will let us exert our power as workers and renters against exploitation and poverty." ]
        , textColumn [ padding 10, Border.widthEach { top = 1, bottom = 0, left = 0, right = 0 } ]
            [ paragraph [ Font.center, Font.italic, Font.size 20 ] [ text "We as workers cannot rely on external assistance like governments, non-profits and charities. We must build power for ourselves, by ourselves by uniting to become more than ourselves. We are all we got, but WE are all we need, because together we can weather any storm." ]
            , paragraph [ Font.center, Font.italic, Font.size 20 ] [ text "As Dr. King said, \"We may have all come on different ships, but we are in the same boat now.\"" ]
            ]
        , image [ width fill ]
            { src = "/static/images/intrographic.png"
            , description = "A printable infographic that introduces Red Door Collective."
            }
        ]


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- EXPORT


toSession : Model -> Session
toSession model =
    model.session
