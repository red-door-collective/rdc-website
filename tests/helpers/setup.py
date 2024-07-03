from rdc_website.app import create_app
import os


def create_test_app():
    os.environ["RDC_WEBSITE_CONFIG"] = "../tests/config.json"
    return create_app(testing=True)
