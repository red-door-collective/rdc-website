from flask import current_app
from selenium import webdriver
from selenium.common.exceptions import ElementNotInteractableException, StaleElementReferenceException
from selenium.webdriver.support.ui import Select
from selenium.webdriver.support.wait import WebDriverWait
import selenium.webdriver.support.expected_conditions as EC
from selenium.webdriver.common.by import By
from selenium.webdriver.common.keys import Keys
import time
import os
import re
import time
from .constants import ids, names, values
from ..util import get_or_create
from ..models import db, PleadingDocument
from .common import login, run_with_chrome, search
from .. import csv_imports
from datetime import date, datetime
import requests
import eviction_tracker.config as config
import logging
import logging.config

logging.config.dictConfig(config.LOGGING)
logger = logging.getLogger(__name__)


def to_date_str(d):
    return datetime.strftime(d, '%m/%d/%Y')


@run_with_chrome
def fetch_csv_link(browser, start_date, end_date):
    login(browser)

    case_type_select = WebDriverWait(browser, 10, ignored_exceptions=[StaleElementReferenceException]).until(
        EC.element_to_be_clickable((By.NAME, names.CASE_TYPE_SELECT))
    )
    time.sleep(1)
    Select(case_type_select).select_by_value(values.CASE_TYPE_DETAINER_WARRANT)

    file_date_start_input = browser.find_element(
        By.NAME, names.FILE_DATE_START_INPUT)
    file_date_end_input = browser.find_element(
        By.NAME, names.FILE_DATE_END_INPUT)

    file_date_start_input.send_keys(to_date_str(start_date))
    file_date_end_input.send_keys(to_date_str(end_date))

    search(browser)

    export_button = WebDriverWait(browser, 20).until(
        EC.element_to_be_clickable((By.NAME, names.EXPORT_BUTTON))
    )

    logger.info('Found export button, clicking...')

    export_button.click()

    time.sleep(5)

    browser.switch_to.frame(ids.POSTBACK_FRAME)

    script_tag = browser.find_element(By.XPATH, "/html")
    postback_HTML = script_tag.get_attribute('outerHTML')

    csv_regex = re.compile(
        r'\s*"(https{0,1}://caselink\.nashville\.gov/.+?\.csv)"\s*\,')

    return csv_regex.search(postback_HTML).group(1)


def import_from_caselink(start_date, end_date):
    logger.info(
        f'Importing caselink warrants between {start_date} and {end_date}')

    csv_url = fetch_csv_link(start_date, end_date)
    if csv_url:
        logger.info(f'Gathered CSV link: {csv_url}')

        csv_imports.from_url(csv_url)
    else:
        logger.warn(f'Could not find CSV between {start_date} and {end_date}')
