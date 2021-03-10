"""Create an application instance."""
from flask.helpers import get_debug_flag

from eviction_tracker.app import create_app

app = create_app()
