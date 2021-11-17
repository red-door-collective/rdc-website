from .models import db
from .models import Attorney, Courtroom, Defendant, DetainerWarrant, District, Judge, Judgment, Plaintiff, detainer_warrant_defendants
from .util import get_or_create, normalize, open_workbook, dw_rows, district_defaults
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
JUDGMENT = "Judgement"
JUDGE = "Judge"
JUDGMENT_BASIS = "Judgement Basis"

DW_COURT_DATE = 'Court_date'
DW_COURTROOM = 'Courtroom'
DW_JUDGE = 'Presiding_judge'


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


def get_existing_judgment(court_date, docket_id):
    return Judgment.query.filter_by(detainer_warrant_id=docket_id, court_date=court_date)


def _from_workbook(defaults, court_date, raw_judgment):
    judgment = {k: normalize(v) for k, v in raw_judgment.items()}

    docket_id = judgment[DOCKET_ID]

    if not bool(docket_id):
        return

    warrant, _ = get_or_create(db.session, DetainerWarrant,
                               docket_id=docket_id,
                               order_number=DetainerWarrant.calc_order_number(
                                   docket_id),
                               defaults={'last_edited_by_id': -1})

    plaintiff_attorney = None
    if judgment[PLAINTIFF_ATTORNEY]:
        plaintiff_attorney, _ = get_or_create(
            db.session, Attorney, name=judgment[PLAINTIFF_ATTORNEY], defaults=defaults)

    defendant_attorney = None
    if judgment[DEFENDANT_ATTORNEY]:
        defendant_attorney, _ = get_or_create(
            db.session, Attorney, name=judgment[DEFENDANT_ATTORNEY], defaults=defaults)

    plaintiff = None
    if judgment[PLAINTIFF]:
        plaintiff, _ = get_or_create(
            db.session, Plaintiff, name=judgment[PLAINTIFF], defaults=defaults)

    courtroom = None
    if judgment[COURTROOM]:
        courtroom, _ = get_or_create(
            db.session, Courtroom, name=judgment[COURTROOM].upper(), defaults=defaults)

    judge = None
    if judgment[JUDGE]:
        judge, _ = get_or_create(
            db.session, Judge, name=judgment[JUDGE], defaults=defaults)

    defendant_address = judgment[DEFENDANT_ADDRESS]
    if defendant_address and len(warrant.defendants) > 0:
        for defendant in warrant.defendants:
            if defendant.address is None:
                defendant.update(address=defendant_address)

    awards_possession, awards_fees, in_favor_of = None, None, None
    outcome = judgment[JUDGMENT].lower() if judgment[JUDGMENT] else None
    if outcome:
        in_favor_of = 'PLAINTIFF' if 'poss' in outcome or 'fees' in outcome else 'DEFENDANT'
        awards_possession = 'poss' in outcome
        try:
            awards_fees = Decimal(str(judgment[AMOUNT]).replace(
                '$', '').replace(',', '')) if 'fees' in outcome and judgment[AMOUNT] else None
        except KeyError:
            awards_fees = Decimal(str(judgment["Amount Awarded"]).replace(
                '$', '').replace(',', '')) if 'fees' in outcome and judgment["Amount Awarded"] else None

    basis = judgment[JUDGMENT_BASIS].lower(
    ) if judgment[JUDGMENT_BASIS] else None

    mediation_letter = judgment[MEDIATION_LETTER].lower(
    ) == 'yes' if judgment[MEDIATION_LETTER] else None
    dismissal_basis = extract_dismissal_basis(
        outcome, basis)
    notes = judgment[NOTES]

    judgment_values = dict(
        detainer_warrant_id=warrant.docket_id,
        court_date=court_date,
        courtroom_id=courtroom.id if courtroom else None,
        plaintiff_id=plaintiff.id if plaintiff else None,
        plaintiff_attorney_id=plaintiff_attorney.id if plaintiff_attorney else None,
        judge_id=judge.id if judge else None,
        defendant_attorney_id=defendant_attorney.id if defendant_attorney else None,
        in_favor_of_id=Judgment.parties[in_favor_of] if in_favor_of else None,
        awards_possession=awards_possession,
        awards_fees=awards_fees,
        mediation_letter=mediation_letter,
        dismissal_basis_id=Judgment.dismissal_bases[dismissal_basis] if dismissal_basis else None,
        notes=notes,
        last_edited_by_id=-1
    )

    existing_judgment = get_existing_judgment(court_date, docket_id)

    if (existing_judgment.count() > 0):
        existing_judgment.update(judgment_values)
        db.session.commit()
        return

    insert_stmt = insert(Judgment).values(
        **judgment_values
    )

    do_update_stmt = insert_stmt.on_conflict_do_update(
        constraint=Judgment.__table__.primary_key,
        set_=judgment_values
    )

    db.session.execute(do_update_stmt)
    db.session.commit()


def from_workbook(workbook_name, limit=None, service_account_key=None):
    wb = open_workbook(workbook_name, service_account_key)

    start_dt = date(2021, 3, 1)
    end_dt = date.today()
    worksheets = [wb.worksheet(datetime.strftime(dt, '%B %Y'))
                  for dt in rrule(MONTHLY, dtstart=start_dt, until=end_dt)]

    defaults = district_defaults()

    for ws in worksheets:
        all_rows = ws.get_all_records()

        stop_index = int(limit) if limit else all_rows

        judgments = all_rows[:stop_index] if limit else all_rows

        court_date = None
        for judgment in judgments:
            court_date = judgment[COURT_DATE] if judgment[COURT_DATE] else court_date
            _from_workbook(defaults, court_date, judgment)


def _from_dw_wb_row(raw_warrant):
    warrant = {k: normalize(v) for k, v in raw_warrant.items()}

    dw = db.session.query(DetainerWarrant).get(warrant["Docket #"])

    if not dw:
        return

    outcome = warrant['Judgement'].lower() if warrant['Judgement'] else None
    if outcome and len(dw._judgments) == 0:
        defaults = district_defaults()
        in_favor_of = 'PLAINTIFF' if 'poss' in outcome or 'fees' in outcome else 'DEFENDANT'
        awards_possession = 'poss' in outcome
        awards_fees = dw.amount_claimed if 'fees' in outcome or 'payment' in outcome else None

        presiding_judge = None
        if warrant[DW_JUDGE]:
            presiding_judge, _ = get_or_create(
                db.session, Judge, name=warrant[DW_JUDGE], defaults=defaults)

        courtroom = None
        if warrant[DW_COURTROOM]:
            courtroom, _ = get_or_create(
                db.session, Courtroom, name=warrant[DW_COURTROOM].upper(), defaults=defaults)

        court_date = warrant[DW_COURT_DATE]
        court_date_final = '11/3/2020' if court_date == '11/3' else court_date

        judgment = Judgment.create(
            detainer_warrant_id=dw.docket_id,
            in_favor_of_id=Judgment.parties[in_favor_of],
            awards_possession=awards_possession,
            awards_fees=awards_fees,
            courtroom_id=courtroom.id if courtroom else None,
            judge_id=presiding_judge.id if presiding_judge else None,
            _court_date=court_date_final
        )

        db.session.add(judgment)
        dw._judgments = dw._judgments + [judgment]
        db.session.add(dw)
        db.session.commit()


def from_dw_wb(workbook_name, limit=None, service_account_key=None):
    wb = open_workbook(workbook_name, service_account_key)
    warrants = dw_rows(limit, wb)
    for warrant in warrants:
        _from_dw_wb_row(warrant)
