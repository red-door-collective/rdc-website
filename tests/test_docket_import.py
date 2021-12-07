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


def date_as_str(d, format):
    return datetime.strptime(d, format).date()


class TestDocketImport(TestCase):

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

    def test_docket_import(self):
        docket = None
        with open('tests/fixtures/circuitclerk/docket.html') as f:
            docket = detainer_warrants.circuitclerk.hearings.parse(
                '1A', f.read())

        self.assertEqual(len(docket), 16)
        first_hearing = docket[0]

        self.assertEqual(first_hearing.docket_id, '03GT2307')
        self.assertEqual(first_hearing.plaintiff.name, 'XXXXXGX XXXXX XXTX')
        self.assertEqual(first_hearing.plaintiff_attorney.name,
                         'XXXXXGXX, XXTXXX XXXXXXX')
        self.assertEqual(first_hearing.defendants[0].name, 'XXXGX X XXXXXTX')
        self.assertEqual(
            first_hearing.address, '110 XXX XXXXXX XXXXX XXT X 126 XXXXXGX XXXXX XXTX XXXXXXXXX,TX 37207')
        self.assertEqual(first_hearing._court_date, datetime.strptime(
            '21-11-23 09:00', '%y-%m-%d %H:%M'))
        self.assertEqual(first_hearing.courtroom.name, '1A')
        self.assertEqual(first_hearing.court_order_number, 0)

        second_hearing = docket[1]
        self.assertEqual(second_hearing.docket_id, '21GT5329')
        self.assertEqual(second_hearing.court_order_number, 1)
        self.assertEqual(second_hearing._court_date, datetime.strptime(
            '21-11-23 09:00', '%y-%m-%d %H:%M'))

        first_hearing_at_ten = docket[8]
        self.assertEqual(first_hearing_at_ten.docket_id, '21GC5871')
        self.assertEqual(first_hearing_at_ten.court_order_number, 8)
        self.assertEqual(first_hearing_at_ten._court_date, datetime.strptime(
            '21-11-23 10:00', '%y-%m-%d %H:%M'))


if __name__ == '__main__':
    unittest.main()
