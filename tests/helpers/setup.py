from rdc_website.app import create_app
import os


def create_test_app():
    os.environ["RDC_WEBSITE_CONFIG"] = "../tests/config.json"
    app = create_app(testing=True)
    caselink_username = os.environ.get("CASELINK_USERNAME")
    caselink_password = os.environ.get("CASELINK_PASSWORD")
    if caselink_username and caselink_password:
        app.config["CASELINK_USERNAME"] = caselink_username
        app.config["CASELINK_PASSWORD"] = caselink_password

    return app
