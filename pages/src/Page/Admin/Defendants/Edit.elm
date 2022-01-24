module Page.Admin.Defendants.Edit exposing (Data, Model, Msg, page)

import Browser.Events exposing (onMouseDown)
import Browser.Navigation as Nav
import DataSource exposing (DataSource)
import Defendant exposing (Defendant)
import Dict
import Element exposing (Element, below, centerX, column, el, fill, height, maximum, minimum, padding, paddingEach, paddingXY, paragraph, px, row, spacing, spacingXY, text, textColumn, width, wrappedRow)
import Element.Border as Border
import Element.Events as Events
import Element.Font as Font
import Element.Input as Input
import FeatherIcons
import Head
import Head.Seo as Seo
import Http
import Json.Decode as Decode
import Json.Encode as Encode
import List.Extra
import Log
import Logo
import MultiInput
import Page exposing (StaticPayload)
import Pages.PageUrl exposing (PageUrl)
import Path exposing (Path)
import QueryParams
import Regex
import Rest exposing (Cred)
import Rest.Endpoint as Endpoint
import Rollbar exposing (Rollbar)
import Runtime
import Session exposing (Session)
import Shared
import Sprite
import String.Extra as String
import UI.Button as Button
import UI.Icon as Icon
import UI.Palette as Palette
import UI.RenderConfig exposing (RenderConfig)
import UI.Size
import UI.TextField as TextField
import Url.Builder
import View exposing (View)


type alias FormOptions =
    { problems : List Problem
    , originalDefendant : Maybe Defendant
    , renderConfig : RenderConfig
    , showHelp : Bool
    }


type alias Form =
    { firstName : String
    , middleName : String
    , lastName : String
    , suffix : String
    , potentialPhones : List String
    }


type Problem
    = InvalidEntry ValidatedField String
    | ServerError String


type Tooltip
    = DefendantInfo
    | FirstNameInfo
    | MiddleNameInfo
    | LastNameInfo
    | SuffixInfo
    | PotentialPhoneNumbersInfo Int


type SaveState
    = SavingDefendant
    | Done


type alias Model =
    { id : Maybe Int
    , defendant : Maybe Defendant
    , problems : List Problem
    , form : FormStatus
    , saveState : SaveState
    , newFormOnSuccess : Bool
    , showHelp : Bool
    }


editForm : Defendant -> Form
editForm defendant =
    { firstName = defendant.firstName
    , middleName = Maybe.withDefault "" defendant.middleName
    , lastName = defendant.lastName
    , suffix = Maybe.withDefault "" defendant.suffix
    , potentialPhones =
        defendant.potentialPhones
            |> Maybe.map (String.split ",")
            |> Maybe.withDefault []
    }


initCreate : Form
initCreate =
    { firstName = ""
    , middleName = ""
    , lastName = ""
    , suffix = ""
    , potentialPhones = []
    }


type FormStatus
    = Initializing Int
    | Ready Form


init :
    Maybe PageUrl
    -> Shared.Model
    -> StaticPayload Data RouteParams
    -> ( Model, Cmd Msg )
init pageUrl sharedModel static =
    let
        session =
            sharedModel.session

        maybeCred =
            Session.cred session

        domain =
            Runtime.domain static.sharedData.runtime.environment

        maybeId =
            case pageUrl of
                Just url ->
                    url.query
                        |> Maybe.andThen (Dict.get "id" << QueryParams.toDict)
                        |> Maybe.andThen List.head
                        |> Maybe.andThen String.toInt

                Nothing ->
                    Nothing
    in
    ( { defendant = Nothing
      , id = maybeId
      , problems = []
      , form =
            case maybeId of
                Just id ->
                    Initializing id

                Nothing ->
                    Ready initCreate
      , saveState = Done
      , newFormOnSuccess = False
      , showHelp = False
      }
    , case maybeId of
        Just id ->
            getDefendant domain id maybeCred

        Nothing ->
            Cmd.none
    )


getDefendant : String -> Int -> Maybe Cred -> Cmd Msg
getDefendant domain id maybeCred =
    Rest.get (Endpoint.defendant domain id) maybeCred GotDefendant (Rest.itemDecoder Defendant.decoder)


