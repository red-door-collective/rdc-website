import logging
import os
from pathlib import Path
from rdc_website.database import session
from flask import Request
from pytest import fixture
from webtest import TestApp as Client

from rdc_website.app import create_app
from rdc_website.request import RdcWebsiteRequest
from rdc_website.detainer_warrants.models import DetainerWarrant

ROOT_DIR = Path(__file__).absolute().parent.parent
logg = logging.getLogger(__name__)


@fixture
def fixture_by_name(request):
    return request.getfixturevalue(request.param)


def get_db_uri():
    return os.getenv(
        "RDC_WEBSITE_TEST_DB_URL",
        "postgresql+psycopg2:///test_rdc_website?host=/tmp",
    )


def get_test_settings(db_uri):
    return {
        "database": {"uri": db_uri, "track_modifications": False},
        "app": {"default_language": "en", "languages": ["en", "es"]},
        "test_section": {"test_setting": "test"},
        "common": {"instance_name": "test", "fail_on_form_validation_error": False},
        "browser_session": {"secret_key": "test", "cookie_secure": False},
        "rdc_website_auth": {
            "client_id": "client_id_test",
            "client_secret": "test_secret",
        },
        "google": {"account_path": "~/.config/gspread/service_account.json"},
        "cloudinary": {"api_key": "secret", "secret": "secret"},
        "rollbar": {"client_token": "secret"},
        "caselink": {"username": "secret", "password": "secret"},
        "storage": {"root": "./data"},
        "flask": {
            "scheduler": {"run_jobs": False, "enabled": False},
            "ENV": "test",
            "FLASK_DEBUG": True,
            "FLASK_RUN_PORT": 5001,
            "FLASK_APP": "rdc_website.app",
            "SECRET_KEY": "fake",
            "SECURITY_PASSWORD_SALT": "fake2",
            "DEBUG": True,
            "LOG_FILE_PATH": "./capture.log",
            "VERSION": "dev",
            "SECURITY_REDIRECT_HOST": "localhost:1234",
            "REPO_PATH": "~/code/red-door-collective/rdc-website",
            "MAIL_SERVER": "smtp.gmail.com",
            "MAIL_PORT": 465,
        },
    }


@fixture(scope="session")
def settings():
    return get_test_settings(get_db_uri())


@fixture(scope="session")
def app(settings):
    app = create_app(testing=True)
    return app


@fixture
def client(app):
    return Client(app)


@fixture
def req(app):
    environ = Request.blank("test").environ
    req = RdcWebsiteRequest(environ, app)
    return req


@fixture
def db_session(app):
    session = session
    yield session
    session.rollback()


@fixture
def db_query(db_session):
    return db_session.query
