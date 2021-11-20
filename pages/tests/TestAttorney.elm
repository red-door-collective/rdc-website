module TestAttorney exposing (all)

import Attorney exposing (Attorney)
import Expect
import Json.Decode as Decode
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


minimalAttorney : Attorney
minimalAttorney =
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


maximumAttorney : Attorney
maximumAttorney =
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
                    (Result.Ok minimalAttorney)
                    (Decode.decodeString Attorney.decoder minimalJson)
        , test "decodes with values" <|
            \() ->
                Expect.equal
                    (Result.Ok maximumAttorney)
                    (Decode.decodeString Attorney.decoder maximumJson)
        ]
