from flask import current_app
from .navigation import Navigation
import re
from datetime import datetime
from .. import csv_imports
from ..models import db, DetainerWarrant, PleadingDocument, Defendant
from .utils import save_all_responses, log_response
from ..util import get_or_create
from sqlalchemy.orm.exc import MultipleResultsFound

from . import pleadings
from loguru import logger
from nameparser import HumanName

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


def open_case_page(docket_id):
    search_page = Navigation.login()
    menu_resp = search_page.menu()
    menu_page = Navigation.from_response(menu_resp)
    # menu_page_resp = menu_page.follow_url()
    read_rec_resp = menu_page.read_rec()
    r1 = menu_page.search_by_docket_id(docket_id)
    r2 = menu_page.search_by_docket_id_2()
    r3 = menu_page.search_by_docket_id_3(docket_id)
    r4 = menu_page.search_by_docket_id_4(docket_id)
    case_page = Navigation.from_response(r4)
    return case_page


def from_docket_id(docket_id, with_pleading_documents=True):
    case_page = open_case_page(docket_id)

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

    full_name = HumanName(name.group(1))

    full_address = None
    if address:
        full_address = address.group(1)
        if address_line2 and address_line2.group(1) != "":
            full_address += " " + address_line2.group(1)
        if csz and csz.group(1) != "":
            full_address += " " + csz.group(1)

    phone = phone.group(1) if phone else None

    return {"full_name": full_name, "address": full_address, "phone": phone}


def create_defendant(docket_id, full_name):
    name = HumanName(full_name.replace("OR ALL OCCUPANTS", ""))

    exists_on_this_docket = DetainerWarrant.query.filter(
        DetainerWarrant.docket_id == docket_id,
        DetainerWarrant._defendants.any(first_name=name.first, last_name=name.last),
    ).first()

    if bool(exists_on_this_docket):
        return exists_on_this_docket.defendants

    defendant = None
    if bool(name.first):
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
    # case_page_response = case_page.follow_url()

    defendant_info_response = case_page.additional_defendant_info(docket_id)
    details = parse_defendant_details(defendant_info_response.text)
    full_name = details["full_name"]

    detainer_warrant = db.session.get(DetainerWarrant, docket_id)

    if not detainer_warrant:
        detainer_warrant = DetainerWarrant.create(docket_id=docket_id)

    if details["address"]:
        detainer_warrant.update(address=details["address"])

    db.session.add(detainer_warrant)

    existing_defendants = detainer_warrant.defendants

    if existing_defendants:
        num_defendants_updated = 0
        for defendant in existing_defendants:
            if (
                details["first_name"] in defendant.name
                or details["last_name"] in defendant.name
            ):
                defendant.update(
                    first_name=full_name.first,
                    middle_name=full_name.middle,
                    last_name=full_name.last,
                    suffix=full_name.suffix,
                )
            db.session.add(defendant)
            num_defendants_updated += 1

        logger.info(
            "Updated {num_existing_updated} defendants on {docket_id}",
            num_existing_updated=num_defendants_updated,
            docket_id=docket_id,
        )

    else:
        defendant = Defendant.create(
            first_name=full_name.first,
            middle_name=full_name.middle,
            last_name=full_name.last,
            suffix=full_name.suffix,
        )
        db.session.add(defendant)
        logger.info("Created a defendant on {docket_id}", docket_id=docket_id)

        detainer_warrant.update(defendants=[{"id": defendant.id}])

    db.session.commit()

    return detainer_warrant


def import_from_caselink(
    start_date,
    end_date,
    record=False,
    with_case_details=True,
    with_pleading_documents=True,
):
    try:
        caselink_log = []
        pages = search_between_dates(start_date, end_date, log=caselink_log)
        results_response = pages["search_page"].search()
        if record:
            caselink_log.append(log_response("search", results_response))
        if 'self.location="/gsapdfs/' in results_response.text:
            results_response = Navigation.from_response(results_response).follow_url()
        matches = extract_search_response_data(results_response.text)
        cell_names, cell_values = split_cell_names_and_values(matches)
        cases = build_cases_from_parsed_matches(cell_values)

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
            logger.info(
                "Scraping {case_count} cases{level_of_detail}",
                case_count=len(cases),
                level_of_detail=(
                    " with pleading documents" if with_pleading_documents else ""
                ),
            )
            for i, case in enumerate(cases):
                docket_id = case["Docket #"]
                from_search_results(
                    docket_id_code_item(i),
                    docket_id,
                    pages,
                    with_pleading_documents=with_pleading_documents,
                    log=caselink_log if i == 0 else None,
                )

        if record:
            record_imports_in_dev(caselink_log)
    except Exception:
        logger.exception("CaseLink import terminated")
        record_imports_in_dev(caselink_log)


def from_search_results(
    code_item, docket_id, pages, with_pleading_documents=True, log=None
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

    scrape_detainer_warrant_info(case_page)

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
    logger.info(f"Importing caselink warrants between {start_date} and {end_date}")

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
