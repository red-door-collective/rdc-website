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
        with open("tests/fixtures/caselink/search-results.html") as f:
            search_results = f.read()

        wc_vars, wc_values = warrants.extract_search_response_data(search_results)

        breakpoint()
        self.assertEqual(
            wc_vars,
            "P_101_1%7FP_102_1%7FP_103_1%7FP_104_1%7FP_105_1%7FP_106_1%7FP_107_1%7FP_108_1%7FP_109_1%7FP_101_2%7FP_102_2%7FP_103_2%7FP_104_2%7FP_105_2%7FP_106_2%7FP_107_2%7FP_108_2%7FP_109_2%7FP_101_3%7FP_102_3%7FP_103_3%7FP_104_3%7FP_105_3%7FP_106_3%7FP_107_3%7FP_108_3%7FP_109_3",
        )
        self.assertEqual(
            wc_values,
            "Sessions%7F24GT4773%7FPENDING%7F05/02/2024%7FDETAINER WARRANT FORM%7FMYKA GODWIN%7FWILLIAM RIDLEY%7F, PRS%7F%7FSessions%7F24GT4770%7FPENDING%7F05/01/2024%7FDETAINER WARRANT%7FPROGRESS RESIDENTIAL BORROWER 6, LLC 1408 CHUTNEY COURT%7FDEFENDANT 1 OR ALL OTHER OCCUPANTS%7FMCCOY, JENNIFER JO%7F%7FSessions%7F24GT4772%7FPENDING%7F05/01/2024%7FDETAINER WARRANT%7FWESTBORO APARTMENTS%7FDEFENDANT 2%7FRUSNAK, JOSEPH P.%7F",
        )

    # @mock.patch("requests.post", side_effect=mocked_login)
    # def test_fetch_csv_url(self):
    #     csv = detainer_warrants.caselink.warrants.fetch_csv_url()


if __name__ == "__main__":
    unittest.main()
