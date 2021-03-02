import unittest

from flask import Flask
from flask_sqlalchemy import SQLAlchemy
from app.models import DetainerWarrant
import app.spreadsheets as spreadsheet

from helpers import db

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

class TestDataImport(unittest.TestCase):

    def test_detainer_warrant_import(self):
        spreadsheet.imports.detainer_warrants([example_warrant])
        saved_warrant = db.session.query(DetainerWarrant).first()

        self.assertEqual(saved_warrant.docket_id, example_warrant[DOCKET_ID])
        self.assertEqual(saved_warrant.file_date, example_warrant[FILE_DATE])


if __name__ == '__main__':
    unittest.main()