type Msg
    = GotDefendant (Result Http.Error (Rest.Item Defendant))
    | ToggleHelp
    | ChangedFirstName String
    | ChangedMiddleName String
    | ChangedLastName String
    | ChangedSuffix String
    | ChangedPotentialPhones Int String
    | AddPotentialPhoneNumber
    | RemovePhone Int
    | SubmitForm
    | SubmitAndAddAnother
    | CreatedDefendant (Result Http.Error (Rest.Item Defendant))
    | NoOp


updateForm : (Form -> Form) -> Model -> ( Model, Cmd Msg )
updateForm transform model =
    ( { model
        | form =
            case model.form of
                Initializing _ ->
                    model.form

                Ready oldForm ->
                    Ready (transform oldForm)
      }
    , Cmd.none
    )


updateFormNarrow : (Form -> ( Form, Cmd Msg )) -> Model -> ( Model, Cmd Msg )
updateFormNarrow transform model =
    let
        ( newForm, cmd ) =
            case model.form of
                Initializing _ ->
                    ( model.form, Cmd.none )

                Ready oldForm ->
                    let
                        ( updatedForm, dropdownCmd ) =
                            transform oldForm
                    in
                    ( Ready updatedForm, dropdownCmd )
    in
    ( { model
        | form = newForm
      }
    , cmd
    )


savingError : Http.Error -> Model -> Model
savingError httpError model =
    let
        problems =
            [ ServerError "Error saving defendant" ]
    in
    { model | problems = problems }


defaultSeparators : List String
defaultSeparators =
    [ "\n", "\t" ]


multiInputUpdateConfig =
    { separators = defaultSeparators }


updatePotentialPhone candidate newPhone index existing =
    if candidate == index then
        newPhone

    else
        existing


update :
    PageUrl
    -> Maybe Nav.Key
    -> Shared.Model
    -> StaticPayload Data RouteParams
    -> Msg
    -> Model
    -> ( Model, Cmd Msg )
update pageUrl navKey sharedModel static msg model =
    let
        session =
            sharedModel.session

        rollbar =
            Log.reporting static.sharedData.runtime

        domain =
            Runtime.domain static.sharedData.runtime.environment

        logHttpError =
            error rollbar << Log.httpErrorMessage
    in
    case msg of
        GotDefendant result ->
            case result of
                Ok defendantPage ->
                    ( { model
                        | defendant = Just defendantPage.data
                        , form = Ready (editForm defendantPage.data)
                      }
                    , Cmd.none
                    )

                Err httpError ->
                    ( model, logHttpError httpError )

        ToggleHelp ->
            ( { model
                | showHelp = not model.showHelp
              }
            , Cmd.none
            )

        ChangedFirstName name ->
            updateForm (\form -> { form | firstName = name }) model

        ChangedMiddleName name ->
            updateForm (\form -> { form | middleName = name }) model

        ChangedLastName name ->
            updateForm (\form -> { form | lastName = name }) model

        ChangedSuffix text ->
            updateForm (\form -> { form | suffix = text }) model

        ChangedPotentialPhones index text ->
            updateForm (\form -> { form | potentialPhones = List.indexedMap (updatePotentialPhone index text) form.potentialPhones }) model

        AddPotentialPhoneNumber ->
            updateForm (\form -> { form | potentialPhones = form.potentialPhones ++ [ "" ] }) model

        RemovePhone index ->
            updateForm (\form -> { form | potentialPhones = List.Extra.removeAt index form.potentialPhones }) model

        SubmitForm ->
            submitForm domain session model

        SubmitAndAddAnother ->
            submitFormAndAddAnother domain session model

        CreatedDefendant (Ok defendantItem) ->
            nextStepSave
                session
                { model
                    | defendant = Just defendantItem.data
                }

        CreatedDefendant (Err httpError) ->
            ( savingError httpError model, logHttpError httpError )

        NoOp ->
            ( model, Cmd.none )


error : Rollbar -> String -> Cmd Msg
error rollbar report =
    Log.error rollbar (\_ -> NoOp) report


