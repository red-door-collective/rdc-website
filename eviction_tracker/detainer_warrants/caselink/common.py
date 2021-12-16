
from flask import current_app
from functools import wraps
from selenium import webdriver
from selenium.common.exceptions import ElementNotInteractableException
from selenium.webdriver.support.wait import WebDriverWait
import selenium.webdriver.support.expected_conditions as EC
from selenium.webdriver.common.by import By
from selenium.webdriver.common.keys import Keys
import time
import os
import re
import time
from .constants import ids, names
from ..util import get_or_create
from ..models import db, PleadingDocument
import traceback
import eviction_tracker.config as config
import logging
import logging.config
import traceback
from circuitbreaker import circuit

logging.config.dictConfig(config.LOGGING)
logger = logging.getLogger(__name__)

CASELINK_URL = 'https://caselink.nashville.gov'


def chrome_options():
    options = webdriver.ChromeOptions()
    options.add_argument('--headless')
    options.add_argument('--disable-gpu')
    options.add_argument('--disable-dev-shm-usage')
    options.add_argument('--no-sandbox')
    # options.add_argument('--ignore-certificate-errors')
    # options.add_argument('--allow-running-insecure-content')
    options.add_experimental_option("prefs", {
        "download.default_directory": "/dev/null"
    })

    return options


def run_with_chrome(f, options=None):
    @wraps(f)
    def wrapper(*args, **kwds):
        browser = webdriver.Chrome(
            chrome_options=options if options else chrome_options())
        try:
            return f(browser, *args, **kwds)
        except:
            logger.error("uncaught exception: %s", traceback.format_exc())
            browser.quit()
            exit(1)
        finally:
            browser.quit()

    return wrapper


@circuit(expected_exception=ConnectionError)
def login(browser):
    browser.get(CASELINK_URL)
    browser.switch_to.frame(ids.UPDATE_FRAME)

    username_field = WebDriverWait(browser, 5).until(
        EC.presence_of_element_located((By.ID, ids.USERNAME_LOGIN_FIELD))
    )
    username_field.send_keys(current_app.config['CASELINK_USERNAME'])

    password_field = browser.find_element(By.ID, ids.PASSWORD_LOGIN_FIELD)
    password_field.send_keys(current_app.config['CASELINK_PASSWORD'])

    browser.find_element(By.ID, ids.LOGIN_BUTTON).click()

    time.sleep(1.5)


def search(browser):
    browser.find_element(By.NAME, names.SEARCH_BUTTON).click()
    time.sleep(1.5)
