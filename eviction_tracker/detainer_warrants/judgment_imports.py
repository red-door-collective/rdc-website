from .models import db
from .models import Attorney, Courtroom, Defendant, DetainerWarrant, Judge, Hearing, Judgment, Plaintiff, detainer_warrant_defendants
from .util import get_or_create, normalize, open_workbook, dw_rows
from sqlalchemy.exc import IntegrityError, InternalError
from sqlalchemy.dialects.postgresql import insert
from decimal import Decimal
from datetime import date, datetime
from dateutil.rrule import rrule, MONTHLY
import re

COURT_DATE = "Court Date"
DOCKET_ID = "Docket #"
COURTROOM = "Courtroom"
PLAINTIFF = "Plaintiff"
PLAINTIFF_ATTORNEY = "Pltf Lawyer"
DEFENDANT = "Defendant"
DEFENDANT_ATTORNEY = "Def Lawyer"
DEFENDANT_ADDRESS = "Def. Address"
REASON = "Reason"
AMOUNT = "Amount Awarded"
MEDIATION_LETTER = "\"Mediation Letter\""
NOTES = "Notes (anything unusual on detainer or in "
JUDGMENT = "Judgement"
JUDGE = "Judge"
JUDGMENT_BASIS = "Judgement Basis"

FEES_REGEX = re.compile(r'\$\s*([\d\.\,]+?)\s+Judge?ment')


def extract_dismissal_basis(outcome, basis):
    if basis == "ftp" or basis == "failure to prosecute":
        return "FAILURE_TO_PROSECUTE"
    elif basis == "fifod" or basis == "finding in favor of defendant":
        return "FINDING_IN_FAVOR_OF_DEFENDANT"
    elif outcome == "non-suit":
        if basis == "default" or basis == "":
            return "NON_SUIT_BY_PLAINTIFF"
        else:
            return None


def _from_workbook(month, court_date, raw_judgment):
    judgment = {k: normalize(v) for k, v in raw_judgment.items()}

    docket_id = judgment[DOCKET_ID]

    if not bool(docket_id) or 'CC' in docket_id:
        return

    dw = DetainerWarrant.query.get(docket_id)

    address = judgment[DEFENDANT_ADDRESS]
    plaintiff_attorney = None
    if judgment[PLAINTIFF_ATTORNEY]:
        plaintiff_attorney, _ = get_or_create(
            db.session, Attorney, name=judgment[PLAINTIFF_ATTORNEY])

    defendant_attorney = None
    if judgment[DEFENDANT_ATTORNEY]:
        defendant_attorney, _ = get_or_create(
            db.session, Attorney, name=judgment[DEFENDANT_ATTORNEY])

    plaintiff = None
    if judgment[PLAINTIFF]:
        plaintiff, _ = get_or_create(
            db.session, Plaintiff, name=judgment[PLAINTIFF])

    courtroom = None
    if judgment[COURTROOM]:
        courtroom, _ = get_or_create(
            db.session, Courtroom, name=judgment[COURTROOM].upper())

    judge = None
    if judgment[JUDGE]:
        judge, _ = get_or_create(
            db.session, Judge, name=judgment[JUDGE])

    awards_possession, awards_fees, in_favor_of = None, None, None
    outcome = judgment[JUDGMENT].lower() if judgment[JUDGMENT] else None

    # Before July, claims were tracked in the amount awards column
    # Awards were tracked in the notes
    if month < datetime.combine(date(2021, 7, 1), datetime.min.time()):  # July
        claims_fees = judgment[AMOUNT]
        dw.update(claims_fees=claims_fees)
        db.session.commit()
        fees_match = FEES_REGEX.search(
            judgment[NOTES]) if judgment[NOTES] else False
        if fees_match:
            awards_fees = fees_match.group(1)
    # After July, claims were not tracked. only fees awarded.
    else:
        awards_fees = Decimal(str(judgment[AMOUNT]).replace(
            '$', '').replace(',', '')) if outcome and 'fees' in outcome and judgment[AMOUNT] else None

    if outcome:
        in_favor_of = 'PLAINTIFF' if 'poss' in outcome or 'fees' in outcome else 'DEFENDANT'
        awards_possession = 'poss' in outcome

    basis = judgment[JUDGMENT_BASIS].lower(
    ) if judgment[JUDGMENT_BASIS] else None

    mediation_letter = judgment[MEDIATION_LETTER].lower(
    ) == 'yes' if judgment[MEDIATION_LETTER] else None
    dismissal_basis = extract_dismissal_basis(
        outcome, basis)
    notes = judgment[NOTES]

    hearing = Hearing.query.filter_by(
        docket_id=docket_id, _court_date=court_date).first()
    if hearing:
        hearing.update(
            address=address,
            courtroom_id=courtroom.id if courtroom else None,
        )
        db.session.commit()
    else:
        hearing = Hearing.create(
            _court_date=court_date,
            docket_id=docket_id,
            address=address,
            courtroom_id=courtroom.id if courtroom else None
        )

    if not in_favor_of:  # this is only a hearing, probably issued a continuance
        return

    judgment_values = dict(
        detainer_warrant_id=docket_id,
        file_date=court_date,
        plaintiff_id=plaintiff.id if plaintiff else None,
        plaintiff_attorney_id=plaintiff_attorney.id if plaintiff_attorney else None,
        judge_id=judge.id if judge else None,
        defendant_attorney_id=defendant_attorney.id if defendant_attorney else None,
        in_favor_of_id=Judgment.parties[in_favor_of],
        awards_possession=awards_possession,
        awards_fees=awards_fees,
        mediation_letter=mediation_letter,
        dismissal_basis_id=Judgment.dismissal_bases[dismissal_basis] if dismissal_basis else None,
        notes=notes,
        last_edited_by_id=-1
    )

    if hearing.judgment:
        hearing.judgment.update(judgment_values)
        db.session.commit()
    else:
        insert_stmt = insert(Judgment).values(
            **judgment_values
        )

        do_update_stmt = insert_stmt.on_conflict_do_update(
            constraint=Judgment.__table__.primary_key,
            set_=judgment_values
        )

        db.session.execute(do_update_stmt)
        db.session.commit()
        judgment = Judgment.query.filter(
            Judgment._file_date == court_date,
            Judgment.detainer_warrant_id == docket_id
        ).first()
        hearing.judgment = judgment
        db.session.commit()

    audit_status = 'CONFIRMED' if dw.audit_status == 'ADDRESS_CONFIRMED' else 'JUDGMENT_CONFIRMED'
    dw.update(audit_status_id=DetainerWarrant.audit_statuses[audit_status])
    db.session.commit()


def from_workbook(workbook_name, limit=None, service_account_key=None):
    wb = open_workbook(workbook_name, service_account_key)

    start_dt = date(2021, 3, 1)
    end_dt = date(2021, 11, 30)
    worksheets = [(dt, wb.worksheet(datetime.strftime(dt, '%B %Y')))
                  for dt in rrule(MONTHLY, dtstart=start_dt, until=end_dt)]

    for month, ws in worksheets:
        all_rows = ws.get_all_records()

        stop_index = int(limit) if limit else all_rows

        judgments = all_rows[:stop_index] if limit else all_rows

        court_date = None
        for judgment in judgments:
            court_date = judgment[COURT_DATE] if judgment[COURT_DATE] else court_date
            _from_workbook(month, court_date, judgment)
