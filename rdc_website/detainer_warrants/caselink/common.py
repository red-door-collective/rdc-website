
from flask import current_app

import re
import requests
import rdc_website.config as config
import logging
import logging.config

logging.config.dictConfig(config.LOGGING)
logger = logging.getLogger(__name__)

username = current_app.config["CASELINK_USERNAME"]
password = current_app.config["CASELINK_PASSWORD"]


def follow_postback(url):
    return requests.get(
        url,
        cookies=cookies,
        headers=headers({
        'Referer': WEBSHELL,
        'Sec-Fetch-Dest': 'frame',
        }),
    )
    