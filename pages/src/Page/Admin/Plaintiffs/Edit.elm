module Page.Admin.Plaintiffs.Edit exposing (Data, Model, Msg, page)

import Api.Endpoint as Endpoint
import Browser.Dom
import Browser.Events exposing (onMouseDown)
import Browser.Navigation as Nav
import Campaign exposing (Campaign)
import Color
import DataSource exposing (DataSource)
import Date exposing (Date)
import DateFormat
import DatePicker exposing (ChangeEvent(..))
import Defendant exposing (Defendant)
import Dict
import Dropdown
import Element exposing (Element, below, centerX, column, el, fill, focusStyle, height, image, inFront, link, maximum, minimum, padding, paddingXY, paragraph, px, row, shrink, spacing, spacingXY, text, textColumn, width, wrappedRow)
import Element.Background as Background
import Element.Border as Border
import Element.Events as Events
import Element.Font as Font
import Element.Input as Input exposing (labelHidden)
import FeatherIcons
import Head
import Head.Seo as Seo
import Html.Attributes
import Html.Events
import Http
import Json.Decode as Decode
import Json.Encode as Encode
import List.Extra as List
import Log
import Mask
import Maybe.Extra
import MultiInput
import Page exposing (Page, PageWithState, StaticPayload)
import Pages.PageUrl exposing (PageUrl)
import Pages.Url
import Palette
import Path exposing (Path)
import PhoneNumber
import PhoneNumber.Countries exposing (countryUS)
import Plaintiff exposing (Plaintiff)
import QueryParams
import Regex exposing (Regex)
import Rest exposing (Cred)
import Rollbar exposing (Rollbar)
import Route
import Runtime exposing (Runtime)
import SearchBox
import Session exposing (Session)
import Set
import Settings exposing (Settings)
import Shared
import Task
import Url.Builder
import User exposing (User)
import View exposing (View)
import Widget
import Widget.Customize as Customize
import Widget.Icon exposing (Icon)
import Widget.Material as Material


type alias FormOptions =
    { tooltip : Maybe Tooltip
    , problems : List Problem
    , originalPlaintiff : Maybe Plaintiff
    }


type alias Form =
    { name : String
    , displayName : String
    , aliases : List String
    , aliasesState : MultiInput.State
    , notes : String
    }


type Problem
    = InvalidEntry ValidatedField String
    | ServerError String


type Tooltip
    = PlaintiffInfo
    | NameInfo
    | AliasesInfo
    | NotesInfo


type SaveState
    = SavingPlaintiff
    | Done


type alias Model =
    { id : Maybe Int
    , plaintiff : Maybe Plaintiff
    , tooltip : Maybe Tooltip
    , problems : List Problem
    , form : FormStatus
    , saveState : SaveState
    , newFormOnSuccess : Bool
    }


aliasesId =
    "aliases-input"


editForm : Plaintiff -> Form
editForm plaintiff =
    { name = plaintiff.name
    , displayName = ""
    , aliases = plaintiff.aliases
    , aliasesState = MultiInput.init aliasesId
    , notes = ""
    }


