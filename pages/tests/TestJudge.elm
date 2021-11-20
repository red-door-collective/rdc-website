module TestJudge exposing (all)

import Expect
import Json.Decode as Decode
import Judge exposing (Judge)
import Test exposing (..)


minimalJson =
    """
    {
        "id": 123,
        "name": "NAME SURNAME",
        "aliases": [],
        "district_id": 1
    }
    """


minimalJudge : Judge
minimalJudge =
    { id = 123
    , name = "NAME SURNAME"
    , aliases = []
    }


maximumJson =
    """
    {
        "id": 123,
        "name": "NAME SURNAME",
        "aliases": [ "UNNAME" ],
        "district_id": 1
    }
    """


maximumJudge : Judge
maximumJudge =
    { id = 123
    , name = "NAME SURNAME"
    , aliases = [ "UNNAME" ]
    }


all : Test
all =
    describe "Creation"
        [ test "decodes with nulls" <|
            \() ->
                Expect.equal
                    (Result.Ok minimalJudge)
                    (Decode.decodeString Judge.decoder minimalJson)
        , test "decodes with values" <|
            \() ->
                Expect.equal
                    (Result.Ok maximumJudge)
                    (Decode.decodeString Judge.decoder maximumJson)
        ]
