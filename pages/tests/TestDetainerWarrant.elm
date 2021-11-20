module TestDetainerWarrant exposing (..)

import DetainerWarrant exposing (DetainerWarrant, Status(..))
import Expect
import Json.Decode as Decode
import Test exposing (..)
import Time


minimalJson =
    """
    {
        "amount_claimed": null,
        "claims_possession": null,
        "created_at": 1633382326000,
        "defendants": [],
        "docket_id": "21GC11668",
        "file_date": null,
        "is_cares": null,
        "is_legacy": null,
        "judgments": [],
        "pleadings": [],
        "last_edited_by": {
          "active": true,
          "first_name": "System",
          "id": -1,
          "last_name": "User",
          "name": "System User",
          "preferred_navigation": "REMAIN",
          "roles": [
            {
              "description": "A user with complete access to all resources.",
              "id": 1,
              "name": "Superuser"
            }
          ]
        },
        "nonpayment": null,
        "notes": null,
        "order_number": 21011668,
        "plaintiff": null,
        "plaintiff_attorney": null,
        "status": null,
        "updated_at": 1634569282000,
        "zip_code": null
    }
    """


minimalDetainer : DetainerWarrant
minimalDetainer =
    { docketId = "21GC11668"
    , amountClaimed = Nothing
    , claimsPossession = Nothing
    , judgments = []
    , pleadings = []
    , defendants = []
    , fileDate = Nothing
    , isCares = Nothing
    , isLegacy = Nothing
    , nonpayment = Nothing
    , plaintiff = Nothing
    , plaintiffAttorney = Nothing
    , status = Nothing
    , notes = Nothing
    }


maximumJson =
    """
    {
        "amount_claimed": 123.45,
        "claims_possession": true,
        "created_at": 1633382326000,
        "defendants": [],
        "docket_id": "21GT11668",
        "file_date": 1635901200000,
        "is_cares": true,
        "is_legacy": false,
        "judgments": [],
        "pleadings": [],
        "last_edited_by": {
          "active": true,
          "first_name": "System",
          "id": -1,
          "last_name": "User",
          "name": "System User",
          "preferred_navigation": "REMAIN",
          "roles": [
            {
              "description": "A user with complete access to all resources.",
              "id": 1,
              "name": "Superuser"
            }
          ]
        },
        "nonpayment": true,
        "notes": "some notes",
        "order_number": 21011668,
        "plaintiff": null,
        "plaintiff_attorney": null,
        "status": "PENDING",
        "updated_at": 1634569282000,
        "zip_code": null
    }
    """


maximumDetainer : DetainerWarrant
maximumDetainer =
    { docketId = "21GT11668"
    , amountClaimed = Just 123.45
    , claimsPossession = Just True
    , fileDate = Just (Time.millisToPosix 1635901200000)
    , isCares = Just True
    , isLegacy = Just False
    , nonpayment = Just True
    , status = Just Pending
    , notes = Just "some notes"
    , plaintiff = Nothing
    , plaintiffAttorney = Nothing
    , judgments = []
    , pleadings = []
    , defendants = []
    }


all : Test
all =
    describe "Creation"
        [ test "decodes with nulls" <|
            \() ->
                Expect.equal
                    (Result.Ok minimalDetainer)
                    (Decode.decodeString DetainerWarrant.decoder minimalJson)
        , test "decodes with all values" <|
            \() ->
                Expect.equal
                    (Result.Ok maximumDetainer)
                    (Decode.decodeString DetainerWarrant.decoder maximumJson)
        ]
