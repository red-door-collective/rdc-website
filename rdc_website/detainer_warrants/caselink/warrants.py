from flask import current_app
from .navigation import Navigation
import requests
import re
import re
import requests
import rdc_website.config as config
import logging
import logging.config
from datetime import datetime
from .. import csv_imports

logging.config.dictConfig(config.LOGGING)
logger = logging.getLogger(__name__)

CSV_URL_REGEX = re.compile(r'parent.UserWinOpen\("", "(https:\/\/.+?)",')


def import_from_caselink(start_date, end_date):
    csv_imports.from_url(fetch_csv_url(start_date, end_date))


def fetch_csv_url(start_date, end_date):
    logger.info(f"Importing caselink warrants between {start_date} and {end_date}")

    username = current_app.config["CASELINK_USERNAME"]
    password = current_app.config["CASELINK_PASSWORD"]

    search_page = Navigation.login(username, password)
    resp = search_page.follow_url()
    heart = search_page.heartbeat()
    menu_resp = search_page.menu()
    menu_postback_resp = Navigation.from_response(menu_resp).follow_url()
    read_rec_resp = search_page.read_rec()
    open_advanced_search_resp = search_page.open_advanced_search()
    start_date_resp = search_page.add_start_date(start_date)
    warrant_type_resp = search_page.add_detainer_warrant_type()
    results_page = search_page.search()

    # navigate to search results
    # headers = {"Referer": WEBSHELL, "Sec-Fetch-Dest": "iframe"}

    csv_response = results_page.export_csv()
    breakpoint()
    return extract_csv_url(csv_response)


def extract_csv_url(csv_response):
    url = re.search(CSV_URL_REGEX, csv_response.text).groups()[0]

    if "caselink.nashville.org" in url:
        return url.replace("caselink.nashville.org", "caselink.nashville.gov")

    logger.warning("CSV URL has changed; potentially valid. Remove old code.")
    return url