submitFormAndAddAnother : String -> Session -> Model -> ( Model, Cmd Msg )
submitFormAndAddAnother domain session model =
    Tuple.mapFirst (\m -> { m | newFormOnSuccess = True }) (submitForm domain session model)


submitForm : String -> Session -> Model -> ( Model, Cmd Msg )
submitForm domain session model =
    let
        maybeCred =
            Session.cred session
    in
    case validate model.form of
        Ok validForm ->
            let
                defendant =
                    toDefendant model.id validForm
            in
            ( { model
                | newFormOnSuccess = False
                , problems = []
                , saveState = SavingDefendant
              }
            , updateDefendant domain maybeCred model defendant
            )

        Err problems ->
            ( { model | newFormOnSuccess = False, problems = problems }
            , Cmd.none
            )


toDefendant : Maybe Int -> TrimmedForm -> Defendant
toDefendant id (Trimmed form) =
    { id = Maybe.withDefault -1 id
    , firstName = form.firstName
    , middleName = String.nonBlank form.middleName
    , lastName = form.lastName
    , suffix = String.nonBlank form.suffix
    , name = form.firstName ++ " " ++ form.lastName
    , aliases = []
    , potentialPhones = Nothing
    , verifiedPhone = Nothing
    }


nextStepSave : Session -> Model -> ( Model, Cmd Msg )
nextStepSave session model =
    case validate model.form of
        Ok form ->
            let
                defendant =
                    toDefendant model.id form
            in
            case model.saveState of
                SavingDefendant ->
                    ( { model | saveState = Done }
                    , Cmd.none
                    )

                Done ->
                    ( model
                    , if model.newFormOnSuccess then
                        Maybe.withDefault Cmd.none <|
                            Maybe.map (\key -> Nav.replaceUrl key (Url.Builder.relative [] [])) (Session.navKey session)

                      else
                        Maybe.withDefault Cmd.none <|
                            Maybe.map (\key -> Nav.replaceUrl key (Url.Builder.relative [ String.fromInt defendant.id ] [])) (Session.navKey session)
                    )

        Err _ ->
            ( model, Cmd.none )


type alias Field =
    { tooltip : Maybe Tooltip
    , description : String
    , children : List (Element Msg)
    }


requiredStar =
    el [ Palette.toFontColor Palette.red, Element.alignTop, width Element.shrink ] (text "*")


viewField : Bool -> Field -> Element Msg
viewField showHelp field =
    let
        tooltip =
            case field.tooltip of
                Just _ ->
                    withTooltip showHelp field.description

                Nothing ->
                    []
    in
    column
        [ width fill
        , height fill
        , spacingXY 5 5
        , paddingXY 0 10
        ]
        (field.children ++ tooltip)


withValidation : ValidatedField -> List Problem -> List (Element.Attr () msg) -> List (Element.Attr () msg)
withValidation validatedField problems attrs =
    let
        maybeError =
            problems
                |> List.filterMap
                    (\problem ->
                        case problem of
                            InvalidEntry field problemText ->
                                if validatedField == field then
                                    Just problemText

                                else
                                    Nothing

                            ServerError _ ->
                                Nothing
                    )
                |> List.head
    in
    attrs
        ++ (case maybeError of
                Just errorText ->
                    [ Palette.toBorderColor Palette.red
                    , Element.below
                        (row [ paddingXY 0 10, spacing 5, Font.size 14 ]
                            [ FeatherIcons.alertTriangle
                                |> FeatherIcons.withSize 16
                                |> FeatherIcons.toHtml []
                                |> Element.html
                                |> Element.el []
                            , text errorText
                            ]
                        )
                    ]

                Nothing ->
                    []
           )


textInput attrs config =
    Input.text ([] ++ attrs) config


requiredLabel labelFn str =
    labelFn [] (row [ spacing 5 ] [ text str, requiredStar ])


nonRequiredLabel labelFn str =
    labelFn [] (row [ spacing 5 ] [ text str ])


type alias PartOfName =
    { onChange : String -> Msg
    , text : String
    , label : String
    , description : String
    , tooltip : Tooltip
    , validation : ValidatedField
    , isRequired : Bool
    }


