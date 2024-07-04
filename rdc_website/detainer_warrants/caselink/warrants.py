from flask import current_app
from .navigation import Navigation
import re
import logging
from datetime import datetime
from .. import csv_imports
from ..models import db, DetainerWarrant, PleadingDocument
from .utils import save_all_responses

logger = logging.getLogger(__name__)

CSV_URL_REGEX = re.compile(r'parent.UserWinOpen\("",\s*"(https:\/\/.+?)",')
WC_VARS_VALS_REGEX = re.compile(
    r'parent\.PutFormVar\(\s*"(?P<vars>P_\d+_\d+)"\s*,\s*"(?P<values>\s*.*?)",'
)
PLEADING_DOCUMENTS_REGEX = re.compile(
    r'parent\.PutMvals\(\s*"P_3"\s*,\s*"([ý\\]*\w+\\+\w+\\+\w+\\+\w+\\+\d+\.pdf.+)"'
)
PLEADING_DOC_REGEX = re.compile(
    r'"\s*(\\+Public\\+Sessions\\+24\\+24GT4771\\+3363356\.pdf)\s*"'
)
OPEN_CASE_REGEX = re.compile(
    r'parent\.UserCallProcess\("(?P<process>.+?)",\s*"(?P<docket_id>\d+\w+\d+)",\s*.+?[\'"]+(?P<dev_path>\/.+)[\'"]+,\s*[\'"]self[\'"]'
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


def import_from_caselink(start_date, end_date, record=False):
    try:
        caselink_log = []
        pages = search_between_dates(start_date, end_date, log=caselink_log)
        results_response = pages["search_page"].search()
        if record:
            caselink_log.append(log_response("search", results_response))
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

        for i, case in enumerate(cases):
            docket_id = case["Docket #"]
            import_pleading_documents(
                docket_id_code_item(i),
                docket_id,
                pages,
                log=caselink_log if i == 0 else None,
            )

        if record:
            record_imports_in_dev(caselink_log)
    except Exception as e:
        record_imports_in_dev(caselink_log)


def record_imports_in_dev(caselink_log):
    if current_app.config["ENV"] == "development":
        save_all_responses(caselink_log)


def extract_case_details(open_case_html):
    return re.search(OPEN_CASE_REGEX, open_case_html)


def extract_pleading_document_paths(html):
    escaped_paths = re.search(PLEADING_DOCUMENTS_REGEX, html).group(1)
    # return escaped_paths.replace("\\\\", "")
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


def import_pleading_documents(code_item, docket_id, pages, log=None):
    search_results_page = pages["search_page"]
    open_case_response = pages["menu_page"].open_case(
        code_item, docket_id, pages["cell_names"]
    )
    if log is not None:
        log.append(log_response("open_case", open_case_response))

    case_page = Navigation.from_response(open_case_response)
    case_page_response = case_page.follow_url()
    # case_details = extract_case_details(case_page_response.text)

    open_case_redirect_response = search_results_page.open_case_redirect(docket_id)
    full_case_page = Navigation.from_response(open_case_redirect_response)
    full_case_page_response = full_case_page.follow_url()

    if log is not None:
        log.append(log_response("open_case_redirect", open_case_redirect_response))

    pleading_doc_response = full_case_page.open_pleading_document_redirect(docket_id)

    if log is not None:
        log.append(log_response("pleading_doc", pleading_doc_response))

    # pleading_doc_page = Navigation.from_response(pleading_doc_response)

    # pleading_documents = pleading_doc_page.follow_url()

    image_paths = extract_pleading_document_paths(full_case_page_response.text)

    populate_pleadings(docket_id, image_paths)


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


def log_response(name, response):
    return {"name": name, "response": response}


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
