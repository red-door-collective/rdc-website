import logging
import os
from pathlib import Path
from rdc_website.database import session
from flask import Request
from pytest import fixture
import json

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
    settings = {}
    with open('./tests/config.json') as f:
        settings = json.load(f)
    settings["SQLALCHEMY_DATABASE_URI"] = db_uri
    return settings


@fixture(scope="session")
def settings():
    return get_test_settings(get_db_uri())


@fixture(scope="session")
def app(settings):
    app = create_app(testing=True)
    return app


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
