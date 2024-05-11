# CaseLink Data Collection

https://nashville.caselink.gov is a decades-old ASP application. It does not
have any sort of API or metric on eviction.

To ensure that the people of Davidson County have insight into eviction trends,
we then have to scrape the website.

## Strategy

### Login Page

Logging into CaseLink requires an active subscription for $25 per month.

Make a POST with basic auth. The response contains a redirect path to the search
page.

### Search Page

Issue a search between two dates, with a filter set to "Detainer Warrant"

- Save basic details from this response. Including:
  - Case status (pending, closed)
  - Plaintiff
  - Plaintiff attorney
  - Defendant (always scrub this from source code, protect from open web)
  - Defendant attorney (usually missing)
- May need to narrow search if there are too many results. A safe bet to is
  ensure less than 100 results. So, a week at a time is usually safe.

### Case Details Page

Navigate to all detainer warrants that are different than our database

**Example**: case status has updated from pending to closed

#### Priority

Getting individual case details takes the longest time. So we prioritize data
collection in the following order:

1. New warrants
2. Recent, pending cases (less than 2 months old)
3. Older pending cases
4. Closed cases (historical data)

#### Pleading Documents

Pleading documents are the various PDFs that are either scanned in or digitally
entered as legal documents in the court proceedings for an individual case.

##### Retrieve pleading document paths

- Their PDF responses require a path
  - Would rather skip going to every case's page, but there is a number
    generated on the case detail page
- Consider caching the detainer warrant itself
  - These are often handwritten and need to be scanned manually or by OCR

##### Navigate to other tabs

- Extract address if possible
  - Address is incredibly important, and it's inconsistently captured in
    handwritten documents
- Extract court date information
  - Can be used to help notify folks facing eviction
  - Difficult to trace the court dates and continuations through various
    pleading documents
    - Some are handwritten...

### Outside of CaseLink

Run an OCR job at another time, to extract address and other important case
information from Detainer Warrant PDFs
