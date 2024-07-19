from flask import current_app
from .navigation import Navigation
import re
from datetime import datetime, UTC
from .. import csv_imports
from ..models import db, DetainerWarrant, PleadingDocument
from .utils import log_response
from loguru import logger

PLEADING_DOCUMENTS_REGEX = re.compile(
    r'parent\.PutMvals\(\s*"P_3"\s*,\s*"([ý\\]*\w+\\+\w+\\+\w+\\+\w+\\+\d+\.pdf.+)"'
)
PLEADING_DOC_REGEX = re.compile(
    r'"\s*(\\+Public\\+Sessions\\+24\\+24GT4771\\+3363356\.pdf)\s*"'
)
OPEN_CASE_REGEX = re.compile(
    r'parent\.UserCallProcess\("(?P<process>.+?)",\s*"(?P<docket_id>\d+\w+\d+)",\s*.+?[\'"]+(?P<dev_path>\/.+)[\'"]+,\s*[\'"]self[\'"]'
)


def from_case_detail_page(docket_id, full_case_page, log=None):
    # logger.info("Scraping pleading documents for Docket ID: {docket_id}", docket_id)

    full_case_page_response = full_case_page.follow_url()

    pleading_doc_response = full_case_page.open_pleading_document_redirect(docket_id)

    if log is not None:
        log.append(log_response("pleading_doc", pleading_doc_response))

    image_paths = extract_pleading_document_paths(full_case_page_response.text)

    return populate_pleadings(docket_id, image_paths)


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
        document = db.session.get(PleadingDocument, image_path)
        if document:
            seen_count += 1
        else:
            created_count += 1
            PleadingDocument.create(image_path=image_path, docket_id=docket_id)

    detainer_warrant = DetainerWarrant.query.get(docket_id).update(
        _last_pleading_documents_check=datetime.now(UTC),
        pleading_document_check_mismatched_html=None,
        pleading_document_check_was_successful=True,
    )

    db.session.commit()
    return detainer_warrant


def extract_case_details(open_case_html):
    return re.search(OPEN_CASE_REGEX, open_case_html)
