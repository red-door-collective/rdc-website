from .models import db
from .models import Attorney, Courtroom, Defendant, DetainerWarrant, Judge, Hearing, Judgment, Plaintiff, detainer_warrant_defendants
from .util import get_or_create, normalize, open_workbook, dw_rows
from sqlalchemy.exc import IntegrityError, InternalError
from sqlalchemy.dialects.postgresql import insert
from decimal import Decimal
from datetime import date, datetime
from dateutil.rrule import rrule, MONTHLY

COURT_DATE = "Court Date"
DOCKET_ID = "Docket #"
COURTROOM = "Courtroom"
PLAINTIFF = "Plaintiff"
PLAINTIFF_ATTORNEY = "Pltf Lawyer"
DEFENDANT = "Defendant"
DEFENDANT_ATTORNEY = "Def Lawyer"
DEFENDANT_ADDRESS = "Def. Address"
REASON = "Reason"
AMOUNT = "Amount"
MEDIATION_LETTER = "\"Mediation Letter\""
NOTES = "Notes (anything unusual on detainer or in "
JUDGEMENT = "Judgement"
JUDGE = "Judge"
JUDGEMENT_BASIS = "Judgement Basis"


def _from_workbook(court_date, raw_judgment):
    judgment = {k: normalize(v) for k, v in raw_judgment.items()}

    docket_id = judgment[DOCKET_ID]

    if not bool(docket_id):
        return

    address = judgment[DEFENDANT_ADDRESS]

    hearing = Hearing.query.filter_by(
        docket_id=docket_id, _court_date=court_date).first()
    if hearing and not hearing.address:
        hearing.update(address=address)
        db.session.commit()


def from_workbook(workbook_name, limit=None, service_account_key=None):
    wb = open_workbook(workbook_name, service_account_key)

    start_dt = date(2021, 3, 1)
    end_dt = date(2021, 11, 30)
    worksheets = [wb.worksheet(datetime.strftime(dt, '%B %Y'))
                  for dt in rrule(MONTHLY, dtstart=start_dt, until=end_dt)]

    for ws in worksheets:
        all_rows = ws.get_all_records()

        stop_index = int(limit) if limit else all_rows

        judgments = all_rows[:stop_index] if limit else all_rows

        court_date = None
        for judgment in judgments:
            court_date = judgment[COURT_DATE] if judgment[COURT_DATE] else court_date
            _from_workbook(court_date, judgment)
