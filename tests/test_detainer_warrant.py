import unittest

from flask import Flask
from flask_sqlalchemy import SQLAlchemy
from flask_testing import TestCase
from rdc_website.app import create_app, db, DetainerWarrant
from rdc_website.admin.models import User, user_datastore
from rdc_website.detainer_warrants.models import Address, Hearing, Plaintiff, PleadingDocument, Judge, Judgment
from flask_security import hash_password, auth_token_required
import rdc_website.detainer_warrants as detainer_warrants
from datetime import datetime
from decimal import Decimal
import uuid


def date_as_str(d, format):
    return datetime.strptime(d, format).date()


DOCKET_ID = '21GT1234'


class TestDetainerWarrantImport(TestCase):

    def create_app(self):
        app = create_app(self)
        app.config['TESTING'] = True
        app.config['SQLALCHEMY_DATABASE_URI'] = 'postgresql+psycopg2://rdc_website_test:junkdata@localhost:5432/rdc_website_test'
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
        DetainerWarrant.create(docket_id=DOCKET_ID)
        with open('tests/fixtures/caselink/detainer-warrant-pdf.txt') as f:
            PleadingDocument.create(
                url='123', kind='DETAINER_WARRANT', text=f.read(), docket_id=DOCKET_ID)

        db.session.commit()

    def tearDown(self):
        db.session.remove()
        db.drop_all()

    def test_import(self):
        document = PleadingDocument.query.first()
        detainer_warrants.caselink.pleadings.update_detainer_warrant_from_document(
            document)

        dw = DetainerWarrant.query.get(DOCKET_ID)
        self.assertEqual(dw.potential_addresses, [
                         Address.query.get('123 Fake Street, Nashville, TN 37214')])


if __name__ == '__main__':
    unittest.main()