initCreate : Form
initCreate =
    { name = ""
    , displayName = ""
    , aliases = []
    , aliasesState = MultiInput.init aliasesId
    , notes = ""
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
    ( { plaintiff = Nothing
      , id = maybeId
      , tooltip = Nothing
      , problems = []
      , form =
            case maybeId of
                Just id ->
                    Initializing id

                Nothing ->
                    Ready initCreate
      , saveState = Done
      , newFormOnSuccess = False
      }
    , case maybeId of
        Just id ->
            getPlaintiff domain id maybeCred

        Nothing ->
            Cmd.none
    )


getPlaintiff : String -> Int -> Maybe Cred -> Cmd Msg
getPlaintiff domain id maybeCred =
    Rest.get (Endpoint.plaintiff domain id) maybeCred GotPlaintiff (Rest.itemDecoder Plaintiff.decoder)


type Msg
    = GotPlaintiff (Result Http.Error (Rest.Item Plaintiff))
    | ChangeTooltip Tooltip
    | CloseTooltip
    | ChangedName String
    | ChangedAliases MultiInput.Msg
    | ChangedNotes String
    | SubmitForm
    | SubmitAndAddAnother
    | CreatedPlaintiff (Result Http.Error (Rest.Item Plaintiff))
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


updateFormOnly : (Form -> Form) -> Model -> Model
updateFormOnly transform model =
    { model
        | form =
            case model.form of
                Initializing _ ->
                    model.form

                Ready oldForm ->
                    Ready (transform oldForm)
    }


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
            [ ServerError "Error saving plaintiff" ]
    in
    { model | problems = problems }


defaultSeparators : List String
defaultSeparators =
    [ "\n", "\t" ]


multiInputUpdateConfig =
    { separators = defaultSeparators }


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

        maybeCred =
            Session.cred session

        rollbar =
            Log.reporting static.sharedData.runtime

        domain =
            Runtime.domain static.sharedData.runtime.environment

        logHttpError =
            error rollbar << Log.httpErrorMessage
    in
    case msg of
        GotPlaintiff result ->
            case result of
                Ok plaintiffPage ->
                    ( { model
                        | plaintiff = Just plaintiffPage.data
                        , form = Ready (editForm plaintiffPage.data)
                      }
                    , Cmd.none
                    )

                Err httpError ->
                    ( model, logHttpError httpError )

        ChangeTooltip selection ->
            ( { model
                | tooltip =
                    if Just selection == model.tooltip then
                        Nothing

                    else
                        Just selection
              }
            , Cmd.none
            )

        CloseTooltip ->
            ( { model | tooltip = Nothing }, Cmd.none )

        ChangedName name ->
            updateForm (\form -> { form | name = name }) model

        ChangedAliases multiMsg ->
            updateFormNarrow
                (\form ->
                    let
                        ( nextState, nextItems, nextCmd ) =
                            MultiInput.update multiInputUpdateConfig multiMsg form.aliasesState form.aliases
                    in
                    ( { form | aliases = nextItems, aliasesState = nextState }, Cmd.map ChangedAliases nextCmd )
                )
                model

        ChangedNotes notes ->
            updateForm
                (\form -> { form | notes = notes })
                model

        SubmitForm ->
            submitForm domain session model

        SubmitAndAddAnother ->
            submitFormAndAddAnother domain session model

        CreatedPlaintiff (Ok plaintiffItem) ->
            nextStepSave
                session
                { model
                    | plaintiff = Just plaintiffItem.data
                }

        CreatedPlaintiff (Err httpError) ->
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
                plaintiff =
                    toPlaintiff model.id validForm
            in
            ( { model
                | newFormOnSuccess = False
                , problems = []
                , saveState = SavingPlaintiff
              }
            , updatePlaintiff domain maybeCred model plaintiff
            )

        Err problems ->
            ( { model | newFormOnSuccess = False, problems = problems }
            , Cmd.none
            )


toPlaintiff : Maybe Int -> TrimmedForm -> Plaintiff
toPlaintiff id (Trimmed form) =
    { id = Maybe.withDefault -1 id
    , name = form.name
    , aliases = form.aliases
    }


nextStepSave : Session -> Model -> ( Model, Cmd Msg )
nextStepSave session model =
    let
        maybeCred =
            Session.cred session
    in
    case validate model.form of
        Ok form ->
            let
                plaintiff =
                    toPlaintiff model.id form
            in
            case model.saveState of
                SavingPlaintiff ->
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
                            Maybe.map (\key -> Nav.replaceUrl key (Url.Builder.relative [ String.fromInt plaintiff.id ] [])) (Session.navKey session)
                    )

        Err _ ->
            ( model, Cmd.none )


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


palette : Material.Palette
palette =
    { primary = Color.rgb255 236 31 39
    , secondary = Color.rgb255 216 27 96
    , background = Color.rgb255 255 255 255
    , surface = Color.rgb255 255 255 255
    , error = Color.rgb255 156 39 176
    , on =
        { primary = Color.rgb255 255 255 255
        , secondary = Color.rgb255 0 0 0
        , background = Color.rgb255 0 0 0
        , surface = Color.rgb255 0 0 0
        , error = Color.rgb255 255 255 255
        }
    }


