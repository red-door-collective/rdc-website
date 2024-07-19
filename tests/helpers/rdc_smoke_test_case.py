import time
from rdc_website.database import db
from flask_testing import TestCase
from .setup import create_test_app


class RDCSmokeTestCase(TestCase):

    render_templates = False

    def create_app(self):
        return create_test_app()

    def setUp(self):
        db.create_all()

    def tearDown(self):
        db.session.remove()
        db.drop_all()
        time.sleep(1)
