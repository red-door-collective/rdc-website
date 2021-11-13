from flask import current_app
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
from ..util import get_or_create
from ..models import db, PleadingDocument
from .constants import ids, names
from .common import login, search, run_with_chrome


@run_with_chrome
def fetch_documents(browser, docket_id):
    login(browser)
    docket_search = WebDriverWait(browser, 5).until(
        EC.element_to_be_clickable((By.NAME, names.DOCKET_NUMBER_INPUT))
    )
    try:
        docket_search.send_keys(docket_id)
    except ElementNotInteractableException:
        time.sleep(.5)
        docket_search.send_keys(docket_id)

    search(browser)

    time.sleep(3)
    browser.switch_to.frame(ids.POSTBACK_FRAME)

    script_tag = browser.find_element(By.XPATH, "/html")
    postback_HTML = script_tag.get_attribute('outerHTML')

    documents_regex = re.compile(
        r'\,\s*"ý(https://caselinkimages.nashville.gov.+?)ý+"\,')

    urls_mess = documents_regex.search(postback_HTML).group(1)
    urls = [url for url in urls_mess.split('ý') if url != '']

    created_count = 0
    for url in urls:
        document, was_created = get_or_create(
            db.session, PleadingDocument, url=url, docket_id=docket_id)
        if was_created:
            created_count += 1

    db.session.commit()

    print(created_count)
