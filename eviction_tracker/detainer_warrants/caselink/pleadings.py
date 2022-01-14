from flask import current_app
from selenium import webdriver
from selenium.common.exceptions import ElementNotInteractableException, StaleElementReferenceException, TimeoutException
from selenium.webdriver.common.action_chains import ActionChains
from selenium.webdriver.support.wait import WebDriverWait
import selenium.webdriver.support.expected_conditions as EC
from selenium.webdriver.common.by import By
from selenium.webdriver.common.keys import Keys
from sqlalchemy import and_, or_
from sqlalchemy import Date, cast
import time
import os
import re
import time
from ...util import get_or_create, file_date_guess
from ..models import db, PleadingDocument, Hearing, DetainerWarrant, Judgment
from .constants import ids, names
from .common import login, search, run_with_chrome
import eviction_tracker.config as config
import logging
import logging.config
import traceback
from datetime import datetime, date, timedelta, time
from pdfminer.layout import LAParams
from pdfminer.high_level import extract_pages, extract_text_to_fp
import requests
import io
from ..judgments import regexes
import usaddress

logging.config.dictConfig(config.LOGGING)
logger = logging.getLogger(__name__)

CONTINUANCE_REGEX = re.compile(r'COURT\s+DATE\s+CONTINUANCE\s+(\d+\.\d+\.\d+)')
HEARING_REGEX = re.compile(r'COURT\s+DATE\s+(\d+\.\d+\.\d+)')
DOCUMENTS_REGEX = re.compile(
    r'\,\s*"ý*(https://caselinkimages\.nashville\.gov.+?\.pdf)ý*"')
STALE_HTML_REGEX = re.compile(
    r'<title>\s*CaseLink\s*Public\s*Inquiry\s*</title>')


def is_between(begin_date, end_date, check_date=None):
    check_time = check_date or date.today()
    return check_date >= begin_date and check_date <= end_date


def date_from_str(some_str, format):
    return datetime.strptime(some_str, format)


def import_from_postback_html(html):
    return DOCUMENTS_REGEX.search(html)


def populate_pleadings(docket_id, documents_match):
    urls_mess = documents_match.group(1)
    urls = [url for url in urls_mess.split('ý') if url != '']

    created_count, seen_count = 0, 0
    for url in urls:
        document = PleadingDocument.query.get(url)
        if document:
            seen_count += 1
        else:
            created_count += 1
            PleadingDocument.create(url=url, docket_id=docket_id)

    logger.info(
        f'{docket_id}: created {created_count}, seen {seen_count} pleading documents')

    DetainerWarrant.query.get(docket_id).update(
        _last_pleading_documents_check=datetime.utcnow(),
        pleading_document_check_mismatched_html=None,
        pleading_document_check_was_successful=True
    )
    db.session.commit()


def import_from_dw_page(browser, docket_id):
    postback_HTML = None

    try:
        browser.switch_to.frame(ids.POSTBACK_FRAME)

        documents_match = None
        for attempt_number in range(4):
            script_tag = browser.find_element(By.XPATH, "/html")
            postback_HTML = script_tag.get_attribute('outerHTML')
            documents_match = import_from_postback_html(postback_HTML)
            if documents_match:
                break
            else:
                time.sleep(.5)

        populate_pleadings(docket_id, documents_match)

        browser.switch_to.default_content()
        browser.switch_to.frame(ids.UPDATE_FRAME)

        pleading_dates = WebDriverWait(browser, 2).until(
            EC.visibility_of_all_elements_located(
                (By.XPATH, '//*[@id="GRIDTBL_1A"]/tbody/tr[*]/td[2]/input'))
        )
        pleading_descriptions = WebDriverWait(browser, 2).until(
            EC.visibility_of_all_elements_located(
                (By.XPATH, '//*[@id="GRIDTBL_1A"]/tbody/tr[*]/td[3]/input'))
        )

        for pleading_date_el, pleading_description_el in zip(pleading_dates, pleading_descriptions):
            pleading_date_str = pleading_date_el.get_attribute('value')
            pleading_description = pleading_description_el.get_attribute(
                'value')
            continuance_match = CONTINUANCE_REGEX.search(pleading_description)
            hearing_match = HEARING_REGEX.search(pleading_description)
            if continuance_match:
                hearing_date = date_from_str(pleading_date_str, '%m/%d/%Y')
                continuance_date = date_from_str(
                    continuance_match.group(1), '%m.%d.%y')
                existing_hearing = Hearing.query.filter(
                    Hearing.docket_id == docket_id,
                    cast(Hearing._court_date, Date) == pleading_date
                ).first()
                if existing_hearing:
                    existing_hearing.update(_continuance_on=continuance_date)
                else:
                    Hearing.create(_court_date=pleading_date, docket_id=docket_id,
                                   address="unknown", _continuance_on=continuance_date)
                db.session.commit()

            elif hearing_match:
                hearing_date = date_from_str(
                    hearing_match.group(1), '%m.%d.%y')
                existing_hearing = Hearing.query.filter(
                    Hearing.docket_id == docket_id,
                    cast(Hearing._court_date, Date) == hearing_date
                ).first()
                if not existing_hearing:
                    Hearing.create(docket_id=docket_id,
                                   _court_date=hearing_date, address="unknown")
                db.session.commit()

    finally:
        return postback_HTML


