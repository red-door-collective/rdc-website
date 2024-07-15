import pytest

from flask import current_app
from rdc_website.database import db
import rdc_website.detainer_warrants.caselink.warrants as warrants
from datetime import datetime, date
from tests.helpers.rdc_test_case import RDCTestCase
from rdc_website.detainer_warrants.models import DetainerWarrant, Attorney, Plaintiff


def date_as_str(d, format):
    return datetime.strptime(d, format).date()


@pytest.mark.smoke
class TestWarrants(RDCTestCase):

    def test_historical_search(self):
        start = date(2023, 1, 3)
        end = date(2023, 1, 4)

        TOTAL_WARRANTS = 84

        warrants.import_from_caselink(start, end, with_pleading_documents=False)

        query = db.session.query(DetainerWarrant)

        scraped = DetainerWarrant.between_dates(start, end, query)

        self.assertEqual(scraped.count(), TOTAL_WARRANTS)
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
        self.assertEqual(
            scraped.filter(
                DetainerWarrant.status_id == DetainerWarrant.statuses["CLOSED"]
            ).count(),
            83,
        )
