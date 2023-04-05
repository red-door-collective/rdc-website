import time
from datetime import datetime, date, timedelta
from apscheduler.triggers.cron import CronTrigger
from apscheduler.triggers.interval import IntervalTrigger

import eviction_tracker.detainer_warrants as detainer_warrants
from eviction_tracker.extensions import scheduler

import eviction_tracker.config as config
import logging.config

logging.config.dictConfig(config.LOGGING)
logger = logging.getLogger(__name__)

weekdays = "1-5"

# sessions site import


@scheduler.task(
    CronTrigger(day_of_week=weekdays, hour=10, minute=0, second=0),
    id="sync-with-sessions-site",
)
def import_sessions_site_hearings():
    with scheduler.app.app_context():
        logger.info(f"Scraping General Sessions website for live court data")

        detainer_warrants.circuitclerk.hearings.scrape()


# CaseLink import


@scheduler.task(
    CronTrigger(day_of_week=weekdays, hour=18, minute=0, second=0, jitter=200),
    id="import-caselink-warrants",
)
def import_caselink_warrants(start_date=None, end_date=None):
    start = (
        datetime.strptime(start_date, "%Y-%m-%d")
        if start_date
        else date.today() - timedelta(days=30)
    )
    end = datetime.strptime(end_date, "%Y-%m-%d") if end_date else date.today()

    with scheduler.app.app_context():
        logger.info(f"Gathering CSV warrant exports from CaseLink")

        detainer_warrants.caselink.warrants.bulk_import_csvs(start, end)


@scheduler.task(
    CronTrigger(day_of_week=weekdays, hour=19, minute=5, second=0, jitter=200),
    id="import-caselink-pleading-documents",
)
def import_caselink_pleading_documents():
    with scheduler.app.app_context():
        logger.info(f"Scraping CaseLink for pleading documents")

        detainer_warrants.caselink.pleadings.update_pending_warrants()


@scheduler.task(
    CronTrigger(day_of_week=weekdays, hour=3, minute=0, second=0, jitter=200),
    id="extract-pleading-document-details",
)
def extract_pleading_document_details():
    with scheduler.app.app_context():
        logger.info(f"Extracting pleading document details with OCR")

        detainer_warrants.caselink.pleadings.bulk_extract_pleading_document_details()


@scheduler.task(
    CronTrigger(day_of_week=weekdays, hour=12, minute=0, second=0, jitter=200),
    id="classify-pleading-documents",
)
def classify_caselink_pleading_documents():
    with scheduler.app.app_context():
        logger.info(f"Classifying pleading documents")

        detainer_warrants.caselink.pleadings.classify_documents()


# data export


@scheduler.task(CronTrigger(hour="*", minute=0, second=0, jitter=200), id="export")
def export():
    with scheduler.app.app_context():
        logger.info(f"Exporting upcoming court data to Google Sheets")

        workbook_name = "Website Export"
        key = scheduler.app.config["GOOGLE_ACCOUNT_PATH"]
        logger.info(f"Exporting upcoming court dates to workbook: {workbook_name}")
        detainer_warrants.exports.to_court_watch_sheet(workbook_name, key)
        courtroom_entry_wb = f'{datetime.strftime(date.today(), "%B %Y")} Court Watch'
        logger.info(f"Exporting the week's to workbook: {courtroom_entry_wb}")
        detainer_warrants.exports.weekly_courtroom_entry_workbook(date.today(), key)
