from selenium import webdriver
from selenium.webdriver.support.wait import WebDriverWait
import selenium.webdriver.support.expected_conditions as EC
from selenium.webdriver.common.by import By
from selenium.webdriver.common.keys import Keys
import time
import os

caselink_username = os.environ['CASELINK_USERNAME']
caselink_password = os.environ['CASELINK_PASSWORD']

browser = webdriver.Chrome()

try:
    browser.get('https://caselink.nashville.gov')
    browser.switch_to.frame("update")
    # browser.find_element(By.ID, "OPERCODE").send_keys(caselink_username)
    username_field = WebDriverWait(browser, 3).until(
        EC.presence_of_element_located((By.ID, 'OPERCODE'))
    )

    username_field.send_keys(caselink_username)
    browser.find_element(By.ID, "PASSWD").send_keys(caselink_password)

    browser.find_element(By.ID, "LogInSub").click()

    docket_search = WebDriverWait(browser, 5).until(
        EC.element_to_be_clickable((By.XPATH, '//input[@name="P_21"]'))
    )
    browser.implicitly_wait(2)
    docket_search.send_keys('21GT3993')

    browser.find_element(By.XPATH, '//button[@name="WTKCB_20"]').click()

    dw = WebDriverWait(browser, 5).until(
        EC.presence_of_element_located((By.ID, 'L_TRN_3'))
    )

    browser.switch_to.frame("postback")

    script_text = browser.get_element(
        '/html/head/script[2]').get_attribute('outerHTML')

    documents_regex = re.compile(
        r'\,\s*"ý(https://caselinkimages.nashville.gov.+?)ý+"\,')

    urls_mess = documents_regex.search(script_text).group(1)
    urls = [url for url in urls_mess.split('ý') if url != '']

    # documents = browser.find_elements(
    #     By.XPATH, '//*[@id="GRIDTBL_1A"]/tbody/tr/td[3]/input')

    # judgment_buttons = []
    # for index, document in enumerate(documents):
    #     is_judgment = 'JUDGMENT' in document.get_attribute('value')
    #     button_matches = browser.find_elements(
    #         By.XPATH, f'//*[@id="GRIDTBL_1A"]/tbody/tr[{index + 2}]/td[4]/button[not(@disabled)]')
    #     if is_judgment and len(button_matches) > 0:
    #         judgment_buttons.append(button_matches[0])

    # for button in judgment_buttons:
    #     browser.implicitly_wait(5)
    #     print(button)
    #     button.click()
    #     browser.implicitly_wait(5)
    #     print('found judgment button')
    #     break

    # buttons = browser.find_elements(By.XPATH, '//button[@value=""][not(@disabled)]')

    # for button in buttons:
    #     button.click()

    # browser.find_element(By.XPATH, '//button[@')

finally:
    browser.quit()
