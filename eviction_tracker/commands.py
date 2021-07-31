"""Click commands."""
import os
from glob import glob
from subprocess import call
import phonenumbers
import click
from flask import current_app
from flask.cli import with_appcontext
from flask_security import hash_password
from werkzeug.exceptions import MethodNotAllowed, NotFound
import gspread
import eviction_tracker.detainer_warrants as detainer_warrants
from eviction_tracker.admin.models import User, user_datastore
from eviction_tracker.database import db
from eviction_tracker.detainer_warrants.models import PhoneNumberVerification, Defendant, District
from twilio.rest import Client
from twilio.base.exceptions import TwilioRestException
import uuid

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
@click.option('-w', '--workbook-name', default='CURRENT 2020-2021 Detainer Warrants',
              help='Name of Google spreadsheet')
@click.option('-l', '--limit', default=None,
              help='Number of rows to insert')
@click.option('-k', '--service-account-key', default=None,
              help='Google Service Account filepath')
@with_appcontext
def sync(workbook_name, limit, service_account_key):
    """Sync data with the Google spreadsheet"""
    detainer_warrants.imports.from_workbook(
        workbook_name, limit=limit, service_account_key=service_account_key)


@click.command()
@click.option('-w', '--workbook-name', default='GS Dockets (Starting March 15)',
              help='Name of Google spreadsheet')
@click.option('-l', '--limit', default=None,
              help='Number of rows to insert')
@click.option('-k', '--service-account-key', default=None,
              help='Google Service Account filepath')
@click.option('-ww', '--warrant-wb', is_flag=True, flag_value='CURRENT 2020-2021 Detainer Warrants',
              default=None, help='Extract judgements from detainer warrant sheet')
@with_appcontext
def sync_judgements(workbook_name, limit, service_account_key, warrant_wb):
    if warrant_wb:
        detainer_warrants.judgement_imports.from_dw_wb(
            warrant_wb, limit=limit, service_account_key=service_account_key)

    else:
        detainer_warrants.judgement_imports.from_workbook(
            workbook_name, limit=limit, service_account_key=service_account_key)


@click.command()
@click.option('-c', '--courtroom', default=None,
              help='Courtroom')
@click.option('-d', '--date', default=None,
              help='Date')
@with_appcontext
def scrape_sessions_site(courtroom, date):
    detainer_warrants.judgement_scraping.scrape(courtroom, date)


@click.command()
@with_appcontext
def scrape_sessions_week():
    detainer_warrants.judgement_scraping.scrape_entire_site()


@click.command()
@click.option('-w', '--workbook-name', default='Website Export',
              help='Sheet name')
@click.option('-k', '--service-account-key', default=None,
              help='Google Service Account filepath')
@click.option('-o', '--only', default=None, help='Only run one sheet')
@with_appcontext
def export(workbook_name, service_account_key, only):
    if only == 'Detainer Warrants':
        detainer_warrants.exports.to_spreadsheet(
            workbook_name, service_account_key)
    elif only == 'Judgements':
        detainer_warrants.exports.to_judgement_sheet(
            workbook_name, service_account_key)
    elif only == 'Court Watch':
        detainer_warrants.exports.to_court_watch_sheet(
            workbook_name, service_account_key)
    else:
        detainer_warrants.exports.to_spreadsheet(
            workbook_name, service_account_key)
        detainer_warrants.exports.to_judgement_sheet(
            workbook_name, service_account_key)
        detainer_warrants.exports.to_court_watch_sheet(
            workbook_name, service_account_key)


def validate_phone_number(client, app, phone_number):
    """Asks Twilio for additional phone number information. Saves result to the database."""
    proper_phone_number = None
    try:
        proper_phone_number = phonenumbers.parse(phone_number, region='US')
        proper_phone_number = phonenumbers.format_number(
            proper_phone_number, phonenumbers.PhoneNumberFormat.E164)
    except phonenumbers.NumberParseException as e:
        app.logger.info(f'Failed to parse {phone_number}: {e}')
        return

    existing_number = db.session.query(PhoneNumberVerification).filter_by(
        phone_number=proper_phone_number).first()

    if existing_number is not None:
        app.logger.info(f'number already validated: {existing_number}')
        return

    try:
        verified_number = client.lookups \
            .v1 \
            .phone_numbers(proper_phone_number) \
            .fetch(type=['carrier', 'caller-name'])
    except TwilioRestException as e:
        app.logger.info(f'Failed to fetch {proper_phone_number}: {e}')
        entry = PhoneNumberVerification.create(
            phone_number=proper_phone_number)
        return entry

    entry = PhoneNumberVerification.from_twilio_response(verified_number)
    db.session.add(entry)
    db.session.commit()

    return entry


def twilio_client(app):
    account_sid = app.config['TWILIO_ACCOUNT_SID']
    auth_token = app.config['TWILIO_AUTH_TOKEN']
    return Client(account_sid, auth_token)


@click.command()
@click.option('-l', '--limit', default=None, help='Number of phone numbers to validate')
@with_appcontext
def verify_phones(limit):
    """Verify phone numbers listed on Detainer Warrants"""
    client = twilio_client(current_app)
    numbers_to_validate = db.session.query(
        Defendant).filter(Defendant.potential_phones != None)

    if limit:
        numbers_to_validate = numbers_to_validate.limit(limit)

    for defendant in numbers_to_validate.all():
        for potential_phone in defendant.potential_phones.split(','):
            validate_phone_number(client, current_app, potential_phone)


@click.command()
@click.argument('phone_number')
@with_appcontext
def verify_phone(phone_number):
    """Verify an individual phone number"""
    client = twilio_client(current_app)
    validate_phone_number(client, current_app, phone_number)


@click.command()
@with_appcontext
def bootstrap():
    district, _ = detainer_warrants.util.get_or_create(
        db.session, District, name="Davidson County")

    db.session.add(district)
    db.session.commit()

    simple = "123456"
    env = current_app.config.get('ENV')

    roles = ['Superuser', 'Admin', 'Organizer', 'Defendant']
    for role in roles:
        user_datastore.find_or_create_role(role)

    user_datastore.create_user(id=-1, email="system-user@reddoorcollective.org", first_name="System",
                               last_name="User", password=hash_password(str(uuid.uuid4())), roles=['Superuser'])

    if env == 'development':
        user_datastore.create_user(email="superuser@example.com", first_name="Super",
                                   last_name="User", password=hash_password(simple), roles=['Superuser'])
        user_datastore.create_user(email="admin@example.com", first_name="Admin",
                                   last_name="Person", password=hash_password(simple), roles=['Admin'])
        user_datastore.create_user(email="organizer@example.com",
                                   first_name="Organizer", last_name="Gal", password=hash_password(simple), roles=['Organizer'])
        user_datastore.create_user(email="defendant@example.com", first_name="Defendant",
                                   last_name="Guy", password=hash_password(simple), roles=['Defendant'])

    db.session.commit()
