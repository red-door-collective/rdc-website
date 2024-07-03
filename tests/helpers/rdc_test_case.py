from flask_testing import TestCase
from .setup import create_test_app


class RDCTestCase(TestCase):

    render_templates = False

    def create_app(self):
        return create_test_app()
