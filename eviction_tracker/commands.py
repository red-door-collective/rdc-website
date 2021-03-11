"""Click commands."""
import os
from glob import glob
from subprocess import call

import click
from flask import current_app
from flask.cli import with_appcontext
from werkzeug.exceptions import MethodNotAllowed, NotFound
import gspread
import eviction_tracker.detainer_warrants as detainer_warrants
from eviction_tracker.database import db

HERE = os.path.abspath(os.path.dirname(__file__))
PROJECT_ROOT = os.path.join(HERE, os.pardir)
TEST_PATH = os.path.join(PROJECT_ROOT, 'tests')


@click.command()
def test():
    """Run the tests."""
    import pytest
    rv = pytest.main([TEST_PATH, '--verbose'])
    exit(rv)


@click.command()
@click.option('-s', '--sheet-name', default=None,
              help='Google Service Account filepath')
@click.option('-l', '--limit', default=None,
              help='Number of rows to insert')
@click.option('-k', '--service-account-key', default=None,
              help='Google Service Account filepath')
@with_appcontext
def sync(sheet_name, limit, service_account_key):
    """Sync data with the Google spreadsheet"""

    connect_kwargs = dict()
    if service_account_key:
        connect_kwargs['filename'] = service_account_key

    gc = gspread.service_account(**connect_kwargs)

    sh = gc.open(sheet_name)

    ws = sh.worksheet("All Detainer Warrants")

    all_rows = ws.get_all_values()

    stop_index = int(limit) if limit else all_rows

    rows = all_rows[1:stop_index] if limit else all_rows[1:]

    detainer_warrants.imports.from_spreadsheet(rows)