@run_with_chrome
def import_documents(browser, docket_id):
    login(browser)

    search_for_warrant(browser, docket_id)


def search_for_warrant(browser, docket_id):
    for attempt in range(4):
        try:
            docket_search = browser.find_element(
                By.NAME, names.DOCKET_NUMBER_INPUT)
            docket_search.send_keys(docket_id)
            break
        except ElementNotInteractableException:
            WebDriverWait(browser, 1).until(EC.staleness_of(docket_search))
            WebDriverWait(browser, 1)\
                .until(EC.element_to_be_clickable((By.NAME, names.DOCKET_NUMBER_INPUT)))
            time.sleep(.5)

    search(browser)

    return import_from_dw_page(browser, docket_id)


def in_between(now, start, end):
    if start <= end:
        return start <= now < end
    else:
        return start <= now or now < end


@run_with_chrome
def bulk_import_documents(browser, docket_ids, cancel_during_working_hours=False):
    logger.info(f'checking {len(docket_ids)} dockets')

    postback_HTML = None

    for index, docket_id in enumerate(docket_ids):
        if cancel_during_working_hours and in_between(datetime.now(), time(8), time(22)):
            return

        login(browser)

        try:
            postback_HTML = search_for_warrant(browser, docket_id)

        except:
            logger.warning(
                f'failed to gather documents for {docket_id}. Exception: {traceback.format_exc()}')
            DetainerWarrant.query.get(docket_id).update(
                _last_pleading_documents_check=datetime.utcnow(),
                pleading_document_check_mismatched_html=postback_HTML,
                pleading_document_check_was_successful=False
            )
            db.session.commit()


def parse_mismatched_html():
    queue = DetainerWarrant.query.filter(
        DetainerWarrant.pleading_document_check_mismatched_html != None
    )

    logger.info(f're-parsing {queue.count} detainer warrants')

    for dw in queue:
        logger.info(f're-parsing docket #: {dw.docket_id}')
        html = dw.pleading_document_check_mismatched_html.replace(
            '\n', ' ').replace('\r', ' ')
        staleness_match = STALE_HTML_REGEX.search(html)

        if staleness_match or 'Search for Case(s)' in html or 'LVP.MAIN_POSTREAD' in html or 'TktAlert' in html:
            dw.update(pleading_document_check_mismatched_html=None)
        else:
            populate_pleadings(dw.docket_id, import_from_postback_html(html))


def update_pending_warrants():
    current_time = datetime.utcnow()

    two_days_ago = current_time - timedelta(days=2)

    queue = db.session.query(DetainerWarrant.docket_id)\
        .order_by(DetainerWarrant._file_date.desc())\
        .filter(and_(
            DetainerWarrant.status == 'PENDING',
            or_(
                DetainerWarrant._last_pleading_documents_check == None,
                DetainerWarrant._last_pleading_documents_check < two_days_ago
            )
        ))
    bulk_import_documents([id[0] for id in queue],
                          cancel_during_working_hours=True)


