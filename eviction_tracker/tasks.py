import time
from datetime import datetime, date, timedelta
from apscheduler.triggers.interval import IntervalTrigger

import eviction_tracker.detainer_warrants as detainer_warrants
from eviction_tracker.extensions import scheduler
from eviction_tracker.monitoring import log_on_exception

import eviction_tracker.config as config
import logging.config

logging.config.dictConfig(config.LOGGING)
logger = logging.getLogger(__name__)


@scheduler.task(IntervalTrigger(minutes=60), id='import_warrants')
@log_on_exception
def import_warrants():
    with scheduler.app.app_context():
        dw_wb = 'CURRENT 2020-2021 Detainer Warrants'
        judgement_wb = 'GS Dockets (Starting March 15)'
        key = scheduler.app.config['GOOGLE_ACCOUNT_PATH']
        logger.info(f'Importing detainer warrants from workbook: {dw_wb}')
        detainer_warrants.imports.from_workbook(
            dw_wb, service_account_key=key)
        logger.info(f'Importing judgements from workbook: {dw_wb}')
        detainer_warrants.judgement_imports.from_dw_wb(
            dw_wb, service_account_key=key)
        logger.info(f'Importing judgements from workbook: {judgement_wb}')
        detainer_warrants.judgement_imports.from_workbook(
            judgement_wb, service_account_key=key)


@scheduler.task(IntervalTrigger(minutes=70), id='export')
@log_on_exception
def export():
    with scheduler.app.app_context():
        workbook_name = 'Website Export'
        key = scheduler.app.config['GOOGLE_ACCOUNT_PATH']
        logger.info(
            f'Exporting detainer warrants to workbook: {workbook_name}')
        detainer_warrants.exports.to_spreadsheet(workbook_name, key)
        logger.info(f'Exporting judgements to workbook: {workbook_name}')
        detainer_warrants.exports.to_judgement_sheet(workbook_name, key)
        logger.info(
            f'Exporting upcoming court dates to workbook: {workbook_name}')
        detainer_warrants.exports.to_court_watch_sheet(workbook_name, key)


@scheduler.task(IntervalTrigger(minutes=65), id='sync_with_sessions_site')
@log_on_exception
def sync_with_sessions_site():
    with scheduler.app.app_context():
        logger.info(f'Scraping General Sessions website')
        detainer_warrants.judgement_scraping.scrape_entire_site()
