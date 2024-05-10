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

CSV_URL_REGEX = re.compile(r'parent.UserWinOpen\("",\s*"(https:\/\/.+?)",')
WC_VARS_VALS_REGEX = re.compile(
    r'parent\.PutFormVar\(\s*"(?P<vars>P_\d+_\d+)"\s*,\s*"(?P<values>\s*.*?)",'
)
COLUMNS = [
    "Office",
    "Docket #",
    "Status",
    "File Date",
    "Description",
    "Plaintiff",
    "Pltf. Attorney",
    "Defendant",
    "Def. Attorney",
]


def import_from_caselink(start_date, end_date):
    csv_imports.from_rows(search_between_dates(start_date, end_date))


def extract_search_response_data(search_results):
    return re.findall(WC_VARS_VALS_REGEX, search_results)


def divide_into_dicts(h, l, n):
    for i in range(0, len(l), n):
        yield {h[(i + ind) % n]: v for ind, v in enumerate(l[i : i + n])}


def search_between_dates(start_date, end_date):
    logger.info(f"Importing caselink warrants between {start_date} and {end_date}")

    username = current_app.config["CASELINK_USERNAME"]
    password = current_app.config["CASELINK_PASSWORD"]

    search_page = Navigation.login(username, password)
    menu_resp = search_page.menu()
    menu_page = Navigation.from_response(menu_resp)
    menu_page.add_start_date(start_date)
    menu_page.add_detainer_warrant_type(end_date)

    results_page = menu_page.search()
    results_response = results_page.follow_url()
    matches = extract_search_response_data(results_response.text)

    rows = list(divide_into_dicts(COLUMNS, [val for _var, val in matches], 9))

    breakpoint()

    return rows
