module Page.Organize.Event exposing (Model, Msg, init, subscriptions, toSession, update, view)

import Api exposing (Cred)
import Api.Endpoint as Endpoint
import Campaign exposing (Campaign)
import Color
import Defendant exposing (Defendant)
import DetainerWarrant exposing (DetainerWarrant)
import Element exposing (Element, centerX, column, fill, height, image, link, maximum, minimum, padding, paragraph, px, row, spacing, table, text, textColumn, width)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Input as Input
import Event exposing (Event(..), PhoneBankEvent)
import FeatherIcons
import Html.Events
import Http
import Json.Decode as Decode
import Palette
import Session exposing (Session)
import Settings exposing (Settings)
import User exposing (User)
import Widget
import Widget.Icon


type alias PhoneBankForm =
    { tenant : Defendant
    }


type alias Model =
    { session : Session
    , event : Maybe Event
    , phoneBankForm : Maybe PhoneBankForm
    }


init : Int -> Int -> Session -> ( Model, Cmd Msg )
init campaignId eventId session =
    let
        maybeCred =
            Session.cred session
    in
    ( { session = session
      , event = Nothing
      , phoneBankForm = Nothing
      }
    , getEvent maybeCred eventId
    )


getEvent : Maybe Cred -> Int -> Cmd Msg
getEvent maybeCred id =
    Api.get (Endpoint.event id) maybeCred GotEvent (Api.itemDecoder Event.decoder)


type Msg
    = GotEvent (Result Http.Error (Api.Item Event))
    | ChangedSorting String
    | TogglePhoneBankForm Defendant


initPhoneBankForm : Defendant -> PhoneBankForm
initPhoneBankForm defendant =
    { tenant = defendant }


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GotEvent result ->
            case result of
                Ok eventPage ->
                    ( { model | event = Just <| eventPage.data }, Cmd.none )

                Err errMsg ->
                    ( model, Cmd.none )

        ChangedSorting column ->
            ( model, Cmd.none )

        TogglePhoneBankForm defendant ->
            ( { model
                | phoneBankForm =
                    case model.phoneBankForm of
                        Just phoneBankForm ->
                            if phoneBankForm.tenant.id == defendant.id then
                                Nothing

                            else
                                Just <| initPhoneBankForm defendant

                        Nothing ->
                            Just <| initPhoneBankForm defendant
              }
            , Cmd.none
            )


onEnter : msg -> Element.Attribute msg
onEnter msg =
    Element.htmlAttribute
        (Html.Events.on "keyup"
            (Decode.field "key" Decode.string
                |> Decode.andThen
                    (\key ->
                        if key == "Enter" then
                            Decode.succeed msg

                        else
                            Decode.fail "Not the enter key"
                    )
            )
        )


ascIcon =
    FeatherIcons.chevronUp
        |> Widget.Icon.elmFeather FeatherIcons.toHtml


sortIconStyle =
    { size = 20, color = Color.white }


descIcon =
    FeatherIcons.chevronDown
        |> Widget.Icon.elmFeather FeatherIcons.toHtml


noSortIcon =
    FeatherIcons.chevronDown
        |> Widget.Icon.elmFeather FeatherIcons.toHtml


sortBy : String
sortBy =
    "Name"


asc : Bool
asc =
    True


viewContactButton : Defendant -> Element Msg
viewContactButton tenant =
    row
        tableCellAttrs
        [ Input.button
            [ Background.color Palette.sred
            , Font.color Palette.white
            , Border.rounded 3
            , padding 5
            ]
            { onPress = Just <| TogglePhoneBankForm tenant, label = text "Start call" }
        ]


tableCellAttrs =
    [ Element.width fill
    , height (px 60)
    , Element.padding 10
    , Border.solid
    , Border.color Palette.grayLight
    , Border.widthEach { bottom = 1, left = 0, right = 0, top = 0 }
    ]


viewHeaderCell text =
    Element.row
        [ Element.width fill
        , Element.padding 10
        , Font.semiBold
        , Border.solid
        , Border.color Palette.grayLight
        , Border.widthEach { bottom = 1, left = 0, right = 0, top = 0 }
        ]
        [ Element.text text ]


viewTextRow text =
    Element.row tableCellAttrs
        [ Element.text text ]


viewDefendants : Maybe PhoneBankForm -> List Defendant -> Element Msg
viewDefendants maybeForm defendants =
    table []
        { data =
            case maybeForm of
                Just phoneBankForm ->
                    List.filter ((==) phoneBankForm.tenant.id << .id) defendants

                Nothing ->
                    defendants
        , columns =
            [ { header = viewHeaderCell "Name"
              , view = viewTextRow << .name
              , width = Element.fill
              }
            , { header = viewHeaderCell "Address"
              , view = viewTextRow << Maybe.withDefault "N/A" << .address
              , width = Element.fill
              }
            , { header = viewHeaderCell "Phone Number"
              , view =
                    \defendant ->
                        viewTextRow <|
                            case defendant.verifiedPhone of
                                Just phone ->
                                    phone.nationalFormat

                                Nothing ->
                                    defendant.potentialPhones
                                        |> Maybe.map (String.join "," << List.take 2 << String.split ",")
                                        |> Maybe.withDefault "N/A"
              , width = fill
              }
            , { header = viewHeaderCell "Phone Type"
              , view = viewTextRow << Maybe.withDefault "" << Maybe.andThen .phoneType << .verifiedPhone
              , width = fill
              }
            , { header = viewHeaderCell "Contact"
              , view = viewContactButton
              , width = fill
              }
            ]
        }


