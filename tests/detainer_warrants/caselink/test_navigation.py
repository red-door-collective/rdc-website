import unittest
from unittest import mock

from flask import Flask
from flask_sqlalchemy import SQLAlchemy
from flask_testing import TestCase
from rdc_website.app import create_app, db, DetainerWarrant
from rdc_website.admin.models import User, user_datastore
from rdc_website.detainer_warrants.models import Hearing, PleadingDocument, Judgment
from flask_security import hash_password, auth_token_required
import rdc_website.detainer_warrants as detainer_warrants
from rdc_website.detainer_warrants.caselink.navigation import Navigation
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

    
    if args[0] == 'https://caselink.nashville.gov/cgi-bin/webshell.asp':
        with open('tests/fixtures/caselink/login-successful.html') as f:
            return MockResponse(f.read(), 200)

    return MockResponse(None, 404)

def date_as_str(d, format):
    return datetime.strptime(d, format).date()

class TestNavigation(TestCase):

    def create_app(self):
        app = create_app(self)
        app.config['TESTING'] = True
        app.config['SQLALCHEMY_DATABASE_URI'] = 'postgresql+psycopg2://rdc_website_test:junkdata@localhost:5432/rdc_website_test'
        app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
        return app

    # def setUp(self):
    #     db.create_all()
    #     db.session.commit()

    # def tearDown(self):
    #     db.session.remove()
    #     db.drop_all()

    @mock.patch('requests.post', side_effect=mocked_login)
    def test_login(self, mock_post):
        navigation = Navigation.login('some-username', 'some-password')

        self.assertEqual(navigation.path, '/gsapdfs/1714944347676.VERIFY.20580.77105150.html')
        self.assertEqual(navigation.web_io_handle, '1714944347676')
        self.assertEqual(navigation.parent, 'VERIFY')

        self.assertEqual(len(mock_post.call_args_list), 1)


if __name__ == '__main__':
    unittest.main()
