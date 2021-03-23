module Page.Actions exposing (Model, Msg, init, subscriptions, toSession, update, view)

import Color
import Element exposing (Element, centerX, el, fill, height, image, maximum, minimum, padding, paragraph, px, spacing, text, textColumn, width)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Html exposing (iframe)
import Html.Attributes as Attr
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
    { title = "Actions", content = viewAbout }


header =
    [ Font.size 22, Font.bold, Font.color Palette.blackLight ]


videoWidth =
    560


videoHeight =
    315


videoEmbed src =
    el [ width (px videoWidth), height (px videoHeight), centerX ]
        (Element.html
            (iframe
                [ Attr.width videoWidth
                , Attr.height videoHeight
                , Attr.src src
                , Attr.title "YouTube video player"
                , Attr.attribute "frameborder" "0"
                , Attr.attribute "allow" "accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
                , Attr.attribute "allowfullscreen" ""
                ]
                []
            )
        )


dataExplanation : String
dataExplanation =
    "https://www.youtube.com/embed/kOuhKZxVF00"


tanfFunds : String
tanfFunds =
    "https://www.youtube.com/embed/63lSmZ0nNNk"


cdcStatement : String
cdcStatement =
    "https://www.youtube.com/embed/cu4Ir2nuvC0"


phonebank : String
phonebank =
    "https://www.youtube.com/embed/VwBXX4dYlwA"


blueLink =
    Element.newTabLink [ Font.color Palette.blueLight, Element.mouseOver [ Font.glow Palette.blueLight 1 ] ]


joinRdc =
    blueLink { url = "https://midtndsa.org/", label = paragraph [] [ text "Join us and help organize for tenants!" ] }


weeklyMeetings =
    [ paragraph []
        [ text "We meet virtually on every Thursday at 6:30 PM CT. "
        ]
    , blueLink { url = "https://bit.ly/RDCWeekly", label = paragraph [] [ text "Click this link to join our weekly meeting." ] }
    ]


tile =
    Element.column
        [ padding 10
        , Font.center
        , spacing 20
        , Border.rounded 5
        , Border.width 1
        , Border.color Palette.grayLight
        , Element.mouseOver
            [ Border.shadow { offset = ( 0, 0 ), size = 0.5, blur = 0, color = Palette.redLight }
            , Border.color Palette.red
            , Background.color Palette.redLight
            ]
        ]


viewAbout : Element Msg
viewAbout =
    Element.textColumn [ centerX, width (fill |> maximum ((videoWidth * 2) + 120) |> minimum videoWidth), spacing 20, Font.size 18, padding 20, Font.center ]
        ([ Element.wrappedRow [ spacing 10 ]
            [ tile
                [ paragraph header [ text "Data - How we know who to help" ]
                , videoEmbed dataExplanation
                ]
            , tile
                [ paragraph header [ text "Policy & Legal - How we inform and agitate" ]
                , videoEmbed tanfFunds
                ]
            ]
         , Element.wrappedRow [ spacing 10 ]
            [ tile
                [ paragraph header [ text "Comms - How we get out the word" ]
                , videoEmbed cdcStatement
                ]
            , tile
                [ paragraph header [ text "Organizing - How we steer the conversation" ]
                , videoEmbed phonebank
                ]
            ]
         , joinRdc
         ]
            ++ weeklyMeetings
        )


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- EXPORT


toSession : Model -> Session
toSession model =
    model.session
