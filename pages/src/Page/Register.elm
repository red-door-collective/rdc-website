module Page.Register exposing (Data, Model, Msg, page)

import Alert exposing (Alert)
import Browser.Navigation as Nav
import DataSource exposing (DataSource)
import Element exposing (Element, alignBottom, alignTop, centerX, centerY, column, fill, height, maximum, padding, paddingXY, px, row, spacing, spacingXY, text, width)
import Form exposing (Problem(..))
import Head
import Head.Seo as Seo
import Http
import Json.Encode as Encode
import Logo
import Maybe.Extra
import Page exposing (StaticPayload)
import Pages.PageUrl exposing (PageUrl)
import Path exposing (Path)
import Regex
import Rest exposing (HttpError(..), httpErrorToStrings)
import Rest.Endpoint as Endpoint
import Runtime
import Session exposing (Session)
import Shared
import Sprite
import Time exposing (Posix)
import UI.Alert as Alert
import UI.Button as Button
import UI.Icon as Icon
import UI.LoadingView
import UI.RenderConfig exposing (RenderConfig)
import UI.TextField as TextField exposing (TextField)
import User exposing (User)
import View exposing (View)
import ZxcvbnPlus as PasswordStrength exposing (Score(..))


disableableField : Bool -> String -> TextField msg -> TextField msg
disableableField isSubmitting label field =
    if isSubmitting then
        TextField.static label label

    else
        field


problemStrings field problems =
    List.filterMap
        (\p ->
            case p of
                InvalidEntry candidate errMsg ->
                    if candidate == field then
                        Just errMsg

                    else
                        Nothing

                ServerError _ ->
                    Nothing
        )
        problems


loginForm : RenderConfig -> Bool -> List (Problem ValidatedField) -> Form -> Element Msg
loginForm cfg showPassword problems form =
    let
        validated =
            validate form

        ( showPassIcon, showPassStyle ) =
            if showPassword then
                ( Icon.eyeHide "Hide password", Button.switchedOn )

            else
                ( Icon.eye "Show password", Button.light )

        toField =
            disableableField (form.status == Submitting)

        passField =
            toField "Password"
                (TextField.newPassword EnteredPassword
                    "Password"
                    form.password
                )
                |> TextField.withPlaceholder "********"
                |> TextField.setLabelVisible True
                |> TextField.withWidth TextField.widthFull
                |> TextField.withOnEnterPressed SubmitRegistration
                |> TextField.setPasswordVisible showPassword

        passwordErrors =
            problemStrings Password problems

        hasPasswordErrors =
            not <| List.isEmpty passwordErrors

        emailField =
            toField "Email" (TextField.email EnteredEmail "Email" form.email)
                |> TextField.withPlaceholder "your.name@reddoorcollective.org"
                |> TextField.setLabelVisible True
                |> TextField.withWidth TextField.widthFull

        emailErrors =
            problemStrings Email problems

        firstNameField =
            toField "First name"
                (TextField.singlelineText EnteredFirstName
                    "First name"
                    form.firstName
                )
                |> TextField.withPlaceholder "Jane"
                |> TextField.setLabelVisible True
                |> TextField.withWidth TextField.widthFull

        firstNameErrors =
            problemStrings FirstName problems

        lastNameField =
            toField "Last name"
                (TextField.singlelineText EnteredLastName
                    "Last name"
                    form.lastName
                )
                |> TextField.withPlaceholder "Doe"
                |> TextField.setLabelVisible True
                |> TextField.withWidth TextField.widthFull

        lastNameErrors =
            problemStrings LastName problems
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
        , row
            [ spacingXY 5 0 ]
            [ column [ width fill ]
                [ TextField.renderElement cfg <|
                    if hasPasswordErrors then
                        TextField.withError (String.join " " passwordErrors) passField

                    else
                        passField
                ]
            , column
                (if hasPasswordErrors then
                    [ alignTop, paddingXY 0 24 ]

                 else
                    [ alignBottom ]
                )
                [ Button.fromIcon showPassIcon
                    |> Button.cmd ToggledPasswordVisibility showPassStyle
                    |> Button.renderElement cfg
                ]
            ]
        , TextField.renderElement cfg <|
            if List.isEmpty firstNameErrors then
                firstNameField

            else
                firstNameField
                    |> TextField.withError (String.join " " firstNameErrors)
        , TextField.renderElement cfg <|
            if List.isEmpty lastNameErrors then
                lastNameField

            else
                lastNameField
                    |> TextField.withError (String.join " " lastNameErrors)
        , Button.fromLabel "Register"
            |> Button.cmd SubmitRegistration Button.primary
            |> Button.renderElement cfg
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
        , description = "Create an account to access the Red Door Collective database."
        , locale = Just "en-us"
        , title = title
        }
        |> Seo.website



