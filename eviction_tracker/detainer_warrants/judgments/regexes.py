import re

DETAINER_WARRANT_DOCUMENT = re.compile(
    r'unlawfully\s+detaining\s+a\s+certain\s+real\s+property')
DETAINER_WARRANT_DOCUMENT_OLD = re.compile(
    r'To\s*Any\s*Lawful\s*Officer\s*To\s*Execute'
)
DETAINER_WARRANT_SCANNED_PRINTED = re.compile(
    r'DETAINER\s+SUMMONS'
)
DETAINER_WARRANT_SCANNED_DARK = re.compile(
    r'To\s+the\s+sheriff\s+or\s+constable\s+of\s+such\s+county'
)
DETAINER_WARRANT_SUMMONS = re.compile(
    r'We\s+therefore\s+command\s+you\s+to\s+summon\s+the\s+Defendant'
)

DETAINER_WARRANT_ADDRESS = re.compile(
    r'aforementioned,\s+and\s+bounded\s+or\s+known\s+and\s+described\s+as\s+follows\:?\s+(.+?)\s+INCLUDING\s+BUT\s+NOT\s+LIMITED\s+TO\s+ALL\s+PARKING')
DETAINER_WARRANT_ADDRESS_2 = re.compile(
    r'bounded\s+or\s+known\s+and\s+described\s+as\s+follows\:?\s+(.+?)\s+AND\s+WHEREAS')


DOCKET_ID = re.compile(r'DOCKET\s+NO.\s*:\s*(\w+)\s*')
PLAINTIFF = re.compile(r'COUNTY, TENNESSEE\s*(.+?)\s*Plaintiff')
JUDGE = re.compile(r'The foregoing is hereby.+Judge\s+(.+?),{0,1}\s+Division')
IN_FAVOR_PLAINTIFF = re.compile(
    r'Order\s*(|)\s*Judgment\s+is\s+granted')
IN_FAVOR_DEFENDANT = re.compile(
    r'per\s+annum\s*(|)\s*Case\s+is\s+dismissed')
AWARDS = re.compile(
    r'(|)\s*(|)\s*(?=for\s+possession\s+of\s+the\s+described\s+property|Judgment\s+is\s+entered\s+by:)'
)
AWARDS_FEES_AMOUNT = re.compile(
    r'[$]\s?([+-]?[0-9]{1,3}(?:(?:,?[0-9]{3}))*(?:\.[0-9]{1,2})?)')
ENTERED_BY_DEFAULT = re.compile(r'Judgment is entered by:\s*(.+)\s*Default.')
ENTERED_BY_AGREEMENT = re.compile(r'Default.\s*(.+)\s*Agreement of parties.')
ENTERED_BY_TRIAL = re.compile(r'parties.\s*(.+)\s*Trial in Court')
INTEREST_FOLLOWS_SITE = re.compile(
    r'granted as follows:\s*(.+)\s*at the rate posted')
INTEREST_RATE = re.compile(
    r'Courts.\s*(.+)\s*at\s+the\s+rate\s+of\s+%\s*([\d\.]*)\s*per\s+annum')

DISMISSAL_FAILURE = re.compile(
    r'Dismissal is based on:\s*(.+)\s*Failure to prosecute.')
DISMISSAL_FAVOR = re.compile(
    r'prosecute\.\s*(.+)\s*Finding in favor of Defendant')
DISMISSAL_NON_SUIT = re.compile(r'after trial.\s*(.+)\s*Non-suit by Plaintiff')

WITH_PREJUDICE = re.compile(r'Dismissal\s+is:\s*(.+)\s*Without prejudice')
NOTES = re.compile(
    r'Other\s+terms\s+of\s+this\s+Order,\s+if\s+any,\s+are\s+as\s+follows:\s*(.+?)\s*EFILED')
