module TestJudgment exposing (all)

import Courtroom exposing (Courtroom)
import Expect
import Hearing exposing (Hearing)
import Json.Decode as Decode
import Judgment exposing (Entrance(..), Judgment)
import PleadingDocument exposing (Kind(..), PleadingDocument)
import Test exposing (..)
import Time
import Url


minimalJson =
    """
    {
        "awards_fees": null,
        "awards_possession": null,
        "court_date": null,
        "courtroom": null,
        "defendant_attorney": null,
        "detainer_warrant_id": "21GT1234",
        "dismissal_basis": null,
        "document": {
            "created_at": 1637406086000,
            "docket_id": "21GT1234",
            "kind": "JUDGMENT",
            "text": "COPY\\nEFILED  08/04/21 09:31 AM  CASE NO. 21GT1234 ...",
            "updated_at": 1637406128000,
            "url": "https://caselinkimages.nashville.gov/PublicSessions/21/21GT1234/12341234.pdf"
        },
        "entered_by": "DEFAULT",
        "file_date": 1628053200000,
        "hearing": {
            "address": "1234 Example St, Nashville 37206",
            "court_date": 1627966800000,
            "courtroom": {
                "id": 2,
                "name": "1B"
            },
            "defendant_attorney": null,
            "defendants": [],
            "docket_id": "21GT1234",
            "id": 12345,
            "judgment": {
                "id": 123
            },
            "plaintiff": null,
            "plaintiff_attorney": null
        },
        "id": 123,
        "in_favor_of": null,
        "interest": null,
        "interest_follows_site": null,
        "interest_rate": null,
        "judge": null,
        "notes": null,
        "plaintiff": null,
        "plaintiff_attorney": null,
        "with_prejudice": null
    }
    """


minimalCourtroom : Courtroom
minimalCourtroom =
    { id = 2
    , name = "1B"
    }


minimalHearing : Hearing
minimalHearing =
    { id = 12345
    , courtDate = Time.millisToPosix 1627966800000
    , courtroom = Just minimalCourtroom
    , plaintiff = Nothing
    , plaintiffAttorney = Nothing
    , defendantAttorney = Nothing
    , judgment = Just { id = 123 }
    }


minimalDocument : PleadingDocument
minimalDocument =
    { createdAt = Time.millisToPosix 1637406086000
    , kind = Just JudgmentDocument
    , text = Just "COPY\nEFILED  08/04/21 09:31 AM  CASE NO. 21GT1234 ..."
    , updatedAt = Time.millisToPosix 1637406128000
    , url =
        { protocol = Url.Https
        , host = "caselinkimages.nashville.gov"
        , port_ = Nothing
        , path = "/PublicSessions/21/21GT1234/12341234.pdf"
        , query = Nothing
        , fragment = Nothing
        }
    }


minimalJudgment : Judgment
minimalJudgment =
    { id = 123
    , docketId = "21GT1234"
    , fileDate = Just <| Time.millisToPosix 1628053200000
    , enteredBy = Default
    , conditions = Nothing
    , notes = Nothing
    , plaintiff = Nothing
    , plaintiffAttorney = Nothing
    , judge = Nothing
    , hearing = minimalHearing
    , document = Just minimalDocument
    }


all : Test
all =
    describe "Creation"
        [ test "decodes with nulls" <|
            \() ->
                Expect.equal
                    (Result.Ok minimalJudgment)
                    (Decode.decodeString Judgment.decoder minimalJson)
        ]