-- MODEL


type alias Model =
    { session : Session
    , problems : List (Problem ValidatedField)
    , form : Form
    , showPassword : Bool
    , alert : Maybe Alert
    }


type FormStatus
    = Editing
    | Submitting


type alias Form =
    { email : String
    , password : String
    , firstName : String
    , lastName : String
    , status : FormStatus
    }


emptyForm =
    { email = ""
    , password = ""
    , firstName = ""
    , lastName = ""
    , status = Editing
    }


init :
    Maybe PageUrl
    -> Shared.Model
    -> StaticPayload Data RouteParams
    -> ( Model, Cmd Msg )
init pageUrl sharedModel static =
    ( { session = sharedModel.session
      , problems = []
      , form = emptyForm
      , showPassword = False
      , alert = Nothing
      }
    , Cmd.none
    )



-- VIEW


title =
    "Red Door Collective | Register"


isServerError err =
    case err of
        ServerError _ ->
            True

        _ ->
            False


viewForm cfg model =
    let
        formLevelErrors =
            List.filter isServerError model.problems
    in
    [ row [ centerX ] (List.map Form.viewProblem formLevelErrors)
    , case model.alert of
        Just alert ->
            Alert.success
                (Alert.text alert)
                |> Alert.withGenericIcon
                |> Alert.renderElement cfg

        Nothing ->
            Element.none
    , row [ width fill ]
        [ loginForm
            cfg
            model.showPassword
            model.problems
            model.form
        ]
    ]


view :
    Maybe PageUrl
    -> Shared.Model
    -> Model
    -> StaticPayload Data RouteParams
    -> View Msg
view maybeUrl sharedModel model static =
    let
        cfg =
            sharedModel.renderConfig
    in
    { title = title
    , body =
        [ Element.el [ width (px 0), height (px 0) ] (Element.html Sprite.all)
        , column
            ([ width fill
             , centerX
             , spacing 20
             , padding 20
             ]
                ++ (if model.form.status == Submitting then
                        [ Element.inFront UI.LoadingView.large ]

                    else
                        []
                   )
            )
            (if Session.isLoggedIn sharedModel.session then
                [ text "Page Not Found" ]

             else
                viewForm cfg model
            )
        ]
    }



-- UPDATE


type Msg
    = SubmitRegistration
    | EnteredEmail String
    | EnteredPassword String
    | EnteredFirstName String
    | EnteredLastName String
    | ToggledPasswordVisibility
    | CompletedRegistration (Result HttpError User)
    | AlertExpired Posix


submitForm : Form -> Form
submitForm form =
    { form | status = Submitting }


