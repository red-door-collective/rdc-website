import re


DOCKET_ID = re.compile(r'DOCKET\s+NO.\s*:\s*(\w+)\s*')
PLAINTIFF = re.compile(r'COUNTY, TENNESSEE\s*(.+?)\s*Plaintiff')
JUDGE = re.compile(r'The foregoing is hereby.+Judge\s+(.+?),{0,1}\s+Division')
IN_FAVOR_PLAINTIFF = re.compile(r'Order\s*(.+)\s*Judgment is granted')
IN_FAVOR_DEFENDANT = re.compile(r'per annum\s*(.+)\s*Case is dismissed')
AWARDS = re.compile(
    r'Judgment\s+is\s+granted\s+to\s+Plaintiff\s+against\s+.+\s+(\uf06f|\uf0fd)\s+(\uf06f|\uf0fd)\s+for\s+possession\s+of\s+the\s+described\s+property'
)
AWARDS_FEES_AMOUNT = re.compile(r'\$\s*([\d\.]+?)\s+')
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
