"""Create an application instance."""
from flask.helpers import get_debug_flag

from rdc_website.app import create_app

app = create_app()
