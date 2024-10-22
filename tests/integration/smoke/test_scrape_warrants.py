import pytest

from rdc_website.database import db
import rdc_website.detainer_warrants.caselink.warrants as warrants
from datetime import date
from tests.helpers.rdc_test_case import RDCTestCase
from rdc_website.detainer_warrants.models import DetainerWarrant, Attorney, Plaintiff


@pytest.mark.smoke
@pytest.mark.integration
class TestScrapeWarrants(RDCTestCase):

    def test_historical_search(self):
        start = date(2023, 1, 3)
        end = date(2023, 1, 4)

        warrants.import_from_caselink(start, end, with_pleading_documents=False)

        query = db.session.query(DetainerWarrant)

        scraped = DetainerWarrant.between_dates(start, end, query)

        self.assertEqual(
            scraped.join(Attorney)
            .filter(Attorney.name == "MCCOY, JENNIFER JO")
            .count(),
            41,
        )
        self.assertEqual(
            scraped.join(Plaintiff).filter(Plaintiff.name == "AVANA OVERLOOK").count(),
            11,
        )
        self.assertIn(
            scraped.filter(
                DetainerWarrant.status_id == DetainerWarrant.statuses["CLOSED"]
            ).count(),
            range(
                80, 90
            ),  # these shouldn't change but caselink is inconsistent. just want a ballpark
        )

    def test_scrape_defendant(self):
        docket_id = "23GT57"

        detainer_warrant = warrants.from_docket_id(docket_id)

        defendant = detainer_warrant.defendants[0]

        self.assertEqual(detainer_warrant.docket_id, docket_id)
        self.assertIsNotNone(defendant.name)
        self.assertNotIn("ALL OTHER OCCUPANTS", defendant.name)
        self.assertEqual(
            detainer_warrant.address, "272 BELL ROAD 15-1524 ANTIOCH, TN  37013"
        )
