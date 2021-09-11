module Page.Login exposing (Data, Model, Msg, page)

{-| The login page.
-}

import Browser.Navigation as Nav
import DataSource exposing (DataSource)
import DataSource.Port
import Element exposing (Element, centerX, column, fill, maximum, padding, row, spacing, text, width)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Input as Input
import Head
import Head.Seo as Seo
import Html.Events
import Http
import Json.Decode
import Json.Encode as Encode
import OptimizedDecoder as Decode exposing (Decoder, decodeString, field, string)
import OptimizedDecoder.Pipeline exposing (optional)
import Page exposing (Page, PageWithState, StaticPayload)
import Pages.PageUrl exposing (PageUrl)
import Pages.Url
import Palette
import Path exposing (Path)
import Rest exposing (Cred)
import Rest.Static
import Route exposing (Route)
import Runtime exposing (Runtime)
import Session exposing (Session)
import Shared
import View exposing (View)
import Viewer exposing (Viewer)


type alias RouteParams =
    {}


page : Page.PageWithState RouteParams Data Model Msg
page =
    Page.single
        { head = head
        , data = data
        }
        |> Page.buildWithLocalState
            { init = init
            , update = update
            , view = view
            , subscriptions = subscriptions
            }


type alias Data =
    ()


data : DataSource Data
data =
    DataSource.succeed ()


head :
    StaticPayload Data RouteParams
    -> List Head.Tag
head static =
    Seo.summary
        { canonicalUrlOverride = Nothing
        , siteName = "Red Door Collective"
        , image =
            { url = Pages.Url.external "https://reddoorcollective.org"
            , alt = "Red Door Collective Logo"
            , dimensions = Nothing
            , mimeType = Nothing
            }
        , description = "Red Door Collective Admin Login"
        , locale = Nothing
        , title = "Login"
        }
        |> Seo.website



-- MODEL


type alias Model =
    { session : Session
    , problems : List Problem
    , form : Form
    }


{-| Recording validation problems on a per-field basis facilitates displaying
them inline next to the field where the error occurred.
-}
type Problem
    = InvalidEntry ValidatedField String
    | ServerError String


type alias Form =
    { email : String
    , password : String
    }


init :
    Maybe PageUrl
    -> Shared.Model
    -> StaticPayload Data RouteParams
    -> ( Model, Cmd Msg )
init pageUrl sharedModel static =
    ( { session = sharedModel.session
      , problems = []
      , form =
            { email = ""
            , password = ""
            }
      }
    , Cmd.none
    )



-- VIEW


onEnter : msg -> Element.Attribute msg
onEnter msg =
    Element.htmlAttribute
        (Html.Events.on "keyup"
            (Json.Decode.field "key" Json.Decode.string
                |> Json.Decode.andThen
                    (\key ->
                        if key == "Enter" then
                            Json.Decode.succeed msg

                        else
                            Json.Decode.fail "Not the enter key"
                    )
            )
        )


view :
    Maybe PageUrl
    -> Shared.Model
    -> Model
    -> StaticPayload Data RouteParams
    -> View Msg
view maybeUrl sharedModel model static =
    { title = "Login"
    , body =
        [ column [ width (fill |> maximum 1000), centerX, spacing 20, padding 20 ]
            [ row [ Font.size 24, centerX ] [ text "Sign in" ]
            , row [ centerX ] (List.map viewProblem model.problems)
            , viewForm model.form
            ]
        ]
    }


primaryButton =
    Input.button
        [ Background.color Palette.sred
        , Font.color Palette.white
        , padding 10
        , Border.rounded 5
        ]


viewProblem : Problem -> Element msg
viewProblem problem =
    let
        errorMessage =
            case problem of
                InvalidEntry _ str ->
                    str

                ServerError str ->
                    str
    in
    column [] [ text errorMessage ]


