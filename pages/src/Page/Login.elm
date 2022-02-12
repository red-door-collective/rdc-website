module Page.Login exposing (Data, Model, Msg, page)

{-| The login page.
-}

import Browser.Navigation as Nav
import DataSource exposing (DataSource)
import Element exposing (Element, centerX, column, fill, height, maximum, padding, px, row, spacing, text, width)
import Form exposing (Problem(..))
import Head
import Head.Seo as Seo
import Http
import Json.Encode as Encode
import Logo
import Page exposing (StaticPayload)
import Pages.PageUrl exposing (PageUrl)
import Path exposing (Path)
import Rest
import Runtime
import Session exposing (Session)
import Shared
import Sprite
import UI.Button as Button
import UI.Icon as Icon
import UI.Link as Link
import UI.RenderConfig exposing (RenderConfig)
import UI.Size
import UI.TextField as TextField
import View exposing (View)
import Viewer exposing (Viewer)


loginForm : RenderConfig -> List (Problem ValidatedField) -> Form -> Element Msg
loginForm cfg problems form =
    let
        emailField =
            TextField.username EnteredEmail
                "Email"
                form.email
                |> TextField.withPlaceholder "your.name@reddoorcollective.org"
                |> TextField.setLabelVisible True
                |> TextField.withWidth TextField.widthFull

        emailErrors =
            List.filterMap toEmailProblems problems

        passwordField =
            TextField.currentPassword EnteredPassword
                "Password"
                form.password
                |> TextField.withPlaceholder "********"
                |> TextField.setLabelVisible True
                |> TextField.withWidth TextField.widthFull
                |> TextField.withOnEnterPressed GetCredentials

        passwordErrors =
            List.filterMap toPasswordProblems problems
    in
    Element.column
        [ Element.centerY
        , Element.centerX
        , Element.spacingXY 8 24
        , Element.padding 32
        , width (fill |> maximum 400)
        ]
        [ TextField.renderElement cfg <|
            if List.isEmpty emailErrors then
                emailField

            else
                TextField.withError (String.join " " emailErrors) emailField
        , TextField.renderElement cfg <|
            if List.isEmpty passwordErrors then
                passwordField

            else
                TextField.withError (String.join " " passwordErrors) passwordField
        , row [ width fill ]
            [ Button.fromLabel "Log in"
                |> Button.cmd GetCredentials Button.primary
                |> Button.renderElement cfg
            ]
        , row [ width fill ]
            [ Button.fromLabeledOnLeftIcon (Icon.arrowRight "Need an account? Register")
                |> Button.redirect (Link.link "/register") Button.hyperlink
                |> Button.withSize UI.Size.medium
                |> Button.renderElement cfg
            ]
        ]


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
        , image = Logo.smallImage
        , description = "Log in to the Red Door Collective Administration Center"
        , locale = Just "en-us"
        , title = title
        }
        |> Seo.website



-- MODEL


type alias Model =
    { session : Session
    , problems : List (Problem ValidatedField)
    , form : Form
    }


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


title =
    "Red Door Collective | Login"


toEmailProblems problem =
    case problem of
        InvalidEntry Email errMsg ->
            Just errMsg

        InvalidEntry _ _ ->
            Nothing

        ServerError errors ->
            errors
                |> List.filterMap
                    (\e ->
                        if e.title == "email" then
                            Just e.details

                        else
                            Nothing
                    )
                |> String.join " "
                |> Just


toPasswordProblems problem =
    case problem of
        InvalidEntry Password errMsg ->
            Just errMsg

        InvalidEntry _ _ ->
            Nothing

        ServerError errors ->
            errors
                |> List.filterMap
                    (\e ->
                        if e.title == "password" then
                            Just e.details

                        else
                            Nothing
                    )
                |> String.join " "
                |> Just


isFormWide problem =
    case problem of
        InvalidEntry _ _ ->
            False

        ServerError errors ->
            List.isEmpty
                (List.filter
                    (\e -> List.member e.title [ "email", "password" ])
                    errors
                )


view :
    Maybe PageUrl
    -> Shared.Model
    -> Model
    -> StaticPayload Data RouteParams
    -> View Msg
view maybeUrl sharedModel model static =
    let
        formWideProblems =
            List.filter isFormWide model.problems

        cfg =
            sharedModel.renderConfig
    in
    { title = title
    , body =
        [ Element.el [ width (px 0), height (px 0) ] (Element.html Sprite.all)
        , column [ width fill, centerX, spacing 20, padding 20 ]
            [ row [ centerX ] (List.map Form.viewProblem formWideProblems)
            , row [ width fill ]
                [ loginForm
                    sharedModel.renderConfig
                    model.problems
                    model.form
                ]
            ]
        ]
    }



-- UPDATE


type Msg
    = GetCredentials
    | EnteredEmail String
    | EnteredPassword String
    | CompletedLogin (Result Rest.HttpError Viewer)


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
        GetCredentials ->
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
            ( { model
                | problems =
                    error
                        |> Rest.httpErrorToSpec
                        |> ServerError
                        |> List.singleton
                        |> List.append model.problems
              }
            , Cmd.none
            )

        CompletedLogin (Ok viewer) ->
            ( model
            , Viewer.store viewer
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
    Sub.none



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
validate : Form -> Result (List (Problem ValidatedField)) TrimmedForm
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


validateField : TrimmedForm -> ValidatedField -> List (Problem ValidatedField)
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
