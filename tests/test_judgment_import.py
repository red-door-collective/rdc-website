import unittest

from flask import Flask
from flask_sqlalchemy import SQLAlchemy
from flask_testing import TestCase
from rdc_website.app import create_app, db, DetainerWarrant
from rdc_website.admin.models import User, user_datastore
from rdc_website.detainer_warrants.models import Hearing, Plaintiff, PleadingDocument, Judge, Judgment
from flask_security import hash_password, auth_token_required
import rdc_website.detainer_warrants as detainer_warrants
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
        with open('tests/fixtures/caselink/judgment-pdf-as-text.txt') as f:
            PleadingDocument.create(
                url='123', kind='JUDGMENT', text=f.read(), docket_id=DOCKET_ID)

        Hearing.create(_court_date=datetime.now(),
                       docket_id=DOCKET_ID, address='example')
        db.session.commit()

    def tearDown(self):
        db.session.remove()
        db.drop_all()

    def test_judgment_import(self):
        hearing = Hearing.query.first()
        document = PleadingDocument.query.first()
        hearing.update_judgment_from_document(document)
        judgment = hearing.judgment

        self.assertEqual(judgment.detainer_warrant_id, DOCKET_ID)
        self.assertEqual(datetime.strftime(
            judgment._file_date, '%m/%d/%y'), '09/02/21')
        self.assertEqual(judgment.plaintiff.name, 'REDACTED APARTMENTS')
        self.assertEqual(judgment.judge.name, 'Redacted Redacted')
        self.assertEqual(judgment.in_favor_of, 'PLAINTIFF')
        self.assertEqual(judgment.awards_possession, True)
        self.assertEqual(judgment.awards_fees, Decimal('7639.56'))
        self.assertEqual(judgment.entered_by, 'AGREEMENT_OF_PARTIES')
        self.assertIsNone(judgment.interest_rate)
        self.assertEqual(judgment.interest_follows_site, True)
        self.assertIsNone(judgment.dismissal_basis)
        self.assertIsNone(judgment.with_prejudice)

    def test_judgment_parsing(self):
        attrs = None
        with open('tests/fixtures/caselink/judgment-pdf-as-text-suit.txt') as f:
            attrs = Judgment.attributes_from_pdf(f.read())

        plaintiff_id = Plaintiff.query.first().id
        judge_id = Judge.query.first().id

        self.assertEqual(attrs['detainer_warrant_id'], DOCKET_ID)
        self.assertEqual(datetime.strftime(
            attrs['_file_date'], '%m/%d/%y'), '11/04/21')
        self.assertEqual(attrs['plaintiff_id'], plaintiff_id)
        self.assertEqual(attrs['judge_id'], judge_id)
        self.assertEqual(attrs['in_favor_of_id'], 0)
        self.assertEqual(attrs['awards_possession'], True)
        self.assertIsNone(attrs['awards_fees'])
        self.assertEqual(attrs['entered_by_id'], 0)
        self.assertIsNone(attrs['interest_rate'])
        self.assertIsNone(attrs['interest_follows_site'])
        self.assertIsNone(attrs['dismissal_basis_id'])
        self.assertIsNone(attrs['with_prejudice'])


if __name__ == '__main__':
    unittest.main()
