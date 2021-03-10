import unittest

from flask import Flask
from flask_sqlalchemy import SQLAlchemy
from flask_testing import TestCase
import eviction_tracker.detainer_warrants as detainer_warrants
from eviction_tracker.detainer_warrants.models import DetainerWarrant
from eviction_tracker.app import create_app, db

example_warrant = ['20GT2',
                   '2',
                   '1/2/20',
                   'CLOSED',
                   '1 Jan',
                   '2020',
                   'BATTLE,PATRICIA',
                   'PRS',
                   '',
                   '',
                   '',
                   '',
                   '',
                   '',
                   'WILLIAMS,SHARHONDA',
                   '5109 BUENA VISTA PIKE 37218',
                   'SHARHONDA WILLIAMS']


DOCKET_ID = 0
FILE_DATE = 2

class TestDataImport(TestCase):

    def create_app(self):
        app = create_app(self)
        app.config['TESTING'] = True
        app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite://'
        app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
        return app

    def setUp(self):
        db.create_all()
    
    def tearDown(self):
        db.session.remove()
        db.drop_all()

    def test_detainer_warrant_import(self):
        detainer_warrants.imports.from_spreadsheet([example_warrant])
        saved_warrant = db.session.query(DetainerWarrant).first()

        self.assertEqual(saved_warrant.docket_id, example_warrant[DOCKET_ID])
        self.assertEqual(saved_warrant.file_date, example_warrant[FILE_DATE])


if __name__ == '__main__':
    unittest.main()
