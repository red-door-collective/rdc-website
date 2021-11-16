from flask import current_app
from selenium import webdriver
from selenium.common.exceptions import ElementNotInteractableException, StaleElementReferenceException
from selenium.webdriver.common.action_chains import ActionChains
from selenium.webdriver.support.wait import WebDriverWait
import selenium.webdriver.support.expected_conditions as EC
from selenium.webdriver.common.by import By
from selenium.webdriver.common.keys import Keys
from sqlalchemy import and_
import time
import os
import re
import time
from ..util import get_or_create
from ..models import db, PleadingDocument, DetainerWarrant
from .constants import ids, names
from .common import login, search, run_with_chrome
import eviction_tracker.config as config
import logging
import logging.config
import traceback

logging.config.dictConfig(config.LOGGING)
logger = logging.getLogger(__name__)


def import_from_dw_page(browser, docket_id):
    browser.switch_to.frame(ids.POSTBACK_FRAME)

    script_tag = browser.find_element(By.XPATH, "/html")
    postback_HTML = script_tag.get_attribute('outerHTML')

    documents_regex = re.compile(
        r'\,\s*"ý(https://caselinkimages.nashville.gov.+?)ý+"\,')

    match = documents_regex.search(postback_HTML)
    if not match:
        logger.info(f'postback HTML: {postback_HTML}')
        return

    urls_mess = match.group(1)
    urls = [url for url in urls_mess.split('ý') if url != '']

    created_count = 0
    for url in urls:
        document, was_created = get_or_create(
            db.session, PleadingDocument, url=url, docket_id=docket_id)
        if was_created:
            created_count += 1

    db.session.commit()

    logger.info(f'created {created_count} pleading documents for {docket_id}')

    browser.switch_to.default_content()
    browser.switch_to.frame(ids.UPDATE_FRAME)


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

            import_from_dw_page(browser, docket_id)

            browser.find_element(By.NAME, names.NEW_SEARCH_BUTTON).click()
        except:
            logger.error(
                f'failed to gather documents for {docket_id}. Exception: {traceback.format_exc()}')
            login(browser)  # just keep swimming...


def update_pending_warrants():
    queue = db.session.query(DetainerWarrant.docket_id).filter(and_(
        DetainerWarrant.docket_id.ilike('%GT%'),
        DetainerWarrant.status == 'PENDING'
    ))
    bulk_import_documents(queue)
