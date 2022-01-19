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
from eviction_tracker.detainer_warrants.models import Attorney, PhoneNumberVerification, PleadingDocument, Defendant, Judgment, District
from twilio.rest import Client
from twilio.base.exceptions import TwilioRestException
import uuid
import logging.config
import eviction_tracker.config as config
from datetime import date, datetime
from io import StringIO

logging.config.dictConfig(config.LOGGING)
logger = logging.getLogger(__name__)

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
@with_appcontext
def sync_judgments(workbook_name, limit, service_account_key):
    detainer_warrants.judgment_imports.from_workbook(
        workbook_name, limit=limit, service_account_key=service_account_key)


@click.command()
@click.argument('url')
@with_appcontext
def parse_docket(url):
    detainer_warrants.circuitclerk.hearings.parse(url)


@click.command()
@click.argument('url')
@with_appcontext
def scrape_docket(url):
    detainer_warrants.circuitclerk.hearings.scrape_docket(url)


@click.command()
@with_appcontext
def scrape_dockets():
    logger.info(f'Scraping Sessions site for the upcoming week')
    detainer_warrants.circuitclerk.hearings.scrape()


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
    elif only == 'Judgments':
        detainer_warrants.exports.to_judgment_sheet(
            workbook_name, service_account_key)
    elif only == 'Court Watch':
        detainer_warrants.exports.to_court_watch_sheet(
            workbook_name, service_account_key)
    else:
        detainer_warrants.exports.to_spreadsheet(
            workbook_name, service_account_key)
        detainer_warrants.exports.to_judgment_sheet(
            workbook_name, service_account_key)
        detainer_warrants.exports.to_court_watch_sheet(
            workbook_name, service_account_key)


@click.command()
@click.option('-d', '--on-date', default=None, help='Date for court watch. Defaults to today.')
@click.option('-w', '--whole-week', is_flag=True, default=False, help='Set for a full week\'s export')
@click.option('-k', '--service-account-key', default=None,
              help='Google Service Account filepath')
@with_appcontext
def export_courtroom_dockets(on_date, whole_week, service_account_key):
    starting_date = datetime.strptime(
        on_date, '%Y-%m-%d') if on_date else date.today()
    if whole_week:
        detainer_warrants.exports.weekly_courtroom_entry_workbook(
            starting_date, service_account_key=service_account_key
        )
    else:
        detainer_warrants.exports.to_courtroom_entry_workbook(
            starting_date,
            service_account_key=service_account_key
        )


def validate_phone_number(client, app, phone_number):
    """Asks Twilio for additional phone number information. Saves result to the database."""
    proper_phone_number = None
    try:
        proper_phone_number = phonenumbers.parse(phone_number, region='US')
        proper_phone_number = phonenumbers.format_number(
            proper_phone_number, phonenumbers.PhoneNumberFormat.E164)
    except phonenumbers.NumberParseException as e:
        logger.info(f'Failed to parse {phone_number}: {e}')
        return

    existing_number = db.session.query(PhoneNumberVerification).filter_by(
        phone_number=proper_phone_number).first()

    if existing_number is not None:
        logger.info(f'number already validated: {existing_number}')
        return

    try:
        verified_number = client.lookups \
            .v1 \
            .phone_numbers(proper_phone_number) \
            .fetch(type=['carrier', 'caller-name'])
    except TwilioRestException as e:
        logger.info(f'Failed to fetch {proper_phone_number}: {e}')
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
    numbers_to_validate = db.session.query(
        Defendant).filter(Defendant.potential_phones != None)
    logger.info(f'Verifying {numbers_to_validate.count()} phone numbers')
    client = twilio_client(current_app)

    if limit:
        numbers_to_validate = numbers_to_validate.limit(limit)

    for defendant in numbers_to_validate.all():
        for potential_phone in defendant.potential_phones.split(','):
            validate_phone_number(client, current_app, potential_phone)


@click.command()
@click.option('-f', '--file-path',
              help='Path to the csv file')
@with_appcontext
def import_from_caselink(file_path):
    """Insert Detainer Warrants"""
    detainer_warrants.csv_imports.from_caselink(file_path)


@click.command()
@click.argument('phone_number')
@with_appcontext
def verify_phone(phone_number):
    """Verify an individual phone number"""
    client = twilio_client(current_app)
    validate_phone_number(client, current_app, phone_number)


@click.command()
@click.argument('url')
@with_appcontext
def extract_pleading_document_text(url):
    document = PleadingDocument.query.get(url)
    detainer_warrants.caselink.pleadings.extract_text_from_document(document)


@click.command()
@with_appcontext
def extract_all_pleading_document_details():
    detainer_warrants.caselink.pleadings.extract_all_pleading_document_details()


