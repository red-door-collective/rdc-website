import unittest
from unittest import mock

from flask_testing import TestCase
from rdc_website.app import create_app
import rdc_website.detainer_warrants.caselink as caselink
from rdc_website.detainer_warrants.caselink.navigation import Navigation
from datetime import datetime, date
from tests.helpers.rdc_test_case import RDCTestCase


def mocked_post(*args, **kwargs):
    class MockResponse:
        def __init__(self, text, status_code):
            self.text = text
            self.status_code = status_code

        def text(self):
            return self.text

    data = kwargs["data"] if isinstance(kwargs["data"], dict) else {}

    if data.get("XEVENT") == "VERIFY":
        with open("tests/fixtures/caselink/login-page/login-redirect.html") as f:
            return MockResponse(f.read(), 200)
    elif "PARENT=MENU" in kwargs["data"]:
        with open("tests/fixtures/caselink/search-page/menu.html") as f:
            return MockResponse(f.read(), 200)
    elif "XEVENT=READREC" in kwargs["data"] and "APPID=davlvp" in kwargs["data"]:
        with open("tests/fixtures/caselink/search-page/read-rec.html") as f:
            return MockResponse(f.read(), 200)
    elif "P_26" in kwargs["data"] and "05%2F01%2F2024" in kwargs["data"]:
        with open("tests/fixtures/caselink/search-page/add-start-date.html") as f:
            return MockResponse(f.read(), 200)
    elif "P_31" in kwargs["data"]:
        with open(
            "tests/fixtures/caselink/search-page/add-detainer-warrant-type.html"
        ) as f:
            return MockResponse(f.read(), 200)
    elif "WTKCB_20" in kwargs["data"]:
        with open("tests/fixtures/caselink/search-page/search-redirect.html") as f:
            return MockResponse(f.read(), 200)
    elif "CP*CASELINK.MAIN" in kwargs["data"] and "APPID=pubgs" in kwargs["data"]:
        with open("tests/fixtures/caselink/search-results-page/open-case.html") as f:
            return MockResponse(f.read(), 200)
    elif "XEVENT=READREC" in kwargs["data"] and "APPID=pubgs" in kwargs["data"]:
        with open(
            "tests/fixtures/caselink/search-results-page/open-case-redirect.html"
        ) as f:
            return MockResponse(f.read(), 200)
    elif "CURRPROCESS=LVP.SES.INQUIRY" in kwargs["data"]:
        with open(
            "tests/fixtures/caselink/case-page/open-pleading-document-redirect.html"
        ) as f:
            return MockResponse(f.read(), 200)
    elif "imageviewer.php" in args[0]:
        with open("tests/fixtures/caselink/pdf-viewer.html") as f:
            return MockResponse(f.read(), 200)

    return MockResponse(None, 404)


def mocked_get(*args, **kwargs):
    class MockResponse:
        def __init__(self, text, status_code):
            self.text = text
            self.status_code = status_code

        def text(self):
            return self.text

    if args[0].endswith("VERIFY.20580.77105150.html"):
        with open("tests/fixtures/caselink/search-page/index.html") as f:
            return MockResponse(f.read(), 200)
    elif args[0].endswith("POSTBACK.20581.72727882.html"):
        with open("tests/fixtures/caselink/search-results-page/index.html") as f:
            return MockResponse(f.read(), 200)
    elif args[0].endswith("STDHUB.20585.59888194.html"):
        with open("tests/fixtures/caselink/case-page/index.html") as f:
            return MockResponse(f.read(), 200)
    elif args[0].endswith("READREC.20585.59888697.html"):
        with open("tests/fixtures/caselink/case-page/pleading-documents.html") as f:
            return MockResponse(f.read(), 200)

    return MockResponse(None, 404)


def date_as_str(d, format):
    return datetime.strptime(d, format).date()


RESULTS_PAGE_PATH = "/gsapdfs/1715026207198.POSTBACK.20581.72727882.html"
RESULT_PAGE_PARENT = "POSTBACK"
WEB_IO_HANDLE = "1715026207198"


