import unittest

from flask import Flask
from flask_sqlalchemy import SQLAlchemy
from flask_testing import TestCase
from eviction_tracker.app import create_app, db, DetainerWarrant
from eviction_tracker.admin.models import User, user_datastore
from eviction_tracker.detainer_warrants.models import Hearing, PleadingDocument, Judgment
from flask_security import hash_password, auth_token_required
import eviction_tracker.detainer_warrants as detainer_warrants
from datetime import datetime
from decimal import Decimal
import uuid


def date_as_str(d, format):
    return datetime.strptime(d, format).date()


DOCKET_ID = '21GT1234'


class TestDataImport(TestCase):

    def create_app(self):
        app = create_app(self)
        app.config['TESTING'] = True
        app.config['SQLALCHEMY_DATABASE_URI'] = 'postgresql+psycopg2://eviction_tracker_test:junkdata@localhost:5432/eviction_tracker_test'
        app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
        return app

    def setUp(self):
        db.create_all()
        roles = ['Superuser', 'Admin', 'Organizer', 'Defendant']
        for role in roles:
            user_datastore.find_or_create_role(role)
            db.session.commit()
        user_datastore.create_user(id=-1, email="system-user@reddoorcollective.org", first_name="System",
                                   last_name="User", password=hash_password(str(uuid.uuid4())), roles=['Superuser'])
        db.session.commit()

    def tearDown(self):
        db.session.remove()
        db.drop_all()

    def test_pleadings_import(self):
        match = None
        with open('tests/fixtures/caselink/detainer-warrant-page.html') as f:
            match = detainer_warrants.caselink.pleadings.import_from_postback_html(
                f.read())

        urls_mess = match.group(1)
        urls = [url for url in urls_mess.split('ý') if url != '']

        self.assertEqual(len(urls), 5)
        self.assertEqual(
            urls[0], 'https://caselinkimages.nashville.gov/PublicSessions/21/21GT9999/2221242.pdf')
        self.assertEqual(
            urls[1], 'https://caselinkimages.nashville.gov/PublicSessions/21/21GT9999/02221243.pdf')
        self.assertEqual(
            urls[2], 'https://caselinkimages.nashville.gov/PublicSessions/21/21GT9999/02234860.pdf')
        self.assertEqual(
            urls[3], 'https://caselinkimages.nashville.gov/PublicSessions/21/21GT9999/02244410.pdf')
        self.assertEqual(
            urls[4], 'https://caselinkimages.nashville.gov/PublicSessions/21/21GT9999/02245154.pdf')


if __name__ == '__main__':
    unittest.main()
