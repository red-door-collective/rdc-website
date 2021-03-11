module Main exposing (main)

import Browser
import DateTime
import Element exposing (Element, fill)
import Element.Input
import Html exposing (Html)
import Http
import Json.Decode as Decode exposing (Decoder, Value, bool, int, list, nullable, string)
import Json.Decode.Pipeline exposing (optional, required)
import LineChart
import LineChart.Axis as Axis
import Time


type Status
    = Closed
    | Pending


type AmountClaimedCategory
    = Possession
    | Fees
    | Both
    | NotApplicable


type alias Defendant =
    { name : String, phone : String, address : String }


type alias Judge =
    { name : String }


type alias Attorney =
    { name : String }


type alias Plantiff =
    { name : String, attorney : Attorney }


type alias Courtroom =
    { name : String }


type alias DetainerWarrant =
    { docketId : String
    , fileDate : String
    , status : Status
    , plantiff : Plantiff
    , courtDate : Maybe String
    , courtroom : Maybe Courtroom
    , presidingJudge : Maybe Judge
    , amountClaimed : Maybe String
    , amountClaimedCategory : AmountClaimedCategory
    , defendants : List Defendant
    }


statusDecoder : Decoder Status
statusDecoder =
    Decode.string
        |> Decode.andThen
            (\str ->
                case str of
                    "CLOSED" ->
                        Decode.succeed Closed

                    "PENDING" ->
                        Decode.succeed Pending

                    somethingElse ->
                        Decode.fail <| "Unknown status:" ++ somethingElse
            )


amountClaimedCategoryDecoder : Decoder AmountClaimedCategory
amountClaimedCategoryDecoder =
    Decode.string
        |> Decode.andThen
            (\str ->
                case str of
                    "POSS" ->
                        Decode.succeed Possession

                    "FEES" ->
                        Decode.succeed Fees

                    "BOTH" ->
                        Decode.succeed Both

                    "N/A" ->
                        Decode.succeed NotApplicable

                    somethingElse ->
                        Decode.fail <| "Unknown amount claimed category:" ++ somethingElse
            )


attorneyDecoder : Decoder Attorney
attorneyDecoder =
    Decode.succeed Attorney
        |> required "name" string


courtroomDecoder : Decoder Courtroom
courtroomDecoder =
    Decode.succeed Courtroom
        |> required "name" string


judgeDecoder : Decoder Judge
judgeDecoder =
    Decode.succeed Judge
        |> required "name" string


plantiffDecoder : Decoder Plantiff
plantiffDecoder =
    Decode.succeed Plantiff
        |> required "name" string
        |> required "attorney" attorneyDecoder


defendantDecoder : Decoder Defendant
defendantDecoder =
    Decode.succeed Defendant
        |> required "name" string
        |> optional "phone" string "not provided"
        |> required "address" string


detainerWarrantDecoder : Decoder DetainerWarrant
detainerWarrantDecoder =
    Decode.succeed DetainerWarrant
        |> required "docket_id" string
        |> required "file_date" string
        |> required "status" statusDecoder
        |> required "plantiff" plantiffDecoder
        |> required "court_date" (nullable string)
        |> required "courtroom" (nullable courtroomDecoder)
        |> required "presiding_judge" (nullable judgeDecoder)
        |> required "amount_claimed" (nullable string)
        |> required "amount_claimed_category" amountClaimedCategoryDecoder
        |> required "defendants" (list defendantDecoder)


apiMetaDecoder : Decoder ApiMeta
apiMetaDecoder =
    Decode.succeed ApiMeta
        |> required "after_cursor" (nullable string)
        |> required "has_next_page" bool


detainerWarrantApiDecoder : Decoder (ApiPage DetainerWarrant)
detainerWarrantApiDecoder =
    Decode.succeed ApiPage
        |> required "data" (list detainerWarrantDecoder)
        |> required "meta" apiMetaDecoder


type alias Model =
    { warrants : List DetainerWarrant
    , query : String
    , warrantsCursor : Maybe String
    }


type alias ApiMeta =
    { afterCursor : Maybe String
    , hasNextPage : Bool
    }


type alias ApiPage data =
    { data : List data
    , meta : ApiMeta
    }


type Page
    = Welcome Model


init : Value -> ( Page, Cmd Msg )
init _ =
    ( Welcome
        { warrants = []
        , query = ""
        , warrantsCursor = Nothing
        }
    , Cmd.none
    )


type Msg
    = SearchWarrants
    | InputQuery String
    | GotWarrants (Result Http.Error (ApiPage DetainerWarrant))


getWarrants : String -> Cmd Msg
getWarrants query =
    Http.get
        { url = "/api/v1/detainer-warrants/?defendant_name=" ++ query
        , expect = Http.expectJson GotWarrants detainerWarrantApiDecoder
        }


update : Msg -> Page -> ( Page, Cmd Msg )
update msg page =
    case page of
        Welcome model ->
            case msg of
                InputQuery query ->
                    ( Welcome { model | query = query }, Cmd.none )

                SearchWarrants ->
                    ( Welcome model, getWarrants model.query )

                GotWarrants result ->
                    case result of
                        Ok detainerWarrantsPage ->
                            ( Welcome { model | warrants = detainerWarrantsPage.data, warrantsCursor = detainerWarrantsPage.meta.afterCursor }, Cmd.none )

                        Err errMsg ->
                            ( Welcome model, Cmd.none )



-- VIEW


viewPage : Page -> Browser.Document Msg
viewPage page =
    case page of
        Welcome model ->
            { title = "Welcome", body = [ viewWarrantsPage model ] }


viewDefendant : Defendant -> Element Msg
viewDefendant defendant =
    Element.row [] [ Element.text (defendant.name ++ " " ++ defendant.phone ++ " " ++ defendant.address) ]


viewDefendants : DetainerWarrant -> Element Msg
viewDefendants warrant =
    Element.column []
        (List.map viewDefendant warrant.defendants)


viewWarrants : Model -> Element Msg
viewWarrants model =
    Element.table [ Element.padding 10 ]
        { data = List.filter (\warrant -> List.any (\defendant -> String.contains (String.toUpper model.query) (String.toUpper defendant.name)) warrant.defendants) model.warrants
        , columns =
            [ { header = Element.text "Docket Id"
              , width = fill
              , view =
                    \warrant ->
                        Element.text warrant.docketId
              }
            , { header = Element.text "File Date"
              , width = fill
              , view =
                    \warrant ->
                        Element.text warrant.fileDate
              }
            , { header = Element.text "Plantiff Name"
              , width = fill
              , view =
                    \warrant ->
                        Element.text warrant.plantiff.name
              }
            , { header = Element.text "Defendants"
              , width = fill
              , view = viewDefendants
              }
            ]
        }


viewWarrantsPage : Model -> Html Msg
viewWarrantsPage model =
    Element.layout []
        (Element.column [ Element.width (Element.px 600), Element.centerX, Element.centerY ]
            [ Element.row [] [ Element.text "Find your Detainer Warrant case" ]
            , Element.Input.text [] { onChange = InputQuery, text = model.query, placeholder = Nothing, label = Element.Input.labelAbove [] (Element.text "Search your name") }
            , Element.Input.button [] { onPress = Just SearchWarrants, label = Element.text "Search" }
            , Element.row []
                [ viewWarrants model ]
            ]
        )


subscriptions : Page -> Sub Msg
subscriptions page =
    case page of
        Welcome _ ->
            Sub.none


main : Program Value Page Msg
main =
    Browser.document
        { init = init
        , view = viewPage
        , update = update
        , subscriptions = subscriptions
        }
