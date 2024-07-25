from flask import current_app
from .navigation import Navigation
import re
from datetime import datetime, timedelta, UTC
from .. import csv_imports
from ..models import db, DetainerWarrant, Defendant
from .utils import save_all_responses, log_response
from ..util import get_or_create
from sqlalchemy.orm.exc import MultipleResultsFound
from sqlalchemy import and_, or_, func
from . import pleadings
from .exceptions import BulkScrapeException
from loguru import logger
from nameparser import HumanName

from tenacity import (
    retry,
    wait_exponential,
    after_log,
    stop_after_attempt,
    before_sleep_log,
)
import logging


CSV_URL_REGEX = re.compile(r'parent.UserWinOpen\("",\s*"(https:\/\/.+?)",')
WC_VARS_VALS_REGEX = re.compile(
    r'parent\.PutFormVar\(\s*"(?P<vars>P_\d+_\d+)"\s*,\s*"(?P<values>\s*.*?)",'
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
DEFENDANT_NAME_REGEX = re.compile(r'"P_211"\s*,\s*"(.*?)"')
DEFENDANT_ADDRESS_REGEX = re.compile(r'"P_212"\s*,\s*"(.*?)"')
DEFENDANT_ADDRESS_LINE_2_REGEX = re.compile(r'"P_213"\s*,\s*"(.*?)"')
CSZ_REGEX = re.compile(r'"P_214"\s*,\s*"(.*?)"')
PHONE_REGEX = re.compile(r'"P_27"\s*,\s*"(.*?)"')


def split_cell_names_and_values(matches):
    """
    Splits the UI table cell names and the table cell values from the combined regex matches.
    """
    return [list(m) for m in zip(*matches)]


def join_with_sep(values):
    return "\x7f".join(values).replace("\x7f\x7f", "\x7f")


def search_response_data_to_formdata(cell_names, cell_values):
    wc_vars, wc_vals = [], []
    for name, value in zip(cell_names, cell_values):
        if "09" in name and value == "":
            continue
        wc_vars.append(name)
        wc_vals.append(value)

    return join_with_sep(wc_vars) + "\x7f", join_with_sep(wc_vals) + "\x7f"


def docket_id_code_item(index):
    return "P_102_{}".format(index)


def open_case_page(docket_id, with_extra_fetches=False):
    search_page = Navigation.login()
    menu_resp = search_page.menu()
    menu_page = Navigation.from_response(menu_resp)
    if with_extra_fetches:
        menu_page_resp = menu_page.follow_url()
        read_rec_resp = menu_page.read_rec()
        r1 = menu_page.search_by_docket_id(docket_id)
        r2 = menu_page.search_by_docket_id_2()
        r3 = menu_page.search_by_docket_id_3(docket_id)
    r4 = menu_page.search_by_docket_id_4(docket_id)
    case_page = Navigation.from_response(r4)
    return case_page


def from_docket_id(docket_id, with_extra_fetches=False, with_pleading_documents=False):
    case_page = open_case_page(docket_id, with_extra_fetches=with_extra_fetches)

    detainer_warrant = scrape_detainer_warrant_info(case_page, docket_id)

    if with_pleading_documents:
        return pleadings.from_case_detail_page(docket_id, case_page)

    return detainer_warrant


def parse_defendant_details(html):
    name = re.search(DEFENDANT_NAME_REGEX, html)
    address = re.search(DEFENDANT_ADDRESS_REGEX, html)
    address_line2 = re.search(DEFENDANT_ADDRESS_LINE_2_REGEX, html)
    csz = re.search(CSZ_REGEX, html)
    phone = re.search(PHONE_REGEX, html)

    full_address = None
    if address:
        full_address = address.group(1)
        if address_line2 and address_line2.group(1) != "":
            full_address += " " + address_line2.group(1)
        if csz and csz.group(1) != "":
            full_address += " " + csz.group(1)

    phone = phone.group(1) if phone else None

    return {"full_name": name.group(1), "address": full_address, "phone": phone}


def create_defendant(docket_id, full_name):
    name = HumanName(full_name.replace("OR ALL OCCUPANTS", ""))

    exists_on_this_docket = DetainerWarrant.query.filter(
        DetainerWarrant.docket_id == docket_id,
        DetainerWarrant._defendants.any(first_name=name.first, last_name=name.last),
    ).first()

    if bool(exists_on_this_docket):
        return exists_on_this_docket.defendants

    if not bool(name.first):
        logger.error("Encountered name without a first name {name}", repr(name))
        return []

    defendant = None
    try:
        defendant, _ = get_or_create(
            db.session,
            Defendant,
            first_name=name.first,
            middle_name=name.middle,
            last_name=name.last,
            suffix=name.suffix,
        )
    except MultipleResultsFound:
        defendant = Defendant.query.filter_by(
            first_name=name.first,
            middle_name=name.middle,
            last_name=name.last,
            suffix=name.suffix,
        ).first()
    return [defendant]


def scrape_detainer_warrant_info(case_page, docket_id):
    """
    Gather case and defendant into from the case page.
    """

    case_page.follow_url()
    defendant_info_response = case_page.additional_defendant_info(docket_id)
    details = parse_defendant_details(defendant_info_response.text)

    detainer_warrant = db.session.get(DetainerWarrant, docket_id)

    if not detainer_warrant:
        detainer_warrant = DetainerWarrant.create(docket_id=docket_id)

    if details["address"]:
        detainer_warrant.update(address=details["address"])

    defendants = create_defendant(docket_id, details["full_name"])

    detainer_warrant.update(
        defendants=[{"id": defendant.id for defendant in defendants}]
    )

    db.session.commit()

    return detainer_warrant


@retry(
    wait=wait_exponential(multiplier=1, min=4, max=10),
    after=after_log(logger, logging.INFO),
    stop=stop_after_attempt(3),
    reraise=True,
)
def scrape_single_row(
    index, case, pages, with_pleading_documents, total_cases=1, log=None
):
    docket_id = case["Docket #"]
    try:
        from_search_results(
            docket_id_code_item(index),
            docket_id,
            pages,
            with_pleading_documents=with_pleading_documents,
            log=log if index == 0 else None,
        )
    except Exception:
        raise BulkScrapeException(docket_id, index, total_cases=total_cases)


def import_from_caselink(
    start_date,
    end_date,
    record=False,
    pending_only=False,
    with_case_details=False,
    with_pleading_documents=False,
):
    try:
        caselink_log = []
        pages = search_between_dates(
            start_date, end_date, log=caselink_log if record else None
        )
        results_response = pages["search_page"].search()
        if record:
            caselink_log.append(log_response("search", results_response))
        if 'self.location="/gsapdfs/' in results_response.text:
            results_response = Navigation.from_response(results_response).follow_url()
        matches = extract_search_response_data(results_response.text)
        cell_names, cell_values = split_cell_names_and_values(matches)
        cases = build_cases_from_parsed_matches(cell_values)
        total_cases = len(cases)

        level_of_detail = ""
        if with_pleading_documents:
            level_of_detail = "with pleading documents"
        elif with_case_details:
            level_of_detail = "with case details"

        logger.info(
            "Scraping {total_cases} cases{level_of_detail}",
            total_cases=total_cases,
            level_of_detail=(" " + level_of_detail if level_of_detail else ""),
        )

        wc_vars, wc_values = search_response_data_to_formdata(cell_names, cell_values)
        pages["cell_names"] = cell_names
        pages["wc_vars"] = wc_vars
        pages["wc_vals"] = wc_values
        search_update_resp = pages["menu_page"].search_update(
            cell_names, wc_vars, wc_values
        )

        if record:
            caselink_log.append(log_response("search_update", search_update_resp))

        csv_imports.from_rows(cases)

        if with_case_details:
            for i, case in enumerate(cases):
                scrape_single_row(
                    i,
                    case,
                    pages,
                    with_pleading_documents,
                    total_cases=total_cases,
                    log=caselink_log if record else None,
                )

        if record:
            record_imports_in_dev(caselink_log)
    except BulkScrapeException as e:
        logger.exception("Bulk Scrape of CaseLink terminated")
    except Exception:
        logger.exception("Bulk Scrape of CaseLink terminated")
    finally:
        record_imports_in_dev(caselink_log)


def from_search_results(
    code_item, docket_id, pages, with_pleading_documents=False, log=None
):
    search_results_page = pages["search_page"]
    open_case_response = pages["menu_page"].open_case(
        code_item, docket_id, pages["cell_names"]
    )
    if log is not None:
        log.append(log_response("open_case", open_case_response))

    case_page = Navigation.from_response(open_case_response)
    case_page_response = case_page.follow_url()
    # unsure if necessary. monitor collection
    # case_details = extract_case_details(case_page_response.text)

    scrape_detainer_warrant_info(case_page, docket_id)

    open_case_redirect_response = search_results_page.open_case_redirect(docket_id)
    if log is not None:
        log.append(log_response("open_case_redirect", open_case_redirect_response))

    full_case_page = Navigation.from_response(open_case_redirect_response)

    if with_pleading_documents:
        pleadings.from_case_detail_page(docket_id, full_case_page, log=log)


def record_imports_in_dev(caselink_log):
    if current_app.config["ENV"] == "development":
        save_all_responses(caselink_log)


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


def search_between_dates(start_date, end_date, log=None):
    logger.info(f"Searching for caselink warrants between {start_date} and {end_date}")

    search_page = Navigation.login(log=log)
    menu_resp = search_page.menu()
    menu_page = Navigation.from_response(menu_resp)
    # menu_page_resp = menu_page.follow_url()
    read_rec_resp = menu_page.read_rec()
    add_start_date_resp = menu_page.add_start_date(start_date)
    add_dw_resp = menu_page.add_detainer_warrant_type(end_date)

    if log is not None:
        log.append(log_response("menu", menu_resp))
        log.append(log_response("read_rec", read_rec_resp))
        log.append(log_response("add_start_date", add_start_date_resp))
        log.append(log_response("add_dw", add_dw_resp))

    return {"menu_page": menu_page, "search_page": menu_page}


def extract_case_number(image_path):
    parts = image_path.split("\\")

    second_last = parts[-2]

    return re.sub(r"^\d+/+", "", second_last)


def view_pleading_document(image_path):
    search_page = Navigation.login()

    docket_id = extract_case_number(image_path)

    view_pdf_response = search_page.view_pdf(image_path)

    with open("/tmp/{}.pdf".format(docket_id), "wb") as f:
        f.write(view_pdf_response.content)


def try_with_extra_fetches(retry_state):
    """return the result of the last call attempt"""
    return retry_state.fn(
        *retry_state.args, **retry_state.kwargs, with_extra_fetches=True
    )


@retry(
    wait=wait_exponential(multiplier=1, min=4, max=10),
    before_sleep=before_sleep_log(logger, logging.INFO),
    after=after_log(logger, logging.INFO),
    stop=stop_after_attempt(3),
    reraise=True,
    retry_error_callback=try_with_extra_fetches,
)
def case_by_case_helper(
    index,
    total_cases,
    docket_id,
    with_extra_fetches=False,
    with_pleading_documents=False,
):
    try:
        from_docket_id(
            docket_id,
            with_extra_fetches=with_extra_fetches,
            with_pleading_documents=with_pleading_documents,
        )
    except Exception:
        raise BulkScrapeException(docket_id, index, total_cases=total_cases)


def case_by_case(
    start_date,
    end_date,
    pending_only=False,
    with_pleading_documents=False,
):
    docket_ids = docket_ids_between_dates(
        start_date, end_date, pending_only=pending_only
    )
    total_cases = docket_ids.count()

    logger.info(f"Scraping caselink warrants between {start_date} and {end_date}")

    for index, selection in enumerate(docket_ids):
        try:
            case_by_case_helper(
                index,
                total_cases,
                selection[0],
                with_pleading_documents=with_pleading_documents,
            )
        except BulkScrapeException:
            continue


def docket_ids_between_dates(start_date, end_date, pending_only=False):
    current_time = datetime.now(UTC)
    two_days_ago = current_time - timedelta(days=2)
    window = [
        func.date(DetainerWarrant.file_date) <= end_date,
        func.date(DetainerWarrant.file_date) >= start_date,
    ]
    last_run = [
        DetainerWarrant._last_pleading_documents_check == None,
        DetainerWarrant._last_pleading_documents_check < two_days_ago,
    ]

    # PENDING (bug with current "status" field)
    pending = [DetainerWarrant.status_id == 1]

    required_filters = window
    if pending_only:
        required_filters.append(pending)

    return (
        db.session.query(DetainerWarrant.docket_id)
        .order_by(DetainerWarrant._file_date.desc())
        .filter(
            and_(
                *required_filters,
                or_(*last_run),
            )
        )
    )