@click.command()
@with_appcontext
def retry_detainer_warrant_extraction():
    detainer_warrants.caselink.pleadings.retry_detainer_warrant_extraction()


@click.command()
@click.option('-s', '--start_date', default=None, help='Start window')
@click.option('-e', '--end_date', default=None, help='End window')
@with_appcontext
def try_ocr_detainer_warrants(start_date, end_date):
    start = datetime.strptime(start_date, '%Y-%m-%d') if start_date else None
    end = datetime.strptime(end_date, '%Y-%m-%d') if end_date else None
    detainer_warrants.caselink.pleadings.try_ocr_detainer_warrants(start, end)


@click.command()
@click.option('-s', '--start_date', default=None, help='Start window')
@click.option('-e', '--end_date', default=None, help='End window')
@with_appcontext
def try_ocr_extraction(start_date, end_date):
    start = datetime.strptime(start_date, '%Y-%m-%d') if start_date else None
    end = datetime.strptime(end_date, '%Y-%m-%d') if end_date else None
    detainer_warrants.caselink.pleadings.try_ocr_extraction(start, end)


@click.command()
@with_appcontext
def extract_no_kind_pleading_document_text():
    detainer_warrants.caselink.pleadings.extract_no_kind_document_details()


@click.command()
@with_appcontext
def bulk_extract_pleading_document_details():
    detainer_warrants.caselink.pleadings.bulk_extract_pleading_document_details()


@click.command()
@click.argument('url')
@with_appcontext
def update_judgment_from_document(url):
    """Extract judgment from pdf"""
    document = PleadingDocument.query.get(url)
    detainer_warrants.caselink.pleadings.update_judgment_from_document(
        document)


@click.command()
@with_appcontext
def update_judgments_from_documents():
    detainer_warrants.caselink.pleadings.update_judgments_from_documents()


@click.command()
@with_appcontext
def update_warrants_from_documents():
    detainer_warrants.caselink.pleadings.update_warrants_from_documents()


@click.command()
@with_appcontext
def parse_detainer_warrant_addresses():
    detainer_warrants.caselink.pleadings.parse_detainer_warrant_addresses()


@click.command()
@click.argument('docket_id')
@with_appcontext
def gather_pleading_documents(docket_id):
    """Gather pleading documents for a detainer warrant"""
    detainer_warrants.caselink.pleadings.import_documents(docket_id)


@click.command()
@with_appcontext
def parse_mismatched_pleading_documents():
    detainer_warrants.caselink.pleadings.parse_mismatched_html()


@click.command()
@click.option('--docket-id', '-d', multiple=True)
@with_appcontext
def gather_pleading_documents_in_bulk(docket_id):
    """Gather pleading documents for detainer warrants"""
    if docket_id:
        detainer_warrants.caselink.pleadings.bulk_import_documents(docket_id)
    else:
        detainer_warrants.caselink.pleadings.update_pending_warrants()


@click.command()
@click.option('--start-date', '-s')
@click.option('--end-date', '-e')
@with_appcontext
def gather_documents_for_missing_addresses(start_date, end_date):
    start = datetime.strptime(start_date, '%Y-%m-%d') if start_date else None
    end = datetime.strptime(end_date, '%Y-%m-%d') if end_date else None
    detainer_warrants.caselink.pleadings.gather_documents_for_missing_addresses(
        start, end)


@click.command()
@click.argument('start_date')
@click.argument('end_date')
@with_appcontext
def gather_warrants_csv(start_date, end_date):
    """Gather detainer warrants as a CSV"""
    start = datetime.strptime(start_date, '%Y-%m-%d')
    end = datetime.strptime(end_date, '%Y-%m-%d')
    detainer_warrants.caselink.warrants.import_from_caselink(start, end)


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
        db.session.commit()

    user_datastore.create_user(id=-1, email="system-user@reddoorcollective.org", first_name="System",
                               last_name="User", password=hash_password(str(uuid.uuid4())), roles=['Superuser'])

    Attorney.create(id=-1, name="Plaintiff Representing Self",
                    district=district)
    db.session.commit()

    if env == 'development':
        user_datastore.create_user(email="superuser@example.com", first_name="Super",
                                   last_name="User", password=hash_password(simple), roles=['Superuser'])
        db.session.commit()
        user_datastore.create_user(email="admin@example.com", first_name="Admin",
                                   last_name="Person", password=hash_password(simple), roles=['Admin'])
        db.session.commit()
        user_datastore.create_user(email="organizer@example.com",
                                   first_name="Organizer", last_name="Gal", password=hash_password(simple), roles=['Organizer'])
        db.session.commit()
        user_datastore.create_user(email="defendant@example.com", first_name="Defendant",
                                   last_name="Guy", password=hash_password(simple), roles=['Defendant'])
        db.session.commit()