class TestNavigation(RDCTestCase):

    @mock.patch("requests.Session.post", side_effect=mocked_post)
    @mock.patch("requests.Session.get", side_effect=mocked_get)
    def test_login(self, mock_get, mock_post):
        navigation = Navigation.login()

        self.assertEqual(
            navigation.path,
            "/gsapdfs/{}.VERIFY.20580.77105150.html".format(WEB_IO_HANDLE),
        )
        self.assertEqual(navigation.web_io_handle, WEB_IO_HANDLE)
        self.assertEqual(navigation.parent, "VERIFY")

        self.assertEqual(len(mock_post.call_args_list), 1)

    @mock.patch("requests.Session.post", side_effect=mocked_post)
    @mock.patch("requests.Session.get", side_effect=mocked_get)
    def test_search(self, mock_get, mock_post):
        navigation = Navigation.from_response(Navigation.login().search())

        self.assertEqual(
            navigation.path,
            "/gsapdfs/{}.POSTBACK.20581.72727882.html".format(WEB_IO_HANDLE),
        )
        self.assertEqual(navigation.web_io_handle, WEB_IO_HANDLE)
        self.assertEqual(navigation.parent, "POSTBACK")

        self.assertEqual(len(mock_post.call_args_list), 2)

    @mock.patch("requests.Session.post", side_effect=mocked_post)
    def test_menu(self, mock_post):
        search_page = Navigation.login()

        postback_response = search_page.menu()

        self.assertIn(
            "/gsapdfs/1714928640773.STDHUB.20634.22312689.html", postback_response.text
        )

    @mock.patch("requests.Session.post", side_effect=mocked_post)
    def test_read_rec(self, mock_post, side_effect=mocked_post):
        search_page = Navigation.login()

        menu_resp = search_page.menu()
        menu_page = Navigation.from_response(menu_resp)
        read_rec_resp = menu_page.read_rec()

        self.assertIn("Appeal from Admin. Hearing", read_rec_resp.text)

    @mock.patch("requests.Session.post", side_effect=mocked_post)
    def test_add_start_date(self, mock_post):
        search_page = Navigation.login()

        search_page.add_start_date(date(2024, 5, 1))

        results_page = Navigation.from_response(search_page.search())

        self.assertEqual(
            results_page.path,
            "/gsapdfs/{}.POSTBACK.20581.72727882.html".format(WEB_IO_HANDLE),
        )
        self.assertEqual(results_page.web_io_handle, WEB_IO_HANDLE)
        self.assertEqual(results_page.parent, "POSTBACK")

        self.assertEqual(len(mock_post.call_args_list), 3)

    @mock.patch("requests.Session.post", side_effect=mocked_post)
    def test_add_detainer_warrant_type(self, mock_post):
        search_page = Navigation.login()

        search_page.add_detainer_warrant_type(date(2024, 5, 1))
        results_page = search_page.search()

        self.assertEqual(
            results_page.path,
            "/gsapdfs/{}.POSTBACK.20581.72727882.html".format(WEB_IO_HANDLE),
        )
        self.assertEqual(results_page.web_io_handle, WEB_IO_HANDLE)
        self.assertEqual(results_page.parent, "POSTBACK")

        self.assertEqual(len(mock_post.call_args_list), 3)

    @mock.patch("requests.Session.post", side_effect=mocked_post)
    def test_add_detainer_warrant_type(self, mock_post):
        search_page = Navigation.login()

        search_page.add_detainer_warrant_type(date(2024, 5, 1))
        results_page = Navigation.from_response(search_page.search())

        self.assertEqual(
            results_page.path,
            "/gsapdfs/{}.POSTBACK.20581.72727882.html".format(WEB_IO_HANDLE),
        )
        self.assertEqual(results_page.web_io_handle, WEB_IO_HANDLE)
        self.assertEqual(results_page.parent, "POSTBACK")

        self.assertEqual(len(mock_post.call_args_list), 3)

    @mock.patch("requests.Session.post", side_effect=mocked_post)
    def test_open_case(self, mock_post):
        search_page = Navigation.login()

        results_page = Navigation.from_response(search_page.search())
        open_case_response = results_page.open_case("P_102_2", "24GT4890", [])

        self.assertIn(
            '"LVP.SES.INQUIRY", "24GT4890", "STDHUB"', open_case_response.text
        )

    @mock.patch("requests.Session.post", side_effect=mocked_post)
    @mock.patch("requests.Session.get", side_effect=mocked_get)
    def test_open_case_redirect(self, mock_get, mock_post):
        search_page = Navigation.login()

        results_page = Navigation.from_response(search_page.search())
        response = results_page.open_case_redirect("24GT4890")
        case_page = Navigation.from_response(response)

        self.assertEqual(
            case_page.path, "/gsapdfs/1715359093408.STDHUB.20585.59888194.html"
        )
        self.assertEqual(case_page.web_io_handle, "1715359093408")

    @mock.patch("requests.Session.post", side_effect=mocked_post)
    def test_view_pdf(self, mock_post):
        search_page = Navigation.login()

        view_pdf_response = search_page.view_pdf(
            "\\Public\\Sessions\\24\\24GT4890\\3370253.pdf"
        )

        self.assertIn('form.action = "/imageviewer.php";', view_pdf_response.text)


if __name__ == "__main__":
    unittest.main()
