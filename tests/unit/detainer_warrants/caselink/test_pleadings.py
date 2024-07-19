import unittest

from rdc_website.detainer_warrants.caselink import pleadings
from tests.helpers.rdc_test_case import RDCTestCase


class TestPleadings(RDCTestCase):

    def test_extract_image_paths(self):
        pleading_documents = None
        with open("tests/fixtures/caselink/case-page/pleading-documents.html") as f:
            pleading_documents = f.read()

        paths = pleadings.extract_pleading_document_paths(pleading_documents)

        self.assertEqual(
            paths,
            [
                "\\Public\\Sessions\\24\\24GT4890\\3370253.pdf",
                "\\Public\\Sessions\\24/24GT4890\\03370254.pdf",
            ],
        )


if __name__ == "__main__":
    unittest.main()
