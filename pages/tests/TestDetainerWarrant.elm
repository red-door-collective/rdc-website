module TestDetainerWarrant exposing (..)

import DetainerWarrant exposing (AmountClaimedCategory(..), DetainerWarrant)
import Expect
import Json.Decode as Decode
import Test exposing (..)


minimalJson =
    """
    {
        "amount_claimed": null,
        "amount_claimed_category": "N/A",
        "created_at": 1633382326000,
        "defendants": [
          {
            "address": "SUPER FAKE ADDRESS",
            "aliases": [],
            "district_id": 1,
            "first_name": "HEATHER",
            "id": 456,
            "last_name": "UNIVERSE",
            "middle_name": "TRUCK",
            "name": "HEATHER TRUCK UNIVERSE",
            "potential_phones": null,
            "suffix": "",
            "verified_phone": null
          }
        ],
        "docket_id": "21GC11668",
        "file_date": null,
        "is_cares": null,
        "is_legacy": null,
        "judgements": [],
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
    , amountClaimedCategory = NotApplicable
    , judgements = []
    , defendants =
        [ { address = "SUPER FAKE ADDRESS"
          , aliases = []
          , firstName = "HEATHER"
          , id = 456
          , lastName = "UNIVERSE"
          , middleName = Just "TRUCK"
          , name = "HEATHER TRUCK UNIVERSE"
          , potentialPhones = Nothing
          , suffix = Just ""
          , verifiedPhone = Nothing
          }
        ]
    , fileDate = Nothing
    , isCares = Nothing
    , isLegacy = Nothing
    , nonpayment = Nothing
    , plaintiff = Nothing
    , plaintiffAttorney = Nothing
    , status = Nothing
    , notes = Nothing
    }


all : Test
all =
    describe "Creation"
        [ test "decodes" <|
            \() ->
                Expect.equal
                    (Result.Ok minimalDetainer)
                    (Decode.decodeString DetainerWarrant.decoder minimalJson)
        ]