backToEditing : Form -> Form
backToEditing form =
    { form | status = Editing }


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
        SubmitRegistration ->
            case validate model.form of
                Ok validForm ->
                    ( { model | problems = [], form = submitForm model.form }
                    , register (Runtime.domain payload.sharedData.runtime.environment) sharedModel.session validForm
                    )

                Err problems ->
                    ( { model | problems = problems, form = backToEditing model.form }
                    , Cmd.none
                    )

        EnteredEmail email ->
            updateForm (\form -> { form | email = email }) model

        EnteredPassword password ->
            updateForm (\form -> { form | password = password }) model

        EnteredFirstName name ->
            updateForm (\form -> { form | firstName = name }) model

        EnteredLastName name ->
            updateForm (\form -> { form | lastName = name }) model

        ToggledPasswordVisibility ->
            ( { model | showPassword = not model.showPassword }, Cmd.none )

        CompletedRegistration (Err error) ->
            ( { model
                | problems =
                    error
                        |> Rest.httpErrorToSpec
                        |> ServerError
                        |> List.singleton
                        |> List.append model.problems
                , form = backToEditing model.form
              }
            , Cmd.none
            )

        CompletedRegistration (Ok viewer) ->
            ( { model
                | alert =
                    Just
                        (Alert.disappearing
                            { lifetimeInSeconds = 10
                            , text =
                                "A confirmation link has been sent to " ++ model.form.email ++ ". You must confirm your account before logging in."
                            }
                        )
                , form = emptyForm
              }
            , Cmd.none
            )

        AlertExpired _ ->
            ( { model | alert = Nothing }, Cmd.none )


{-| Helper function for `update`. Updates the form and returns Cmd.none.
Useful for recording form fields!
-}
updateForm : (Form -> Form) -> Model -> ( Model, Cmd Msg )
updateForm transform model =
    ( { model | form = transform model.form }, Cmd.none )



-- SUBSCRIPTIONS


subscriptions : Maybe PageUrl -> RouteParams -> Path -> Model -> Sub Msg
subscriptions pageUrl params path model =
    model.alert
        |> Maybe.map (Alert.subscriptions { onExpiration = AlertExpired })
        |> Maybe.withDefault Sub.none



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
    | FirstName
    | LastName


fieldsToValidate : List ValidatedField
fieldsToValidate =
    [ Email
    , Password
    , FirstName
    , LastName
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


fieldIsBlank label fieldText =
    if String.isEmpty fieldText then
        [ label ++ " can't be blank." ]

    else
        []


validEmail fieldText =
    "[^@ \t\u{000D}\n]+@[^@ \t\u{000D}\n]+\\.[^@ \t\u{000D}\n]+"
        |> Regex.fromStringWith { multiline = False, caseInsensitive = True }
        |> Maybe.map (\regex -> not <| List.isEmpty <| Regex.findAtMost 1 regex fieldText)
        |> Maybe.withDefault False


emailIsValid fieldText =
    if validEmail fieldText then
        []

    else
        [ "Email is not valid." ]


passwordIsTooSimple pass =
    let
        result =
            PasswordStrength.zxcvbnPlus [] pass
    in
    if result.score /= SafelyUnguessable || result.score /= VeryUnguessable then
        Maybe.Extra.toList result.feedback.warning ++ result.feedback.suggestions

    else
        []


validateField : TrimmedForm -> ValidatedField -> List (Problem ValidatedField)
validateField (Trimmed form) field =
    List.map (InvalidEntry field) <|
        case field of
            Email ->
                fieldIsBlank "Email" form.email
                    ++ emailIsValid form.email

            Password ->
                fieldIsBlank "Password" form.password
                    ++ passwordIsTooSimple form.password

            FirstName ->
                fieldIsBlank "First name" form.firstName

            LastName ->
                fieldIsBlank "Last name" form.lastName


{-| Don't trim while the user is typing! That would be super annoying.
Instead, trim only on submit.
-}
trimFields : Form -> TrimmedForm
trimFields form =
    Trimmed
        { email = String.trim form.email
        , password = String.trim form.password
        , firstName = String.trim form.firstName
        , lastName = String.trim form.lastName
        , status = form.status
        }



-- HTTP


register : String -> Session -> TrimmedForm -> Cmd Msg
register domain session (Trimmed form) =
    let
        user =
            Encode.object
                [ ( "email", Encode.string form.email )
                , ( "password", Encode.string form.password )
                , ( "first_name", Encode.string form.firstName )
                , ( "last_name", Encode.string form.lastName )
                ]

        body =
            Http.jsonBody user
    in
    Rest.post (Endpoint.register domain) (Session.cred session) body CompletedRegistration User.decoder
