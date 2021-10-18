from .models import db
from .models import Attorney, Courtroom, Defendant, DetainerWarrant, District, Judge, Judgement, Plaintiff, detainer_warrant_defendants
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
JUDGEMENT = "Judgement"
JUDGE = "Judge"
JUDGEMENT_BASIS = "Judgement Basis"

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


def get_existing_judgement(court_date, docket_id):
    return Judgement.query.filter_by(detainer_warrant_id=docket_id, court_date=court_date)


def _from_workbook(defaults, court_date, raw_judgement):
    judgement = {k: normalize(v) for k, v in raw_judgement.items()}

    docket_id = judgement[DOCKET_ID]

    if not bool(docket_id):
        return

    warrant, _ = get_or_create(db.session, DetainerWarrant,
                               docket_id=docket_id,
                               order_number=DetainerWarrant.calc_order_number(
                                   docket_id),
                               defaults={'last_edited_by_id': -1})

    plaintiff_attorney = None
    if judgement[PLAINTIFF_ATTORNEY]:
        plaintiff_attorney, _ = get_or_create(
            db.session, Attorney, name=judgement[PLAINTIFF_ATTORNEY], defaults=defaults)

    defendant_attorney = None
    if judgement[DEFENDANT_ATTORNEY]:
        defendant_attorney, _ = get_or_create(
            db.session, Attorney, name=judgement[DEFENDANT_ATTORNEY], defaults=defaults)

    plaintiff = None
    if judgement[PLAINTIFF]:
        plaintiff, _ = get_or_create(
            db.session, Plaintiff, name=judgement[PLAINTIFF], defaults=defaults)

    courtroom = None
    if judgement[COURTROOM]:
        courtroom, _ = get_or_create(
            db.session, Courtroom, name=judgement[COURTROOM].upper(), defaults=defaults)

    judge = None
    if judgement[JUDGE]:
        judge, _ = get_or_create(
            db.session, Judge, name=judgement[JUDGE], defaults=defaults)

    defendant_address = judgement[DEFENDANT_ADDRESS]
    if defendant_address and len(warrant.defendants) > 0:
        for defendant in warrant.defendants:
            if defendant.address is None:
                defendant.update(address=defendant_address)

    awards_possession, awards_fees, in_favor_of = None, None, None
    outcome = judgement[JUDGEMENT].lower() if judgement[JUDGEMENT] else None
    if outcome:
        in_favor_of = 'PLAINTIFF' if 'poss' in outcome or 'fees' in outcome else 'DEFENDANT'
        awards_possession = 'poss' in outcome
        try:
            awards_fees = Decimal(str(judgement[AMOUNT]).replace(
                '$', '').replace(',', '')) if 'fees' in outcome and judgement[AMOUNT] else None
        except KeyError:
            awards_fees = Decimal(str(judgement["Amount Awarded"]).replace(
                '$', '').replace(',', '')) if 'fees' in outcome and judgement["Amount Awarded"] else None

    basis = judgement[JUDGEMENT_BASIS].lower(
    ) if judgement[JUDGEMENT_BASIS] else None

    mediation_letter = judgement[MEDIATION_LETTER].lower(
    ) == 'yes' if judgement[MEDIATION_LETTER] else None
    dismissal_basis = extract_dismissal_basis(
        outcome, basis)
    notes = judgement[NOTES]

    judgement_values = dict(
        detainer_warrant_id=warrant.docket_id,
        court_date=court_date,
        courtroom_id=courtroom.id if courtroom else None,
        plaintiff_id=plaintiff.id if plaintiff else None,
        plaintiff_attorney_id=plaintiff_attorney.id if plaintiff_attorney else None,
        judge_id=judge.id if judge else None,
        defendant_attorney_id=defendant_attorney.id if defendant_attorney else None,
        in_favor_of_id=Judgement.parties[in_favor_of] if in_favor_of else None,
        awards_possession=awards_possession,
        awards_fees=awards_fees,
        mediation_letter=mediation_letter,
        dismissal_basis_id=Judgement.dismissal_bases[dismissal_basis] if dismissal_basis else None,
        notes=notes,
        last_edited_by_id=-1
    )

    existing_judgement = get_existing_judgement(court_date, docket_id)

    if (existing_judgement.count() > 0):
        existing_judgement.update(judgement_values)
        db.session.commit()
        return

    insert_stmt = insert(Judgement).values(
        **judgement_values
    )

    do_update_stmt = insert_stmt.on_conflict_do_update(
        constraint=Judgement.__table__.primary_key,
        set_=judgement_values
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

        judgements = all_rows[:stop_index] if limit else all_rows

        court_date = None
        for judgement in judgements:
            court_date = judgement[COURT_DATE] if judgement[COURT_DATE] else court_date
            _from_workbook(defaults, court_date, judgement)


def _from_dw_wb_row(raw_warrant):
    warrant = {k: normalize(v) for k, v in raw_warrant.items()}

    dw = db.session.query(DetainerWarrant).get(warrant["Docket #"])

    if not dw:
        return

    outcome = warrant['Judgement'].lower() if warrant['Judgement'] else None
    if outcome and len(dw._judgements) == 0:
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

        judgement = Judgement.create(
            detainer_warrant_id=dw.docket_id,
            in_favor_of_id=Judgement.parties[in_favor_of],
            awards_possession=awards_possession,
            awards_fees=awards_fees,
            courtroom_id=courtroom.id if courtroom else None,
            judge_id=presiding_judge.id if presiding_judge else None,
            _court_date=court_date_final
        )

        db.session.add(judgement)
        dw._judgements = dw._judgements + [judgement]
        db.session.add(dw)
        db.session.commit()


def from_dw_wb(workbook_name, limit=None, service_account_key=None):
    wb = open_workbook(workbook_name, service_account_key)
    warrants = dw_rows(limit, wb)
    for warrant in warrants:
        _from_dw_wb_row(warrant)
