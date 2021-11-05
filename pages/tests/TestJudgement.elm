module TestJudgement exposing (all)

import Expect
import Json.Decode as Decode
import Judgement exposing (Entrance(..), Judgement)
import Test exposing (..)
import Time


minimalJson =
    """
    {
        "awards_fees": null,
        "awards_possession": null,
        "court_date": null,
        "courtroom": null,
        "defendant_attorney": null,
        "detainer_warrant": {
          "docket_id": "21GC11668"
        },
        "dismissal_basis": null,
        "entered_by": "DEFAULT",
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


minimalJudgement : Judgement
minimalJudgement =
    { id = 123
    , courtDate = Nothing
    , courtroom = Nothing
    , enteredBy = Default
    , conditions = Nothing
    , notes = Nothing
    , plaintiff = Nothing
    , plaintiffAttorney = Nothing
    , judge = Nothing
    }


all : Test
all =
    describe "Creation"
        [ test "decodes with nulls" <|
            \() ->
                Expect.equal
                    (Result.Ok minimalJudgement)
                    (Decode.decodeString Judgement.decoder minimalJson)
        ]
