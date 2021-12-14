module TestDefendant exposing (all)

import Defendant exposing (Defendant)
import Expect
import Json.Decode as Decode
import Test exposing (..)


minimalJson =
    """
    {
        "aliases": [],
        "district_id": 1,
        "first_name": "HEATHER",
        "id": 123,
        "last_name": "UNIVERSE",
        "middle_name": "",
        "name": "HEATHER UNIVERSE",
        "potential_phones": null,
        "suffix": "",
        "verified_phone": null
    }
    """


minimalDefendant : Defendant
minimalDefendant =
    { id = 123
    , aliases = []
    , firstName = "HEATHER"
    , middleName = Just ""
    , lastName = "UNIVERSE"
    , suffix = Just ""
    , name = "HEATHER UNIVERSE"
    , potentialPhones = Nothing
    , verifiedPhone = Nothing
    }


maximumJson =
    """
    {
        "aliases": [ "TRUCKER" ],
        "district_id": 1,
        "first_name": "HEATHER",
        "id": 123,
        "last_name": "UNIVERSE",
        "middle_name": "TRUCK",
        "name": "HEATHER TRUCK UNIVERSE, JR",
        "potential_phones": "123-456-7890,987-012-3456",
        "suffix": "JR",
        "verified_phone": {
            "caller_name": "HEATHER UNIVERSE",
            "phone_type": "mobile",
            "national_format": "+1-(123)-456-7890"
        }
    }
    """


maximumDefendant : Defendant
maximumDefendant =
    { id = 123
    , aliases = [ "TRUCKER" ]
    , firstName = "HEATHER"
    , middleName = Just "TRUCK"
    , lastName = "UNIVERSE"
    , suffix = Just "JR"
    , name = "HEATHER TRUCK UNIVERSE, JR"
    , potentialPhones = Just "123-456-7890,987-012-3456"
    , verifiedPhone =
        Just
            { callerName = Just "HEATHER UNIVERSE"
            , phoneType = Just "mobile"
            , nationalFormat = "+1-(123)-456-7890"
            }
    }


all : Test
all =
    describe "Creation"
        [ test "decodes with nulls" <|
            \() ->
                Expect.equal
                    (Result.Ok minimalDefendant)
                    (Decode.decodeString Defendant.decoder minimalJson)
        , test "decodes with values" <|
            \() ->
                Expect.equal
                    (Result.Ok maximumDefendant)
                    (Decode.decodeString Defendant.decoder maximumJson)
        ]
