import unittest
from unittest import mock

from flask import Flask
from flask_sqlalchemy import SQLAlchemy
from flask_testing import TestCase
from rdc_website.app import create_app, db, DetainerWarrant
from rdc_website.admin.models import User, user_datastore
from rdc_website.detainer_warrants.models import Hearing, PleadingDocument, Judgment
from flask_security import hash_password, auth_token_required
import rdc_website.detainer_warrants.caselink.warrants as warrants
from datetime import datetime
from decimal import Decimal
import uuid


def mocked_login(*args, **kwargs):
    class MockResponse:
        def __init__(self, text, status_code):
            self.text = text
            self.status_code = status_code

        def text(self):
            return self.text

    if args[0] == "https://caselink.nashville.gov/cgi-bin/webshell.asp":
        with open("tests/fixtures/caselink/login-successful.html") as f:
            return MockResponse(f.read(), 200)

    return MockResponse(None, 404)


def date_as_str(d, format):
    return datetime.strptime(d, format).date()


class TestWarrants(TestCase):

    def create_app(self):
        app = create_app(self)
        app.config["TESTING"] = True
        app.config["SQLALCHEMY_DATABASE_URI"] = (
            "postgresql+psycopg2://rdc_website_test:junkdata@localhost:5432/rdc_website_test"
        )
        app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False
        return app

    # def setUp(self):
    #     db.create_all()
    #     roles = ['Superuser', 'Admin', 'Organizer', 'Defendant']
    #     for role in roles:
    #         user_datastore.find_or_create_role(role)
    #         db.session.commit()
    #     user_datastore.create_user(id=-1, email="system-user@reddoorcollective.org", first_name="System",
    #                                last_name="User", password=hash_password(str(uuid.uuid4())), roles=['Superuser'])
    #     db.session.commit()

    # def tearDown(self):
    #     db.session.remove()
    #     db.drop_all()

    def test_extract_search_response_data(self):
        search_results = None
        with open("tests/fixtures/caselink/search-results-page/index.html") as f:
            search_results = f.read()

        wc_values = warrants.extract_search_response_data(search_results)

        self.assertEqual(
            wc_values,
            [
                "Sessions",
                "24GT4773",
                "PENDING",
                "05/02/2024",
                "DETAINER WARRANT FORM",
                "MYKA GODWIN",
                "DEFENDANT A",
                ", PRS",
                "",
                "Sessions",
                "24GT4770",
                "PENDING",
                "05/01/2024",
                "DETAINER WARRANT",
                "PROGRESS RESIDENTIAL BORROWER 6, LLC 1408 CHUTNEY COURT",
                "DEFENDANT 1 OR ALL OTHER OCCUPANTS",
                "MCCOY, JENNIFER JO",
                "",
                "Sessions",
                "24GT4772",
                "PENDING",
                "05/01/2024",
                "DETAINER WARRANT",
                "WESTBORO APARTMENTS",
                "DEFENDANT 2",
                "RUSNAK, JOSEPH P.",
                "",
            ],
        )

    def test_build_cases_from_parsed_matches(self):
        search_results = None
        with open("tests/fixtures/caselink/search-results-page/index.html") as f:
            search_results = f.read()

        matches = warrants.extract_search_response_data(search_results)
        cases = warrants.build_cases_from_parsed_matches(matches)

        self.assertEqual(
            cases,
            [
                {
                    "Office": "Sessions",
                    "Docket #": "24GT4773",
                    "Status": "PENDING",
                    "File Date": "05/02/2024",
                    "Description": "DETAINER WARRANT FORM",
                    "Plaintiff": "MYKA GODWIN",
                    "Pltf. Attorney": "REPRESENTING SELF",
                    "Defendant": "DEFENDANT A",
                    "Def. Attorney": "",
                },
                {
                    "Office": "Sessions",
                    "Docket #": "24GT4770",
                    "Status": "PENDING",
                    "File Date": "05/01/2024",
                    "Description": "DETAINER WARRANT",
                    "Plaintiff": "PROGRESS RESIDENTIAL BORROWER 6, LLC 1408 CHUTNEY COURT",
                    "Pltf. Attorney": "MCCOY, JENNIFER JO",
                    "Defendant": "DEFENDANT 1 OR ALL OTHER OCCUPANTS",
                    "Def. Attorney": "",
                },
                {
                    "Office": "Sessions",
                    "Docket #": "24GT4772",
                    "Status": "PENDING",
                    "File Date": "05/01/2024",
                    "Description": "DETAINER WARRANT",
                    "Plaintiff": "WESTBORO APARTMENTS",
                    "Pltf. Attorney": "RUSNAK, JOSEPH P.",
                    "Defendant": "DEFENDANT 2",
                    "Def. Attorney": "",
                },
            ],
        )

    def test_extract_pleading_document_paths(self):
        pleading_documents = None
        with open("tests/fixtures/caselink/case-page/pleading-documents.html") as f:
            pleading_documents = f.read()

        paths = warrants.extract_pleading_document_paths(pleading_documents)

        self.assertEqual(
            paths,
            [
                "\\Public\\Sessions\\24\\24GT4890\\3370253.pdf",
                "\\Public\\Sessions\\24/24GT4890\\03370254.pdf",
            ],
        )


if __name__ == "__main__":
    unittest.main()