PARSE_PARAMS = LAParams(
    all_texts=True,
    boxes_flow=0.5,
    line_margin=0.5,
    word_margin=0.1,
    char_margin=2.0,
    detect_vertical=False
)


def extract_text_from_pdf(pdf):
    output_string = io.StringIO()

    extract_text_to_fp(pdf, output_string, laparams=PARSE_PARAMS,
                       output_type='text', codec=None)

    return output_string.getvalue().strip()


def extract_text_from_document(document):
    try:
        response = requests.get(document.url)
        pdf_memory_file = io.BytesIO()
        pdf_memory_file.write(response.content)
        text = extract_text_from_pdf(pdf_memory_file)
        detainer_warrant_doc_match = regexes.DETAINER_WARRANT_DOCUMENT.search(
            text)

        kind = None
        if detainer_warrant_doc_match:
            kind = 'DETAINER_WARRANT'
        elif 'Other terms of this Order, if any, are as follows' in text:
            kind = 'JUDGMENT'

        document.update(text=text, kind=kind)
        db.session.commit()
    except:
        logger.warning(
            f'Could not extract text for docket # {document.docket_id}, {document.url}. Exception: {traceback.format_exc()}')
        document.update(status="FAILED_TO_EXTRACT_TEXT")
        db.session.commit()

    if document.kind == 'DETAINER_WARRANT':
        update_detainer_warrant_from_document(document)
    elif document.kind == 'JUDGMENT':
        update_judgment_from_document(document)


def bulk_extract_pleading_document_details():
    queue = PleadingDocument.query.filter(
        PleadingDocument.text == None,
        PleadingDocument.status == None
    )
    for document in queue:
        extract_text_from_document(document)


def extract_all_pleading_document_details():
    for document in PleadingDocument.query:
        extract_text_from_document(document)


def retry_detainer_warrant_extraction():
    for document in PleadingDocument.query.filter(PleadingDocument.text.ilike('%detaining%')):
        extract_text_from_document(document)


IMPORTANT_PIECES = ['AddressNumber', 'StreetName',
                    'PlaceName', 'StateName', 'ZipCode']


def get_address(text):
    for line in text.split('\n'):
        potential = line.strip()
        try:
            pieces, labels = usaddress.tag(potential)
            valid = all([pieces.get(piece) for piece in IMPORTANT_PIECES])
            if valid:
                return potential
            else:
                continue
        except:
            continue


def update_detainer_warrant_from_document(document):
    try:
        text = document.text
        file_date = file_date_guess(text)
        if not file_date:
            logger.warning(f'could not guess file date for {document.url}')
            return

        detainer_warrant = DetainerWarrant.query.get(document.docket_id)

        address = get_address(text)
        if address:
            detainer_warrant.update(address=address, document_url=document.url)
            db.session.commit()
        else:
            logger.warning(
                f'could not find address in detainer warrant: {document.url}')
    except:
        logger.warning(
            f'failed update detainer warrant {document.docket_id} for {document.url}. Exception: {traceback.format_exc()}')
        document.update(status='FAILED_TO_UPDATE_DETAINER_WARRANT')
        db.session.commit()


def update_judgment_from_document(document):
    try:
        text = document.text
        file_date = file_date_guess(text)
        if not file_date:
            logger.warning(f'could not guess file date for {document.url}')
            return

        existing_hearing = Hearing.query.filter(
            and_(
                Hearing._court_date >= file_date -
                timedelta(days=3),
                Hearing.docket_id == document.docket_id,
            )).first()

        if existing_hearing:
            existing_hearing.update_judgment_from_document(document)
        else:
            hearing = Hearing.create(
                _court_date=file_date, docket_id=document.docket_id, address="unknown")
            hearing.update_judgment_from_document(document)
        db.session.commit()

    except:
        logger.warning(
            f'failed update judgment {document.docket_id} for {document.url}. Exception: {traceback.format_exc()}')
        document.update(status='FAILED_TO_UPDATE_JUDGMENT')
        db.session.commit()


def update_judgments_from_documents():
    queue = PleadingDocument.query.filter(and_(
        PleadingDocument.kind == 'JUDGMENT',
        PleadingDocument.text != None
    ))
    for document in queue:
        update_judgment_from_document(document)