viewPartOfName : FormOptions -> PartOfName -> Element Msg
viewPartOfName options partOfName =
    column [ width (fill |> minimum 200), height fill, paddingXY 0 10 ]
        [ viewField options.showHelp
            { tooltip = Just partOfName.tooltip
            , description = partOfName.description
            , children =
                [ textInput
                    (withValidation partOfName.validation options.problems [ Input.focusedOnLoad ])
                    { onChange = partOfName.onChange
                    , text = partOfName.text
                    , placeholder = Nothing
                    , label =
                        partOfName.label
                            |> (if partOfName.isRequired then
                                    requiredLabel Input.labelAbove

                                else
                                    nonRequiredLabel Input.labelAbove
                               )
                    }
                ]
            }
        ]


matches : String -> String -> Bool
matches regex =
    let
        validRegex =
            Regex.fromString regex
                |> Maybe.withDefault Regex.never
    in
    Regex.findAtMost 1 validRegex >> List.isEmpty >> not


formGroup : List (Element Msg) -> Element Msg
formGroup group =
    row
        [ spacing 10
        , width fill
        ]
        group


tile : List (Element Msg) -> Element Msg
tile groups =
    column
        [ spacing 20
        , padding 20
        , width fill
        , Border.rounded 3
        , Palette.toBorderColor Palette.gray
        , Border.width 1
        , Border.shadow { offset = ( 0, 10 ), size = 1, blur = 30, color = Element.rgb 60 60 60 }
        ]
        groups


submitAndAddAnother : RenderConfig -> Element Msg
submitAndAddAnother cfg =
    Button.fromLabeledOnRightIcon (Icon.add "Save and add another")
        |> Button.cmd SubmitAndAddAnother Button.clear
        |> Button.renderElement cfg


submitButton : RenderConfig -> Element Msg
submitButton cfg =
    Button.fromLabeledOnRightIcon (Icon.check "Save")
        |> Button.cmd SubmitForm Button.primary
        |> Button.renderElement cfg


viewPotentialPhone options index phone =
    viewField options.showHelp
        { tooltip = Just <| PotentialPhoneNumbersInfo index
        , description = "Provide a phone number for the tenant so they will be called and texted during upcoming phonebanks and receive notifications about their detainer warrant updates."
        , children =
            [ TextField.singlelineText (ChangedPotentialPhones index)
                "Potential phone"
                phone
                |> TextField.setLabelVisible True
                |> TextField.withPlaceholder "123-456-7890"
                |> TextField.renderElement options.renderConfig
            , if index == 0 then
                Element.none

              else
                el
                    [ padding 2
                    , Element.alignTop
                    ]
                    (Button.fromIcon (Icon.close "Remove phone")
                        |> Button.cmd (RemovePhone index) Button.clear
                        |> Button.withSize UI.Size.extraSmall
                        |> Button.renderElement options.renderConfig
                    )
            ]
        }


viewForm : FormOptions -> FormStatus -> Element Msg
viewForm options formStatus =
    case formStatus of
        Initializing id ->
            column [] [ text ("Fetching defendant " ++ String.fromInt id) ]

        Ready form ->
            column
                [ centerX
                , spacing 30
                , width (fill |> maximum 1200)
                , Element.inFront
                    (case options.originalDefendant of
                        Just defendant ->
                            column [ Element.alignRight, padding 10 ]
                                [ Defendant.viewLargeWarrantsButton defendant
                                    |> Button.renderElement options.renderConfig
                                ]

                        Nothing ->
                            Element.none
                    )
                ]
                [ tile
                    [ paragraph [ Font.center, centerX ] [ text "Defendant" ]
                    , formGroup
                        (List.map (viewPartOfName options)
                            [ { onChange = ChangedFirstName
                              , text = form.firstName
                              , label = "First name"
                              , description = "Example: \"Jane\" in Jane Sue Doe, Jr."
                              , tooltip = FirstNameInfo
                              , validation = FirstName
                              , isRequired = True
                              }
                            , { onChange = ChangedMiddleName
                              , text = form.middleName
                              , label = "Middle name"
                              , description = "Example: \"Sue\" in Jane Sue Doe, Jr."
                              , tooltip = MiddleNameInfo
                              , validation = MiddleName
                              , isRequired = False
                              }
                            , { onChange = ChangedLastName
                              , text = form.lastName
                              , label = "Last name"
                              , description = "Example: \"Doe\" in Jane Sue Doe, Jr."
                              , tooltip = LastNameInfo
                              , validation = LastName
                              , isRequired = True
                              }
                            , { onChange = ChangedSuffix
                              , text = form.suffix
                              , label = "Suffix"
                              , description = "Example: \"Jr.\" in Jane Sue Doe, Jr."
                              , tooltip = SuffixInfo
                              , validation = Suffix
                              , isRequired = False
                              }
                            ]
                        )
                    , wrappedRow [ spacing 5 ]
                        (List.indexedMap (viewPotentialPhone options) form.potentialPhones ++ [ addPhoneButton options.renderConfig ])
                    ]
                , row [ Element.alignRight, spacing 10 ]
                    [ submitAndAddAnother options.renderConfig
                    , submitButton options.renderConfig
                    ]
                ]


