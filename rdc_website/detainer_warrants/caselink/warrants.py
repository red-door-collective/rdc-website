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


def import_from_caselink(start_date, end_date):
    csv_imports.from_url(fetch_csv_url(start_date, end_date))


def fetch_csv_url(start_date, end_date):
    logger.info(f"Importing caselink warrants between {start_date} and {end_date}")

    username = current_app.config["CASELINK_USERNAME"]
    password = current_app.config["CASELINK_PASSWORD"]

    search_page = Navigation.login(username, password)
    search_page.add_start_date(start_date)
    search_page.add_detainer_warrant_type()
    search_response = search_page.search()

    # navigate to search results
    # headers = {"Referer": WEBSHELL, "Sec-Fetch-Dest": "iframe"}

    results_page = Navigation.from_response(search_response).follow_url()
    csv_html_response = results_page.export_csv()
    csv_page = Navigation.from_response(csv_html_response)

    url = csv_page.url()

    if "caselink.org" in url:
        return url.replace("caselink.org", "caselink.gov")

    logger.warning("CSV URL has changed; potentially valid. Remove old code.")
    return url
