import time
from datetime import datetime, date, timedelta

import eviction_tracker.detainer_warrants as detainer_warrants
from eviction_tracker.extensions import scheduler


@scheduler.task('interval', id='import_warrants', minutes=60)
def import_warrants():
    print('Importing from google sheets')
    print(time.strftime("%A, %d. %B %Y %I:%M:%S %p"))
    with scheduler.app.app_context():
        dw_wb = 'CURRENT 2020-2021 Detainer Warrants'
        judgement_wb = 'GS Dockets (Starting March 15)'
        key = '/srv/within/eviction-tracker/google_service_account.json'
        detainer_warrants.imports.from_workbook(
            dw_wb, service_account_key=key)
        detainer_warrants.judgement_imports.from_dw_wb(
            dw_wb, service_account_key=key)
        detainer_warrants.judgement_imports.from_workbook(
            judgement_wb, service_account_key=key)


@scheduler.task('interval', id='export', minutes=60)
def export():
    print('Exporting to google sheets')
    print(time.strftime("%A, %d. %B %Y %I:%M:%S %p"))
    with scheduler.app.app_context():
        sheet = 'Website Export'
        key = '/srv/within/eviction-tracker/google_service_account.json'
        detainer_warrants.exports.to_spreadsheet(sheet, key)
        detainer_warrants.exports.to_judgement_sheet(sheet, key)
        detainer_warrants.exports.to_court_watch_sheet(sheet, key)


@scheduler.task('interval', id='sync_with_sessions_site', minutes=60)
def sync_with_sessions_site():
    print('Syncing with sessions site:')
    print(time.strftime("%A, %d. %B %Y %I:%M:%S %p"))
    with scheduler.app.app_context():
        today = date.today()
        day_delta = timedelta(days=1)
        week = [day_delta * num + today for num in range(4)]
        for day in week:
            date_str = datetime.strftime(day, '%m/%d/%Y')
            print(f'scraping court dates for {date_str}')
            detainer_warrants.judgement_scraping.scrape('1A', date_str)
            detainer_warrants.judgement_scraping.scrape('1B', date_str)
