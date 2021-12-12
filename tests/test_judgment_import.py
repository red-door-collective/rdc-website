import unittest

from flask import Flask
from flask_sqlalchemy import SQLAlchemy
from flask_testing import TestCase
from eviction_tracker.app import create_app, db, DetainerWarrant
from eviction_tracker.admin.models import User, user_datastore
from eviction_tracker.detainer_warrants.models import District, Hearing, PleadingDocument, Judgment
from flask_security import hash_password, auth_token_required
import eviction_tracker.detainer_warrants as detainer_warrants
from datetime import datetime
from decimal import Decimal
import uuid


def date_as_str(d, format):
    return datetime.strptime(d, format).date()


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
        District.create(name='Davidson County')
        db.session.commit()
        with open('tests/fixtures/caselink/judgment-pdf-as-text.txt') as f:
            PleadingDocument.create(
                url='123', kind='JUDGMENT', text=f.read(), docket_id='21GT1234')

        Hearing.create(_court_date=datetime.now(),
                       docket_id='21GT1234', address='example')
        db.session.commit()

    def tearDown(self):
        db.session.remove()
        db.drop_all()

    def test_judgment_import(self):
        hearing = Hearing.query.first()
        document = PleadingDocument.query.first()
        hearing.update_judgment_from_document(document)
        judgment = hearing.judgment

        self.assertEqual(judgment.detainer_warrant_id, '21GT1234')
        self.assertEqual(datetime.strftime(
            '%m/%d/%y', judgment._file_date), '09/02/21')
        self.assertEqual(judgment.plaintiff.name, 'REDACTED REDACTED')
        self.assertEqual(judgment.judge.name, 'Redacted Redacted')
        self.assertEqual(judgment.in_favor_of, 'PLAINTIFF')
        self.assertEqual(judgment.awards_possession, True)
        self.assertEqual(judgment.awards_fees, Decimal('7639.56'))
        self.assertEqual(judgment.entered_by, 'AGREEMENT_OF_PARTIES')
        self.assertIsNone(judgment.interest_rate)
        self.assertEqual(judgment.interest_follows_site, True)
        self.assertIsNone(judgment.dismissal_basis)
        self.assertIsNone(judgment.with_prejudice)
        self.assertEqual(
            judgment.notes, 'DEFENDANT REDACTED MADE PERSONAL APPEARANCE IN COURT SEPT. 1, 2021 ANDSUBMITS TO PERSONAL JURISDICTION OF THIS COURT.')


if __name__ == '__main__':
    unittest.main()
