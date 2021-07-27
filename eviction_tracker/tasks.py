import time
from datetime import datetime, date, timedelta
from apscheduler.triggers.interval import IntervalTrigger

import eviction_tracker.detainer_warrants as detainer_warrants
from eviction_tracker.extensions import scheduler


@scheduler.task(IntervalTrigger(minutes=60), id='import_warrants')
def import_warrants():
    print('Importing from google sheets')
    print(time.strftime("%A, %d. %B %Y %I:%M:%S %p"))
    with scheduler.app.app_context():
        dw_wb = 'CURRENT 2020-2021 Detainer Warrants'
        judgement_wb = 'GS Dockets (Starting March 15)'
        key = scheduler.app.config['GOOGLE_ACCOUNT_PATH']
        detainer_warrants.imports.from_workbook(
            dw_wb, service_account_key=key)
        detainer_warrants.judgement_imports.from_dw_wb(
            dw_wb, service_account_key=key)
        detainer_warrants.judgement_imports.from_workbook(
            judgement_wb, service_account_key=key)


@scheduler.task(IntervalTrigger(minutes=65), id='export')
def export():
    print('Exporting to google sheets')
    print(time.strftime("%A, %d. %B %Y %I:%M:%S %p"))
    with scheduler.app.app_context():
        workbook_name = 'Website Export'
        key = scheduler.app.config['GOOGLE_ACCOUNT_PATH']
        detainer_warrants.exports.to_spreadsheet(workbook_name, key)
        detainer_warrants.exports.to_judgement_sheet(workbook_name, key)
        detainer_warrants.exports.to_court_watch_sheet(workbook_name, key)


@scheduler.task(IntervalTrigger(minutes=60), id='sync_with_sessions_site')
def sync_with_sessions_site():
    print('Syncing with sessions site:')
    print(time.strftime("%A, %d. %B %Y %I:%M:%S %p"))
    with scheduler.app.app_context():
        detainer_warrants.judgement_scraping.scrape_entire_site()
