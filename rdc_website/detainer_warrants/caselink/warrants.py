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
from ..models import db, DetainerWarrant, PleadingDocument

logging.config.dictConfig(config.LOGGING)
logger = logging.getLogger(__name__)

CSV_URL_REGEX = re.compile(r'parent.UserWinOpen\("",\s*"(https:\/\/.+?)",')
WC_VARS_VALS_REGEX = re.compile(
    r'parent\.PutFormVar\(\s*"P_\d+_\d+"\s*,\s*"(?P<values>\s*.*?)",'
)
PLEADING_DOCUMENTS_REGEX = re.compile(
    r'parent\.PutMvals\(\s*"P_3"\s*,\s*"([ý\\]*\w+\\+\w+\\+\w+\\+\w+\\+\d+\.pdf.+)"'
)
PLAINTIFF_ATTORNEY = "Pltf. Attorney"
COLUMNS = [
    "Office",
    "Docket #",
    "Status",
    "File Date",
    "Description",
    "Plaintiff",
    "Defendant",
    PLAINTIFF_ATTORNEY,
    "Def. Attorney",
]


def import_from_caselink(start_date, end_date):
    search_results_page = search_between_dates(start_date, end_date)
    results_response = search_results_page.follow_url()
    cases = build_cases_from_parsed_matches(
        extract_search_response_data(results_response.text)
    )

    breakpoint()

    # csv_imports.from_rows(cases)

    # TODO: do this for each case in the search
    pleading_document_urls = import_pleading_documents(search_results_page)

    return pleading_document_urls


def extract_pleading_document_paths(html):
    escaped_paths = re.search(PLEADING_DOCUMENTS_REGEX, html).group(1)
    trimmed_paths = escaped_paths.strip("ý").split(".pdf")

    paths = [
        path.strip("ý").replace("\\\\\\\\", "\\") + ".pdf"
        for path in trimmed_paths
        if path
    ]

    return paths


def populate_pleadings(docket_id, image_paths):
    created_count, seen_count = 0, 0
    for image_path in image_paths:
        document = PleadingDocument.query.get(image_path)
        if document:
            seen_count += 1
        else:
            created_count += 1
            PleadingDocument.create(image_path=image_path, docket_id=docket_id)

    DetainerWarrant.query.get(docket_id).update(
        _last_pleading_documents_check=datetime.utcnow(),
        pleading_document_check_mismatched_html=None,
        pleading_document_check_was_successful=True,
    )

    db.session.commit()


def import_pleading_documents(search_results_page):
    search_results_page.open_case()
    case_page = search_results_page.open_case_redirect()
    case_page.follow_link()

    pleading_doc_page = case_page.open_pleading_document_redirect()

    pleading_documents = pleading_doc_page.follow_url()

    paths = extract_pleading_document_paths(pleading_documents.text)

    for path in paths:
        PleadingDocument.create()

    return paths


def build_cases_from_parsed_matches(matches):
    cases = list(divide_into_dicts(COLUMNS, matches, 9))
    for case in cases:
        if case[PLAINTIFF_ATTORNEY] == ", PRS":
            case[PLAINTIFF_ATTORNEY] = "REPRESENTING SELF"

    return cases


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

    return menu_page.search()