focusedButtonStyles : List (Element.Attr decorative msg)
focusedButtonStyles =
    [ Background.color Palette.sred, Font.color Palette.white ]


hoveredButtonStyles : List (Element.Attr decorative msg)
hoveredButtonStyles =
    [ Background.color Palette.sred, Font.color Palette.white ]


helpButton : Tooltip -> Element Msg
helpButton tooltip =
    Input.button
        [ Events.onLoseFocus CloseTooltip
        , Font.color Palette.sred
        , padding 10
        , Element.alignBottom
        , Border.rounded 3
        , Element.mouseOver hoveredButtonStyles
        , Element.focused focusedButtonStyles
        ]
        { label =
            Element.html
                (FeatherIcons.helpCircle
                    |> FeatherIcons.toHtml []
                )
        , onPress = Just (ChangeTooltip tooltip)
        }


type alias Field =
    { tooltip : Maybe Tooltip
    , description : List (Element Msg)
    , children : List (Element Msg)
    , currentTooltip : Maybe Tooltip
    }


requiredStar =
    el [ Font.color Palette.sred, Element.alignTop, width Element.shrink ] (text "*")


viewField : Field -> Element Msg
viewField field =
    let
        help =
            Maybe.withDefault Element.none <| Maybe.map helpButton field.tooltip

        tooltip =
            case field.tooltip of
                Just tip ->
                    withTooltip tip field.currentTooltip field.description

                Nothing ->
                    []
    in
    row
        ([ width fill, height fill, spacingXY 5 0, paddingXY 0 10 ] ++ tooltip)
        (help :: field.children)


