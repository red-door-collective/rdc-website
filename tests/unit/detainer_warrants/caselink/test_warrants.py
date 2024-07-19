import unittest

import rdc_website.detainer_warrants.caselink.warrants as warrants
from datetime import datetime
from tests.helpers.rdc_test_case import RDCTestCase


def mocked_login(*args, **kwargs):
    class MockResponse:
        def __init__(self, text, status_code):
            self.text = text
            self.status_code = status_code

        def text(self):
            return self.text

    if args[0] == "https://caselink.nashville.gov/cgi-bin/webshell.asp":
        with open("tests/fixtures/caselink/login-successful.html") as f:
            return MockResponse(f.read(), 200)

    return MockResponse(None, 404)


def date_as_str(d, format):
    return datetime.strptime(d, format).date()


class TestWarrants(RDCTestCase):

    def test_extract_search_response_data(self):
        search_results = None
        with open("tests/fixtures/caselink/search-results-page/index.html") as f:
            search_results = f.read()

        matches = warrants.extract_search_response_data(search_results)

        self.assertEqual(
            matches,
            [
                ("P_101_1", "Sessions"),
                ("P_102_1", "24GT4773"),
                ("P_103_1", "PENDING"),
                ("P_104_1", "05/02/2024"),
                ("P_105_1", "DETAINER WARRANT FORM"),
                ("P_106_1", "MYKA GODWIN"),
                ("P_107_1", "DEFENDANT A"),
                ("P_108_1", ", PRS"),
                ("P_109_1", ""),
                ("P_101_2", "Sessions"),
                ("P_102_2", "24GT4770"),
                ("P_103_2", "PENDING"),
                ("P_104_2", "05/01/2024"),
                ("P_105_2", "DETAINER WARRANT"),
                ("P_106_2", "PROGRESS RESIDENTIAL BORROWER 6, LLC 1408 CHUTNEY COURT"),
                ("P_107_2", "DEFENDANT 1 OR ALL OTHER OCCUPANTS"),
                ("P_108_2", "MCCOY, JENNIFER JO"),
                ("P_109_2", ""),
                ("P_101_3", "Sessions"),
                ("P_102_3", "24GT4772"),
                ("P_103_3", "PENDING"),
                ("P_104_3", "05/01/2024"),
                ("P_105_3", "DETAINER WARRANT"),
                ("P_106_3", "WESTBORO APARTMENTS"),
                ("P_107_3", "DEFENDANT 2"),
                ("P_108_3", "RUSNAK, JOSEPH P."),
                ("P_109_3", ""),
            ],
        )

    def test_build_cases_from_parsed_matches(self):
        search_results = None
        with open("tests/fixtures/caselink/search-results-page/index.html") as f:
            search_results = f.read()

        matches = warrants.extract_search_response_data(search_results)
        cell_names, cell_values = warrants.split_cell_names_and_values(matches)
        cases = warrants.build_cases_from_parsed_matches(cell_values)

        self.assertEqual(
            cases,
            [
                {
                    "Office": "Sessions",
                    "Docket #": "24GT4773",
                    "Status": "PENDING",
                    "File Date": "05/02/2024",
                    "Description": "DETAINER WARRANT FORM",
                    "Plaintiff": "MYKA GODWIN",
                    "Pltf. Attorney": "REPRESENTING SELF",
                    "Defendant": "DEFENDANT A",
                    "Def. Attorney": "",
                },
                {
                    "Office": "Sessions",
                    "Docket #": "24GT4770",
                    "Status": "PENDING",
                    "File Date": "05/01/2024",
                    "Description": "DETAINER WARRANT",
                    "Plaintiff": "PROGRESS RESIDENTIAL BORROWER 6, LLC 1408 CHUTNEY COURT",
                    "Pltf. Attorney": "MCCOY, JENNIFER JO",
                    "Defendant": "DEFENDANT 1 OR ALL OTHER OCCUPANTS",
                    "Def. Attorney": "",
                },
                {
                    "Office": "Sessions",
                    "Docket #": "24GT4772",
                    "Status": "PENDING",
                    "File Date": "05/01/2024",
                    "Description": "DETAINER WARRANT",
                    "Plaintiff": "WESTBORO APARTMENTS",
                    "Pltf. Attorney": "RUSNAK, JOSEPH P.",
                    "Defendant": "DEFENDANT 2",
                    "Def. Attorney": "",
                },
            ],
        )


if __name__ == "__main__":
    unittest.main()
