import unittest

from flask import Flask
from flask_sqlalchemy import SQLAlchemy
from flask_testing import TestCase
import eviction_tracker.detainer_warrants as detainer_warrants
from eviction_tracker.detainer_warrants.models import DetainerWarrant
from eviction_tracker.app import create_app, db
from datetime import datetime
from decimal import Decimal

example = {
    'Docket #': '20GT5633',
    'Order #': 5633,
    'File Date': '12/3/20',
    'Status': 'PENDING',
    'Month': '12 Dec',
    'Year': 2020,
    'Plantiff': 'Che',
    'Pltf. Attorney': 'Thomas',
    'Court Date': '2/1/2021',
    'Courtroom': '1B',
    'Presiding Judge': 'Kim',
    'Amt Claimed ($)': '$2,239',
    'Amount Claimed (CATEGORY)': 'FEES',
    'Amount Claimed (NON-$)': '',
    'Defendant(s)': '',
    'CARES covered property?': '',
    'LEGACY Case': 'Yes',
    'Defendant Address': '123 Best Rd #1234, 37210',
    'Zip code': 37210,
    'Def #1 Name': 'Wenzel',
    'Def #1 Phone': '123-456-7890',
    'Def #2 Name': '',
    'Def #2 Phone': '',
    'Def #3 Name': '',
    'Def #3 Phone': '',
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

    def tearDown(self):
        db.session.remove()
        db.drop_all()

    def test_detainer_warrant_import(self):
        detainer_warrants.imports.from_spreadsheet([example])
        warrant = db.session.query(DetainerWarrant).first()

        self.assertEqual(warrant.docket_id, example['Docket #'])
        self.assertEqual(warrant.file_date, date_as_str(
            example['File Date'], '%m/%d/%y'))
        self.assertEqual(warrant.status, example['Status'])
        self.assertEqual(warrant.plantiff.name, example['Plantiff'])
        self.assertEqual(warrant.plantiff.attorney.name,
                         example['Pltf. Attorney'])
        self.assertEqual(warrant.court_date,
                         date_as_str(example['Court Date'], '%m/%d/%Y'))
        self.assertEqual(warrant.courtroom.name, example['Courtroom'])
        self.assertEqual(warrant.presiding_judge.name,
                         example['Presiding Judge'])
        self.assertEqual(warrant.amount_claimed, Decimal('2239'))
        self.assertEqual(warrant.amount_claimed_category,
                         example['Amount Claimed (CATEGORY)'])
        self.assertEqual(warrant.is_cares,
                         None)
        self.assertEqual(warrant.is_legacy, True)
        self.assertEqual(
            warrant.defendants[0].address, example['Defendant Address'])
        self.assertEqual(warrant.zip_code, str(example['Zip code']))
        self.assertEqual(
            warrant.defendants[0].name, example['Def #1 Name'])
        self.assertEqual(
            warrant.defendants[0].potential_phones, example['Def #1 Phone'])
        self.assertEqual(warrant.judgement, example['Judgement'])


if __name__ == '__main__':
    unittest.main()
