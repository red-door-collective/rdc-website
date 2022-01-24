module TestDetainerWarrant exposing (..)

import DetainerWarrant exposing (DetainerWarrant, Status(..))
import Expect
import Json.Decode as Decode
import PleadingDocument exposing (PleadingDocument)
import Test exposing (..)
import Time
import Url
import Url.Builder


minimalJson =
    """
    {
        "address": "123 Some Street, Nashville, TN 37010",
        "amount_claimed": null,
        "claims_possession": null,
        "created_at": 1633382326000,
        "docket_id": "21GC11668",
        "document": null,
        "file_date": null,
        "hearings": [],
        "is_cares": null,
        "is_legacy": null,
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
        "updated_at": 1634569282000
    }
    """


minimalDetainer : DetainerWarrant
minimalDetainer =
    { docketId = "21GC11668"
    , address = Just "123 Some Street, Nashville, TN 37010"
    , amountClaimed = Nothing
    , claimsPossession = Nothing
    , hearings = []
    , fileDate = Nothing
    , isCares = Nothing
    , isLegacy = Nothing
    , nonpayment = Nothing
    , plaintiff = Nothing
    , plaintiffAttorney = Nothing
    , status = Nothing
    , notes = Nothing
    , document = Nothing
    }


maximumJson =
    """
    {
        "address": "123 Some Street, Nashville, TN 37010",
        "amount_claimed": 123.45,
        "claims_possession": true,
        "created_at": 1633382326000,
        "docket_id": "21GT11668",
        "document": {
          "created_at": 1637071221000,
          "docket_id": "21GT1234",
          "kind": "DETAINER_WARRANT",
          "text": "COPY EFILED  07/20/21 07:28 AM  CASE NO. 21GT1234 ...",
          "updated_at": 1642214383000,
          "url": "https://caselinkimages.nashville.gov/PublicSessions/21/21GT1234/2197025.pdf"
        },
        "file_date": 1635901200000,
        "hearings": [],
        "is_cares": true,
        "is_legacy": false,
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
        "updated_at": 1634569282000
    }
    """


maximumDetainer : DetainerWarrant
maximumDetainer =
    { docketId = "21GT11668"
    , address = Just "123 Some Street, Nashville, TN 37010"
    , amountClaimed = Just 123.45
    , claimsPossession = Just True
    , fileDate = Just (Time.millisToPosix 1635901200000)
    , hearings = []
    , isCares = Just True
    , isLegacy = Just False
    , nonpayment = Just True
    , status = Just Pending
    , notes = Just "some notes"
    , plaintiff = Nothing
    , plaintiffAttorney = Nothing
    , document =
        Just
            { createdAt = Time.millisToPosix 1637071221000
            , kind = Just PleadingDocument.DetainerWarrantDocument
            , text = Just "COPY EFILED  07/20/21 07:28 AM  CASE NO. 21GT1234 ..."
            , updatedAt = Time.millisToPosix 1642214383000
            , url =
                { protocol = Url.Https
                , host = "caselinkimages.nashville.gov"
                , port_ = Nothing
                , path = "/PublicSessions/21/21GT1234/2197025.pdf"
                , query = Nothing
                , fragment = Nothing
                }
            }
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
