import time
import pytest

from rdc_website.database import db
from rdc_website.detainer_warrants.caselink import warrants, pleadings
from datetime import date
from tests.helpers.rdc_test_case import RDCTestCase
from rdc_website.detainer_warrants.models import PleadingDocument


@pytest.mark.smoke
@pytest.mark.integration
class TestScrapePleadingDocuments(RDCTestCase):

    def test_closed_warrant(self):
        docket_id = "23GT57"  # simple docket with warrant and dismissal judgment

        detainer_warrant = warrants.from_docket_id(
            docket_id, with_pleading_documents=True
        )

        self.assertEqual(len(detainer_warrant.pleadings), 4)
