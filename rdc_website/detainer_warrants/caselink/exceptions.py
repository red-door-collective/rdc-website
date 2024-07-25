class BulkScrapeException(Exception):
    def __init__(
        self, docket_id, index, total_cases, was_fatal=False, last_failure=None
    ):
        self.docket_id = docket_id
        self.index = index
        self.total_cases = total_cases
        self.was_fatal = was_fatal
        self.last_failure = last_failure

    def progress_made(self):
        cases_processed = self.total_cases

        if self.last_failure:
            cases_processed -= self.last_failure

        return self.index / cases_processed