withChanges hasChanged attrs =
    attrs
        ++ (if hasChanged then
                [ Border.color Palette.purpleLight ]

            else
                []
           )


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
                    [ Border.color Palette.sred
                    , Element.below
                        (row [ paddingXY 0 10, spacing 5, Font.color Palette.sred, Font.size 14 ]
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
    Input.text ([ Border.color Palette.grayLight ] ++ attrs) config


requiredLabel labelFn str =
    labelFn [] (row [ spacing 5 ] [ text str, requiredStar ])


viewName : FormOptions -> Form -> Element Msg
viewName options form =
    column [ width (fill |> minimum 600), height fill, paddingXY 0 10 ]
        [ viewField
            { tooltip = Just NameInfo
            , description = [ paragraph [] [ text "This name is how we uniquely identify a Plaintiff." ] ]
            , currentTooltip = options.tooltip
            , children =
                [ textInput
                    (withValidation Name options.problems [ Input.focusedOnLoad ])
                    { onChange = ChangedName
                    , text = form.name
                    , placeholder = Nothing
                    , label = requiredLabel Input.labelAbove "Name"
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


viewAliases : FormOptions -> Form -> Element Msg
viewAliases options form =
    column [ width (fill |> minimum 600), height fill, paddingXY 0 10 ]
        [ viewField
            { tooltip = Just AliasesInfo
            , description =
                [ paragraph []
                    [ text "These are other names that are used to refer to the same plaintiff." ]
                , paragraph [] [ text "Tip: press tab or enter to add another alias." ]
                ]
            , currentTooltip = options.tooltip
            , children =
                [ column [ width fill, spacing 2 ]
                    [ paragraph [] [ text "Aliases" ]
                    , MultiInput.view
                        -- (withValidation Aliases options.problems [ Input.focusedOnLoad ])
                        { toOuterMsg = ChangedAliases
                        , placeholder = "Enter alias here"
                        , isValid = matches "^[a-z0-9]+(?:-[a-z0-9]+)*$"
                        }
                        []
                        form.aliases
                        form.aliasesState
                    ]
                ]
            }
        ]


viewNotes : FormOptions -> Form -> Element Msg
viewNotes options form =
    -- let
    --     hasChanges =
    --         (Maybe.withDefault False <|
    --             Maybe.map ((/=) form.notes) <|
    --                 Maybe.andThen .notes options.originalPlaintiff
    --         )
    --             || (options.originalPlaintiff == Nothing && form.notes /= "")
    -- in
    column [ width fill ]
        [ viewField
            { tooltip = Just NotesInfo
            , currentTooltip = options.tooltip
            , description =
                [ paragraph []
                    [ text "Any additional notes you have about this case go here!"
                    , text "This is a great place to leave feedback for the form as well, perhaps there's another field or field option we need to provide."
                    ]
                ]
            , children =
                [ Input.multiline (withChanges False [])
                    { onChange = ChangedNotes
                    , text = form.notes
                    , label = Input.labelAbove [] (text "Notes")
                    , placeholder = Just <| Input.placeholder [] (text "Add anything you think is noteworthy.")
                    , spellcheck = True
                    }
                ]
            }
        ]


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
        , Border.color Palette.grayLight
        , Border.width 1
        , Border.shadow { offset = ( 0, 10 ), size = 1, blur = 30, color = Palette.grayLight }
        ]
        groups


primaryStyles : List (Element.Attr () msg)
primaryStyles =
    [ Background.color Palette.sred
    , Font.color Palette.white
    , Font.size 20
    , padding 10
    , Border.rounded 3
    ]


submitAndAddAnother : Element Msg
submitAndAddAnother =
    Input.button
        [ Background.color Palette.redLightest
        , Font.color Palette.sred
        , padding 10
        , Border.rounded 3
        , Border.width 1
        , Border.color Palette.sred
        , Font.size 22
        ]
        { onPress = Just SubmitAndAddAnother, label = text "Submit and add another" }


submitButton : Element Msg
submitButton =
    Input.button
        (primaryStyles ++ [ Font.size 22 ])
        { onPress = Just SubmitForm, label = text "Submit" }


viewForm : FormOptions -> FormStatus -> Element Msg
viewForm options formStatus =
    case formStatus of
        Initializing id ->
            column [] [ text ("Fetching plaintiff " ++ String.fromInt id) ]

        Ready form ->
            column [ centerX, spacing 30, width (fill |> maximum 1200) ]
                [ tile
                    [ paragraph [ Font.center, centerX ] [ text "Plaintiff" ]
                    , formGroup
                        [ viewName options form
                        ]
                    , formGroup
                        [ viewAliases options form
                        ]
                    ]
                , row [ Element.alignRight, spacing 10 ]
                    [ submitAndAddAnother
                    , submitButton
                    ]
                ]


formOptions : Model -> FormOptions
formOptions model =
    { tooltip = model.tooltip
    , problems = model.problems
    , originalPlaintiff = model.plaintiff
    }


viewProblem : Problem -> Element Msg
viewProblem problem =
    paragraph []
        [ case problem of
            InvalidEntry _ value ->
                Element.none

            ServerError err ->
                text ("Something went wrong: " ++ err)
        ]


viewProblems : List Problem -> Element Msg
viewProblems problems =
    row [] [ column [] (List.map viewProblem problems) ]


viewTooltip : List (Element Msg) -> Element Msg
viewTooltip content =
    textColumn
        [ width (fill |> maximum 600)
        , padding 10
        , Background.color Palette.red
        , Font.color Palette.white
        , Border.rounded 3
        , Font.size 14
        , Border.shadow
            { offset = ( 0, 3 ), blur = 6, size = 0, color = Element.rgba 0 0 0 0.32 }
        ]
        content


withTooltip : Tooltip -> Maybe Tooltip -> List (Element Msg) -> List (Element.Attribute Msg)
withTooltip candidate active content =
    if Just candidate == active then
        [ below (viewTooltip content) ]

    else
        []


view :
    Maybe PageUrl
    -> Shared.Model
    -> Model
    -> StaticPayload Data RouteParams
    -> View Msg
view maybeUrl sharedModel model static =
    { title = "Organize - Plaintiff - Edit"
    , body =
        [ row
            [ centerX
            , padding 20
            , Font.size 20
            , width (fill |> maximum 1200 |> minimum 400)
            , Element.inFront
                (Input.button
                    (primaryStyles
                        ++ [ Font.size 14
                           , Element.alignRight
                           , Element.alignTop
                           , Events.onLoseFocus CloseTooltip
                           ]
                        ++ withTooltip PlaintiffInfo model.tooltip [ paragraph [] [ text "The person sueing a tenant for possession or fees." ] ]
                    )
                    { onPress = Just (ChangeTooltip PlaintiffInfo)
                    , label = text "What is a Plaintiff?"
                    }
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
                                    ++ " Plaintiff"
                                )
                            ]
                        ]
                    ]
                , viewProblems model.problems
                , row [ width fill ]
                    [ viewForm (formOptions model) model.form
                    ]
                ]
            ]
        ]
    }


subscriptions : Maybe PageUrl -> RouteParams -> Path -> Model -> Sub Msg
subscriptions pageUrl params path model =
    case model.form of
        Initializing _ ->
            Sub.none

        Ready form ->
            Sub.batch
                (List.concat
                    [ [ MultiInput.subscriptions form.aliasesState
                            |> Sub.map ChangedAliases
                      ]
                    , Maybe.withDefault [] (Maybe.map (List.singleton << onOutsideClick) model.tooltip)
                    ]
                )


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


onOutsideClick : Tooltip -> Sub Msg
onOutsideClick tip =
    onMouseDown (outsideTarget (tooltipToString tip) CloseTooltip)


tooltipToString : Tooltip -> String
tooltipToString tip =
    case tip of
        PlaintiffInfo ->
            "plaintiff-info"

        NameInfo ->
            "name-info"

        AliasesInfo ->
            "aliases-info"

        NotesInfo ->
            "notes-info"



-- FORM


{-| Marks that we've trimmed the form's fields, so we don't accidentally send
it to the server without having trimmed it!
-}
type TrimmedForm
    = Trimmed Form


{-| When adding a variant here, add it to `fieldsToValidate` too!
-}
type ValidatedField
    = Name
    | Aliases


fieldsToValidate : List ValidatedField
fieldsToValidate =
    [ Name
    , Aliases
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


validateField : TrimmedForm -> ValidatedField -> List Problem
validateField (Trimmed form) field =
    List.map (InvalidEntry field) <|
        case field of
            Name ->
                if String.isEmpty form.name then
                    []

                else
                    []

            Aliases ->
                if String.isEmpty form.name then
                    []

                else
                    []


{-| Don't trim while the user is typing! That would be super annoying.
Instead, trim only on submit.
-}
trimFields : Form -> TrimmedForm
trimFields form =
    Trimmed
        { form
            | name = String.trim form.name
            , aliases = List.map String.trim form.aliases
            , notes = String.trim form.notes
        }


conditional fieldName fn field =
    Maybe.withDefault [] <| Maybe.map (\f -> [ ( fieldName, fn f ) ]) field


nullable fieldName fn field =
    Maybe.withDefault [ ( fieldName, Encode.null ) ] <| Maybe.map (\f -> [ ( fieldName, fn f ) ]) field


toBody body =
    Encode.object [ ( "data", body ) ]
        |> Http.jsonBody


remoteId : { a | id : number } -> Maybe number
remoteId resource =
    if resource.id == -1 then
        Nothing

    else
        Just resource.id


defaultDistrict =
    ( "district_id", Encode.int 1 )


encodeRelated record =
    Encode.object [ ( "id", Encode.int record.id ) ]


updatePlaintiff : String -> Maybe Cred -> Model -> Plaintiff -> Cmd Msg
updatePlaintiff domain maybeCred model form =
    let
        plaintiff =
            Encode.object
                ([ ( "name", Encode.string form.name )
                 , ( "aliases", Encode.list Encode.string form.aliases )
                 ]
                    ++ conditional "id" Encode.int model.id
                 -- ++ nullable "notes" Encode.string form.notes
                )
    in
    case model.id of
        Just id ->
            Rest.itemDecoder Plaintiff.decoder
                |> Rest.patch (Endpoint.plaintiff domain id) maybeCred (toBody plaintiff) CreatedPlaintiff

        Nothing ->
            Rest.post (Endpoint.plaintiffs domain []) maybeCred (toBody plaintiff) CreatedPlaintiff (Rest.itemDecoder Plaintiff.decoder)


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
        , siteName = "elm-pages"
        , image =
            { url = Pages.Url.external "TODO"
            , alt = "elm-pages logo"
            , dimensions = Nothing
            , mimeType = Nothing
            }
        , description = "TODO"
        , locale = Nothing
        , title = "TODO title" -- metadata.title -- TODO
        }
        |> Seo.website