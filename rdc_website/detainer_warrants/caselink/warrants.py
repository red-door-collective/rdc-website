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


def search_response_data_to_formdata(matches):
    wc_vars, wc_values = [], []
    for var, value in matches:
        wc_vars.append(var)
        wc_values.append(value)

    return "%7F".join(wc_vars), "%7F".join(wc_values)


def divide_into_dicts(h, l, n):
    for i in range(0, len(l), n):
        yield {h[(i + ind) % n]: v for ind, v in enumerate(l[i : i + n])}


def search_between_dates(start_date, end_date):
    logger.info(f"Importing caselink warrants between {start_date} and {end_date}")

    username = current_app.config["CASELINK_USERNAME"]
    password = current_app.config["CASELINK_PASSWORD"]

    search_page = Navigation.login(username, password)
    resp = search_page.follow_url()
    menu_resp = search_page.menu()
    menu_page = Navigation.from_response(menu_resp)
    menu_page.follow_url()
    read_rec_resp = menu_page.read_rec()
    open_advanced_search_resp = menu_page.open_advanced_search()
    start_date_resp = menu_page.add_start_date(start_date)
    warrant_type_resp = menu_page.add_detainer_warrant_type(end_date)

    results_page = menu_page.search()
    results_response = results_page.follow_url()
    matches = extract_search_response_data(results_response.text)
    # wc_vars, wc_values = search_response_data_to_formdata(matches)
    # search_update_resp = menu_page.search_update(wc_vars, wc_values)

    rows = list(divide_into_dicts(COLUMNS, [val for _var, val in matches], 9))

    breakpoint()

    return rows

    # csv_response = results_page.export_csv()
    # return extract_csv_url(csv_response)


def extract_csv_url(csv_response):
    url = re.search(CSV_URL_REGEX, csv_response.text).groups()[0]

    if "caselink.nashville.org" in url:
        return url.replace("caselink.nashville.org", "caselink.nashville.gov")

    logger.warning("CSV URL has changed; potentially valid. Remove old code.")
    return url
