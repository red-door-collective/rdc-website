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


def fetch_documents(docket_id):
    caselink_username = current_app.config['CASELINK_USERNAME']
    caselink_password = current_app.config['CASELINK_PASSWORD']

    browser = webdriver.Chrome()
    try:
        browser.get('https://caselink.nashville.gov')
        browser.switch_to.frame("update")

        username_field = WebDriverWait(browser, 5).until(
            EC.presence_of_element_located((By.ID, 'OPERCODE'))
        )

        username_field.send_keys(caselink_username)
        browser.find_element(By.ID, "PASSWD").send_keys(caselink_password)

        browser.find_element(By.ID, "LogInSub").click()

        docket_search = WebDriverWait(browser, 5).until(
            EC.element_to_be_clickable((By.XPATH, '//input[@name="P_21"]'))
        )
        # browser.implicitly_wait(2)
        try:
            docket_search.send_keys(docket_id)
        except ElementNotInteractableException:
            time.sleep(.5)
            docket_search.send_keys(docket_id)

        browser.find_element(By.XPATH, '//button[@name="WTKCB_20"]').click()

        # dw = WebDriverWait(browser, 5).until(
        #     EC.presence_of_element_located((By.ID, 'L_TRN_3'))
        # )

        # WebDriverWait(browser, 5).until(
        #     EC.frame_to_be_available_and_switch_to_it('postback')
        # )

        time.sleep(3)
        browser.switch_to.frame("postback")

        script_tag = browser.find_element(
            By.XPATH, "/html")
        # script_tag = WebDriverWait(browser, 5).until(
        #     EC.presence_of_element_located(
        #         (By.XPATH, "//*[contains(text(),'function PostRead()')]"))
        # )
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

    finally:
        browser.quit()