viewForm : Form -> Element Msg
viewForm form =
    column [ centerX, spacing 20 ]
        [ row []
            [ Input.email
                []
                { onChange = EnteredEmail
                , placeholder = Just <| Input.placeholder [] (text "Email")
                , text = form.email
                , label = Input.labelHidden "Email"
                }
            ]
        , row []
            [ Input.currentPassword
                [ onEnter SubmittedForm ]
                { onChange = EnteredPassword
                , text = form.password
                , placeholder = Just <| Input.placeholder [] (text "Password")
                , label = Input.labelHidden "Password"
                , show = False
                }
            ]
        , row [ Element.alignRight ]
            [ primaryButton { onPress = Just SubmittedForm, label = text "Sign in" } ]
        ]



-- UPDATE


type Msg
    = SubmittedForm
    | EnteredEmail String
    | EnteredPassword String
    | CompletedLogin (Result Http.Error Viewer)
    | GotSession Session


update :
    PageUrl
    -> Maybe Nav.Key
    -> Shared.Model
    -> StaticPayload Data RouteParams
    -> Msg
    -> Model
    -> ( Model, Cmd Msg )
update pageUrl navKey sharedModel payload msg model =
    case msg of
        SubmittedForm ->
            case validate model.form of
                Ok validForm ->
                    ( { model | problems = [] }
                    , login (Runtime.domain payload.sharedData.runtime.environment) validForm
                    )

                Err problems ->
                    ( { model | problems = problems }
                    , Cmd.none
                    )

        EnteredEmail email ->
            updateForm (\form -> { form | email = email }) model

        EnteredPassword password ->
            updateForm (\form -> { form | password = password }) model

        CompletedLogin (Err error) ->
            let
                serverErrors =
                    Rest.decodeErrors error
                        |> List.map ServerError
            in
            ( { model | problems = List.append model.problems serverErrors }
            , Cmd.none
            )

        CompletedLogin (Ok viewer) ->
            ( model
            , Viewer.store viewer
            )

        GotSession session ->
            ( { model | session = session }
            , Maybe.withDefault Cmd.none <| Maybe.map (\key -> Nav.replaceUrl key "/dashboard") (Session.navKey session)
            )


{-| Helper function for `update`. Updates the form and returns Cmd.none.
Useful for recording form fields!
-}
updateForm : (Form -> Form) -> Model -> ( Model, Cmd Msg )
updateForm transform model =
    ( { model | form = transform model.form }, Cmd.none )



-- SUBSCRIPTIONS


subscriptions : Maybe PageUrl -> RouteParams -> Path -> Model -> Sub Msg
subscriptions pageUrl params path model =
    Session.changes GotSession (Session.navKey model.session)



-- FORM


{-| Marks that we've trimmed the form's fields, so we don't accidentally send
it to the server without having trimmed it!
-}
type TrimmedForm
    = Trimmed Form


{-| When adding a variant here, add it to `fieldsToValidate` too!
-}
type ValidatedField
    = Email
    | Password


fieldsToValidate : List ValidatedField
fieldsToValidate =
    [ Email
    , Password
    ]


{-| Trim the form and validate its fields. If there are problems, report them!
-}
validate : Form -> Result (List Problem) TrimmedForm
validate form =
    let
        trimmedForm =
            trimFields form
    in
    case List.concatMap (validateField trimmedForm) fieldsToValidate of
        [] ->
            Ok trimmedForm

        problems ->
            Err problems


validateField : TrimmedForm -> ValidatedField -> List Problem
validateField (Trimmed form) field =
    List.map (InvalidEntry field) <|
        case field of
            Email ->
                if String.isEmpty form.email then
                    [ "email can't be blank." ]

                else
                    []

            Password ->
                if String.isEmpty form.password then
                    [ "password can't be blank." ]

                else
                    []


{-| Don't trim while the user is typing! That would be super annoying.
Instead, trim only on submit.
-}
trimFields : Form -> TrimmedForm
trimFields form =
    Trimmed
        { email = String.trim form.email
        , password = String.trim form.password
        }



-- HTTP


login : String -> TrimmedForm -> Cmd Msg
login domain (Trimmed form) =
    let
        user =
            Encode.object
                [ ( "email", Encode.string form.email )
                , ( "password", Encode.string form.password )
                ]

        body =
            Http.jsonBody user
    in
    Rest.login domain body CompletedLogin Viewer.decoder
