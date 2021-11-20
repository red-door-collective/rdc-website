module TestPlaintiff exposing (all)

import Expect
import Json.Decode as Decode
import Plaintiff exposing (Plaintiff)
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


minimalPlaintiff : Plaintiff
minimalPlaintiff =
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


maximumPlaintiff : Plaintiff
maximumPlaintiff =
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
                    (Result.Ok minimalPlaintiff)
                    (Decode.decodeString Plaintiff.decoder minimalJson)
        , test "decodes with values" <|
            \() ->
                Expect.equal
                    (Result.Ok maximumPlaintiff)
                    (Decode.decodeString Plaintiff.decoder maximumJson)
        ]