heading : List (Element.Attribute Msg)
heading =
    [ centerX, Font.size 26 ]


viewPhoneBank : User -> Maybe PhoneBankForm -> PhoneBankEvent -> Element Msg
viewPhoneBank user maybeForm phoneBank =
    column [ width fill, spacing 10 ]
        [ row heading [ text phoneBank.name ]
        , row [ width fill ]
            [ viewDefendants maybeForm phoneBank.tenants
            ]
        , row [ width fill, padding 10 ]
            [ case maybeForm of
                Just phoneBankForm ->
                    viewInfoGatheringForm user phoneBankForm

                Nothing ->
                    Element.none
            ]
        ]


viewEvent : User -> Maybe PhoneBankForm -> Event -> Element Msg
viewEvent user phoneBankForm event =
    case event of
        PhoneBank phoneBank ->
            viewPhoneBank user phoneBankForm phoneBank

        Canvass canvass ->
            row [] [ text canvass.name ]

        Generic generic ->
            row [] [ text generic.name ]


viewStepOne : User -> PhoneBankForm -> Element Msg
viewStepOne user phoneBankForm =
    paragraph [] [ text <| "\"Hi " ++ phoneBankForm.tenant.name ++ "! As I said, my name is " ++ user.name ++ " and I am with an organization called the Red Door Collective. We are a group of renters and tenants in Davidson County. I am calling because we are trying to speak to people with upcoming detainer warrants or evictions. Do you have a few minutes to talk?\"" ]


viewStepTwo : User -> Element Msg
viewStepTwo user =
    paragraph [] [ text <| "\"Awesome! We at Red Door Collective believe housing is a human right and no one should be evicted, especially in a pandemic. We are calling people who have gotten detainer warrants ahead of their court dates to make sure people understand the legal process, know their rights as renters, and are aware of local resources. You said you got a detainer warrant, correct?” [Get to know the tenant and ask about their situation, including if they have plans to leave their residence or worked something out with their landlord, have gotten aid or a lawyer, if they are going to go to court.]\"" ]


viewStepThree : PhoneBankForm -> List (Element Msg)
viewStepThree phoneBankForm =
    [ paragraph [] [ text "Step 3: [Depending on how the conversation goes, communicate the following information]." ]
    , paragraph [] [ text "If they want to know how detainer warrants/the legal process works: Go to “A Reminder on the Proper Legal Eviction Process” section of the Open Table website link." ]
    , paragraph [] [ text "If they have an upcoming court date: Currently, all eviction cases are pushed back through June. If your date was between now and then, the plaintiff or your landlord will need to reschedule with the court and they are supposed to inform you of the date. They may not do that, so you should find it yourself [see next section]. " ]
    , paragraph []
        [ text "If they don’t know their court date: “To find out your court date, you can call the court clerks on a regular basis to ask when their court date is scheduled. Their phone number is 615-862-5195. You can also check "
        , link [ Font.color Palette.blueLight, Font.underline ] { url = "http://circuitclerk.nashville.gov", label = text "http://circuitclerk.nashville.gov" }
        , text " for the upcoming court cases. Go to the website and click “General Sessions” at the top and “civil dockets” on the left side. "
        ]
    , paragraph [] [ text "If they need legal assistance:" ]
    , paragraph [] [ text "If they need monetary assistance:" ]
    , paragraph []
        [ text "If they want to get in touch/join RDC: We meet weekly on Zoom every Thursday at 6:30PM. You can email us at "
        , link [ Font.color Palette.blueLight, Font.underline ] { url = "mailto:reddoormidtn@gmail.com", label = text "reddoormidtn@gmail.com" }
        , text "You can also fill out a form to join our group at [insert bit.ly]"
        ]
    , paragraph [] [ text "ALL LINKS/REFERENCES: https://linktr.ee/reddoorcollective" ]
    ]


viewInfoGatheringForm : User -> PhoneBankForm -> Element Msg
viewInfoGatheringForm user phoneBankForm =
    textColumn [ centerX, spacing 10 ]
        ([ paragraph []
            [ text <| "Start with:"
            ]
         , paragraph []
            [ text <| "Hi! My name is " ++ user.name ++ ". Am I speaking with " ++ phoneBankForm.tenant.name ++ "?\"" ]
         , paragraph []
            [ text "If no: \"Sorry for the wrong number! Have a nice day.\"" ]
         , paragraph []
            [ text "If yes: continue"
            ]
         , viewStepOne user phoneBankForm
         , viewStepTwo user
         ]
            ++ viewStepThree phoneBankForm
        )


view : Settings -> Model -> { title : String, content : Element Msg }
view settings model =
    { title = "Organize - Campaign - Event"
    , content =
        row [ centerX, padding 10, Font.size 20, width (fill |> maximum 1200 |> minimum 800) ]
            [ column [ width fill, spacing 10 ]
                [ case ( model.event, settings.user ) of
                    ( Just event, Just user ) ->
                        row [ width fill ]
                            [ viewEvent user model.phoneBankForm event
                            ]

                    ( _, _ ) ->
                        Element.none
                ]
            ]
    }


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- EXPORT


toSession : Model -> Session
toSession model =
    model.session
