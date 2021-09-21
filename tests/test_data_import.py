import unittest

from flask import Flask
from flask_sqlalchemy import SQLAlchemy
from flask_testing import TestCase
from eviction_tracker.app import create_app, db, DetainerWarrant
from eviction_tracker.admin.models import User, user_datastore
from eviction_tracker.detainer_warrants.models import District
from flask_security import hash_password, auth_token_required
import eviction_tracker.detainer_warrants as detainer_warrants
from datetime import datetime
from decimal import Decimal
import uuid

example = {
    'Docket #': '20GT5633',
    'Order #': 5633,
    'File_date': '12/3/20',
    'Status': 'PENDING',
    'Month': '12 Dec',
    'Year': 2020,
    'Plaintiff': 'Che',
    'Plaintiff_atty': 'Thomas',
    'Court_date': '2/1/2021',
    'Any_day': 'TUESDAY',
    'Courtroom': '1B',
    'Presiding_judge': 'Kim',
    'Amount_claimed_num': '$2,239',
    'Amount_claimed_cat': 'FEES',
    'CARES': '',
    'LEGACY': 'Yes',
    'Nonpayment': 'Yes',
    'Address': '123 Best Rd #1234, 37210',
    'Def_1_first': 'Wenzel',
    'Def_1_middle': 'McKenzie',
    'Def_1_last': 'Stuwart',
    'Def_1_suffix': 'Jr.',
    'Def_1_phone': '123-456-7890',
    'Def_2_first': '',
    'Def_2_middle': '',
    'Def_2_last': '',
    'Def_2_suffix': '',
    'Def_2_phone': '',
    'Def_3_first': '',
    'Def_3_middle': '',
    'Def_3_last': '',
    'Def_3_suffix': '',
    'Def_3_phone': '',
    'Judgement': 'POSS',
    'Notes': ''
}


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

    def tearDown(self):
        db.session.remove()
        db.drop_all()

    def test_detainer_warrant_import(self):
        detainer_warrants.imports.from_workbook_help([example])
        warrant = db.session.query(DetainerWarrant).first()

        self.assertEqual(warrant.docket_id, example['Docket #'])
        self.assertEqual(warrant.file_date, date_as_str(
            example['File_date'], '%m/%d/%y'))
        self.assertEqual(warrant.status, example['Status'])
        self.assertEqual(warrant.plaintiff.name, example['Plaintiff'])
        self.assertEqual(warrant.plaintiff_attorney.name,
                         example['Plaintiff_atty'])
        self.assertEqual(warrant.court_date,
                         date_as_str(example['Court_date'], '%m/%d/%Y'))
        self.assertEqual(warrant.courtroom.name, example['Courtroom'])
        self.assertEqual(warrant.presiding_judge.name,
                         example['Presiding_judge'])
        self.assertEqual(warrant.amount_claimed, Decimal('2239'))
        self.assertEqual(warrant.amount_claimed_category,
                         example['Amount_claimed_cat'])
        self.assertEqual(warrant.is_cares,
                         None)
        self.assertEqual(warrant.is_legacy, True)
        self.assertEqual(
            warrant.defendants[0].address, example['Address'])
        self.assertEqual(
            warrant.defendants[0].name, 'Wenzel McKenzie Stuwart Jr.')
        self.assertEqual(
            warrant.defendants[0].potential_phones, example['Def_1_phone'])


if __name__ == '__main__':
    unittest.main()