addPhoneButton cfg =
    Button.fromIcon (Icon.add "Add potential phone number")
        |> Button.cmd AddPotentialPhoneNumber Button.primary
        |> Button.renderElement cfg


formOptions : RenderConfig -> Model -> FormOptions
formOptions cfg model =
    { problems = model.problems
    , originalDefendant = model.defendant
    , renderConfig = cfg
    , showHelp = model.showHelp
    }


viewProblem : Problem -> Element Msg
viewProblem problem =
    paragraph []
        [ case problem of
            InvalidEntry _ _ ->
                Element.none

            ServerError err ->
                text ("Something went wrong: " ++ err)
        ]


viewProblems : List Problem -> Element Msg
viewProblems problems =
    row [] [ column [] (List.map viewProblem problems) ]


viewTooltip : String -> Element Msg
viewTooltip str =
    textColumn
        [ width (fill |> maximum 280)
        , padding 10
        , Palette.toBackgroundColor Palette.blue600
        , Palette.toFontColor Palette.genericWhite
        , Border.rounded 3
        , Font.size 14
        , Border.shadow
            { offset = ( 0, 3 ), blur = 6, size = 0, color = Element.rgba 0 0 0 0.32 }
        ]
        [ paragraph [] [ text str ] ]


withTooltip : Bool -> String -> List (Element Msg)
withTooltip showHelp str =
    if showHelp then
        [ viewTooltip str ]

    else
        []


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
        , row
            [ centerX
            , padding 20
            , Font.size 20
            , width (fill |> maximum 1200 |> minimum 400)
            , Element.inFront
                (el
                    [ paddingEach { top = 0, bottom = 5, left = 0, right = 0 }
                    , Element.alignRight
                    ]
                    (Button.fromLabel "Help"
                        |> Button.cmd ToggleHelp Button.primary
                        |> Button.withSize UI.Size.small
                        |> Button.renderElement cfg
                    )
                )
            ]
            [ column [ centerX, spacing 10 ]
                [ row
                    [ width fill
                    ]
                    [ column [ centerX, width (px 300) ]
                        [ paragraph [ Font.center, centerX, width Element.shrink ]
                            [ text
                                ((case model.id of
                                    Just _ ->
                                        "Edit"

                                    Nothing ->
                                        "Create"
                                 )
                                    ++ " Defendant"
                                )
                            ]
                        ]
                    ]
                , viewProblems model.problems
                , row [ width fill ]
                    [ viewForm (formOptions cfg model) model.form
                    ]
                ]
            ]
        ]
    }


subscriptions : Maybe PageUrl -> RouteParams -> Path -> Model -> Sub Msg
subscriptions pageUrl params path model =
    Sub.none


isOutsideTooltip : String -> Decode.Decoder Bool
isOutsideTooltip tooltipId =
    Decode.oneOf
        [ Decode.field "id" Decode.string
            |> Decode.andThen
                (\id ->
                    if tooltipId == id then
                        Decode.succeed False

                    else
                        Decode.fail "continue"
                )
        , Decode.lazy (\_ -> isOutsideTooltip tooltipId |> Decode.field "parentNode")
        , Decode.succeed True
        ]


