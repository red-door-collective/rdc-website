from flask import current_app
from selenium import webdriver
from selenium.common.exceptions import ElementNotInteractableException, StaleElementReferenceException
from selenium.webdriver.common.action_chains import ActionChains
from selenium.webdriver.support.wait import WebDriverWait
import selenium.webdriver.support.expected_conditions as EC
from selenium.webdriver.common.by import By
from selenium.webdriver.common.keys import Keys
from sqlalchemy import and_, or_
import time
import os
import re
import time
from ..util import get_or_create
from ..models import db, PleadingDocument, Hearing, DetainerWarrant, Judgment
from .constants import ids, names
from .common import login, search, run_with_chrome
import eviction_tracker.config as config
import logging
import logging.config
import traceback
from datetime import datetime, date, timedelta
from pdfminer.high_level import extract_pages, extract_text
import requests
import io

logging.config.dictConfig(config.LOGGING)
logger = logging.getLogger(__name__)


def is_between(begin_date, end_date, check_date=None):
    check_time = check_date or date.today()
    return check_date >= begin_date and check_date <= end_date


def import_from_dw_page(browser, docket_id):
    postback_HTML = None

    try:
        browser.switch_to.frame(ids.POSTBACK_FRAME)

        script_tag = browser.find_element(By.XPATH, "/html")
        postback_HTML = script_tag.get_attribute('outerHTML')

        documents_regex = re.compile(
            r'\,\s*"ý(https://caselinkimages.nashville.gov.+?\.pdf)ý*"')

        urls_mess = documents_regex.search(postback_HTML).group(1)
        urls = [url for url in urls_mess.split('ý') if url != '']

        created_count = 0
        for url in urls:
            document, was_created = get_or_create(
                db.session, PleadingDocument, url=url, docket_id=docket_id)
            if was_created:
                created_count += 1

        DetainerWarrant.query.get(docket_id).update(
            _last_pleading_documents_check=datetime.utcnow(),
            pleading_document_check_mismatched_html=None,
            pleading_document_check_was_successful=True
        )
        db.session.commit()

        logger.info(
            f'created {created_count} pleading documents for {docket_id}')

        browser.switch_to.default_content()
        browser.switch_to.frame(ids.UPDATE_FRAME)
    finally:
        return postback_HTML


@run_with_chrome
def import_documents(browser, docket_id):
    login(browser)

    docket_search = WebDriverWait(browser, 5, ignored_exceptions=[ElementNotInteractableException]).until(
        EC.element_to_be_clickable((By.NAME, names.DOCKET_NUMBER_INPUT))
    )

    docket_search.send_keys(docket_id)

    search(browser)

    time.sleep(3)

    import_from_dw_page(browser, docket_id)


@run_with_chrome
def bulk_import_documents(browser, docket_ids):
    login(browser)

    logger.info(f'checking {len(docket_ids)} dockets')

    postback_HTML = None

    for docket_id in docket_ids:
        try:
            time.sleep(3)

            docket_search = WebDriverWait(browser, 5).until(
                EC.element_to_be_clickable(
                    (By.NAME, names.DOCKET_NUMBER_INPUT))
            )

            docket_search.send_keys(docket_id)

            search(browser)

            time.sleep(3)

            postback_HTML = import_from_dw_page(browser, docket_id)

            WebDriverWait(browser, 5).until(
                EC.element_to_be_clickable(
                    (By.NAME, names.NEW_SEARCH_BUTTON)
                )
            ).click()
        except:
            logger.error(
                f'failed to gather documents for {docket_id}. Exception: {traceback.format_exc()}')
            DetainerWarrant.query.get(docket_id).update(
                _last_pleading_documents_check=datetime.utcnow(),
                pleading_document_check_mismatched_html=postback_HTML,
                pleading_document_check_was_successful=False
            )
            db.session.commit()
            login(browser)  # just keep swimming...


def update_pending_warrants():
    current_time = datetime.utcnow()

    three_days_ago = current_time - timedelta(days=3)

    queue = db.session.query(DetainerWarrant.docket_id).filter(and_(
        DetainerWarrant.status == 'PENDING',
        or_(
            DetainerWarrant._last_pleading_documents_check == None,
            DetainerWarrant._judgments.any(
                DetainerWarrant._last_pleading_documents_check < Judgment._court_date
            )
        ),
        or_(
            DetainerWarrant._last_pleading_documents_check == None,
            DetainerWarrant._last_pleading_documents_check < three_days_ago
        )
    ))
    bulk_import_documents([id[0] for id in queue])


def extract_text_from_pdf(file_name):
    output_string = ''
    with open(file_name, 'rb') as fin:
        output_string = extract_text(fin)

    return output_string.strip()


def extract_text_from_document(document):
    try:
        response = requests.get(document.url)
        pdf_memory_file = io.BytesIO()
        pdf_memory_file.write(response.content)
        text = extract_text(pdf_memory_file)
        kind = None
        if 'Other terms of this Order, if any, are as follows' in text:
            kind = 'JUDGMENT'
            update_judgment_from_document(document)
        document.update(text=text, kind=kind)
        db.session.commit()

    except:
        logger.warning(
            f'Could not extract text for docket # {document.docket_id}, {document.url}. Exception: {traceback.format_exc()}')
        document.update(text="FAILED_TO_PARSE_JUDGMENT")
        db.session.commit()


def bulk_extract_pleading_document_details():
    queue = PleadingDocument.query.filter(
        PleadingDocument.text == None
    )
    for document in queue:
        extract_text_from_document(document)


def update_judgment_from_document(document):
    if document.kind == 'JUDGMENT' and document.text:
        text = document.text
        file_date = Judgment.file_date_guess(text)
        existing_hearing = Hearing.query.filter(
            and_(
                Hearing._court_date >= file_date -
                timedelta(days=3),
                Hearing.docket_id == document.docket_id,
            )).first()

        if existing_hearing:
            existing_hearing.update_judgment_from_document(document)
        else:
            logger.warning(
                f"Could not match {document.url} with existing hearing.")


def update_judgments_from_documents():
    queue = PleadingDocument.query.filter(and_(
        PleadingDocument.kind == 'JUDGMENT',
        PleadingDocument.text != None
    ))
    for document in queue:
        update_judgment_from_document(document)