outsideTarget : String -> Msg -> Decode.Decoder Msg
outsideTarget tooltipId msg =
    Decode.field "target" (isOutsideTooltip tooltipId)
        |> Decode.andThen
            (\isOutside ->
                if isOutside then
                    Decode.succeed msg

                else
                    Decode.fail "inside dropdown"
            )


tooltipToString : Tooltip -> String
tooltipToString tip =
    case tip of
        DefendantInfo ->
            "defendant-info"

        FirstNameInfo ->
            "first-name-info"

        MiddleNameInfo ->
            "middle-name-info"

        LastNameInfo ->
            "last-name-info"

        SuffixInfo ->
            "suffix-info"

        PotentialPhoneNumbersInfo _ ->
            "potential-phone-numbers-info"



-- FORM


{-| Marks that we've trimmed the form's fields, so we don't accidentally send
it to the server without having trimmed it!
-}
type TrimmedForm
    = Trimmed Form


{-| When adding a variant here, add it to `fieldsToValidate` too!
-}
type ValidatedField
    = FirstName
    | MiddleName
    | LastName
    | Suffix


fieldsToValidate : List ValidatedField
fieldsToValidate =
    [ FirstName
    , LastName
    ]


{-| Trim the form and validate its fields. If there are problems, report them!
-}
validate : FormStatus -> Result (List Problem) TrimmedForm
validate formStatus =
    case formStatus of
        Initializing _ ->
            Err []

        Ready form ->
            let
                trimmedForm =
                    trimFields form
            in
            case List.concatMap (validateField trimmedForm) fieldsToValidate of
                [] ->
                    Ok trimmedForm

                problems ->
                    Err problems


isEmptyError text =
    if String.isEmpty text then
        []

    else
        []


isTooLongError text =
    if String.length text > 255 then
        []

    else
        []


validateOnString text =
    List.concat << List.map (\fn -> fn text)


validateField : TrimmedForm -> ValidatedField -> List Problem
validateField (Trimmed form) field =
    List.map (InvalidEntry field) <|
        case field of
            FirstName ->
                validateOnString form.firstName <| [ isTooLongError, isEmptyError ]

            MiddleName ->
                validateOnString form.middleName <| [ isTooLongError ]

            LastName ->
                validateOnString form.lastName <| [ isTooLongError, isEmptyError ]

            Suffix ->
                validateOnString form.suffix <| [ isTooLongError ]


{-| Don't trim while the user is typing! That would be super annoying.
Instead, trim only on submit.
-}
trimFields : Form -> TrimmedForm
trimFields form =
    Trimmed
        { form
            | firstName = String.trim form.firstName
            , lastName = String.trim form.lastName
        }


conditional fieldName fn field =
    Maybe.withDefault [] <| Maybe.map (\f -> [ ( fieldName, fn f ) ]) field


toBody body =
    Encode.object [ ( "data", body ) ]
        |> Http.jsonBody


updateDefendant : String -> Maybe Cred -> Model -> Defendant -> Cmd Msg
updateDefendant domain maybeCred model form =
    let
        defendant =
            Encode.object
                ([ ( "name", Encode.string form.name )
                 ]
                    ++ conditional "id" Encode.int model.id
                )
    in
    case model.id of
        Just id ->
            Rest.itemDecoder Defendant.decoder
                |> Rest.patch (Endpoint.defendant domain id) maybeCred (toBody defendant) CreatedDefendant

        Nothing ->
            Rest.post (Endpoint.defendants domain []) maybeCred (toBody defendant) CreatedDefendant (Rest.itemDecoder Defendant.decoder)


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


title =
    "RDC | Admin | Defendants | Edit"


head :
    StaticPayload Data RouteParams
    -> List Head.Tag
head static =
    Seo.summary
        { canonicalUrlOverride = Nothing
        , siteName = "Red Door Collective"
        , image = Logo.smallImage
        , description = "Edit defendant details"
        , locale = Just "en-us"
        , title = title
        }
        |> Seo.website
