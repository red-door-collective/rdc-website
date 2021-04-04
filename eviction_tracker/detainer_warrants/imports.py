from .models import db
from .models import Attorney, Courtroom, Defendant, DetainerWarrant, District, Judge, Plantiff, detainer_warrant_defendants
from .util import get_or_create
from sqlalchemy.exc import IntegrityError, InternalError
from sqlalchemy.dialects.postgresql import insert
from decimal import Decimal

DOCKET_ID = 'Docket_number'
FILE_DATE = 'File_date'
STATUS = 'Status'
PLANTIFF = 'Plantiff'
PLTF_ATTORNEY = 'Plaintiff_atty'
COURT_DATE = 'Court_date'
RECURRING_COURT_DATE = 'Any_day'
COURTROOM = 'Courtroom'
JUDGE = 'Presiding_judge'
AMT_CLAIMED = 'Amount_claimed_num'
AMT_CLAIMED_CAT = 'Amount_claimed_cat'
IS_CARES = 'CARES'
IS_LEGACY = 'LEGACY'
NONPAYMENT = 'Nonpayment'
ADDRESS = 'Address'
JUDGEMENT = 'Judgement'
NOTES = 'Notes'


def normalize(value):
    if type(value) is int:
        return value
    elif type(value) is str:
        no_trailing = value.strip()
        return no_trailing if no_trailing not in ['', 'NA'] else None
    else:
        return None


def create_defendant(defaults, number, warrant):
    prefix = f'Def_{number}_'
    first_name = warrant[prefix + 'first']
    middle_name = warrant[prefix + 'middle']
    last_name = warrant[prefix + 'last']
    suffix = warrant[prefix + 'suffix']
    phones = warrant[prefix + 'phone']
    address = warrant[ADDRESS]

    defendant = None
    if bool(first_name) or bool(phones):
        defendant, _ = get_or_create(
            db.session, Defendant,
            first_name=first_name,
            middle_name=middle_name,
            last_name=last_name,
            suffix=suffix,
            potential_phones=phones, address=address, defaults=defaults
        )
    return defendant


def link_defendant(docket_id, defendant):
    db.session.execute(insert(detainer_warrant_defendants)
                       .values(detainer_warrant_docket_id=docket_id, defendant_id=defendant.id))


def extract_raw_court_data(court_date):
    exceptions = []  # [None, 'Any Tuesday', 'Any Tues', 'Any Weds', 'Soonest Tuesday', 'Soonest Friday', 'NA - Continuance - Positive for Covid',
    # 'NA - "any Tuesday"', 'Non-suit retracted', 'TBD / Not Serviced', 'TBD', 'not stated', '(1/7/21) needs update', 'TBD / 12/4/20', 'Earliest Thurs']
    if court_date in exceptions:
        return None
    else:
        return court_date


def _from_spreadsheet_row(raw_warrant, defaults):
    warrant = {k: normalize(v) for k, v in raw_warrant.items()}

    docket_id = warrant[DOCKET_ID]
    file_date = warrant[FILE_DATE]
    status = warrant[STATUS]

    attorney = None
    if warrant[PLTF_ATTORNEY]:
        attorney, _ = get_or_create(
            db.session, Attorney, name=warrant[PLTF_ATTORNEY], defaults=defaults)

    plantiff = None
    if warrant[PLANTIFF]:
        plantiff, _ = get_or_create(
            db.session, Plantiff, name=warrant[PLANTIFF], attorney=attorney, defaults=defaults)

    court_date = extract_raw_court_data(warrant[COURT_DATE])
    recurring_court_date = warrant[RECURRING_COURT_DATE]

    courtroom = None
    if warrant[COURTROOM]:
        courtroom, _ = get_or_create(
            db.session, Courtroom, name=warrant[COURTROOM], defaults=defaults)

    presiding_judge = None
    if warrant[JUDGE]:
        presiding_judge, _ = get_or_create(
            db.session, Judge, name=warrant[JUDGE], defaults=defaults)

    amount_claimed = Decimal(str(warrant[AMT_CLAIMED]).replace(
        '$', '').replace(',', '')) if warrant[AMT_CLAIMED] else None
    amount_claimed_category = warrant[AMT_CLAIMED_CAT] or 'N/A'
    is_cares = warrant[IS_CARES] == 'Yes' if warrant[IS_CARES] else None
    is_legacy = warrant[IS_LEGACY] == 'Yes' if warrant[IS_LEGACY] else None
    nonpayment = warrant[NONPAYMENT] == 'Yes' if warrant[NONPAYMENT] else None

    defendant = create_defendant(defaults, 1, warrant)
    defendant2 = create_defendant(defaults, 2, warrant)
    defendant3 = create_defendant(defaults, 3, warrant)

    judgement = warrant[JUDGEMENT] or 'N/A'

    notes = warrant[NOTES]

    dw_values = dict(docket_id=docket_id,
                     file_date=file_date,
                     status_id=DetainerWarrant.statuses[status],
                     plantiff_id=plantiff.id if plantiff else None,
                     court_date='11/3/2020' if court_date == '11/3' else court_date,
                     court_date_recurring_id=DetainerWarrant.recurring_court_dates[
                         recurring_court_date] if recurring_court_date else None,
                     courtroom_id=courtroom.id if courtroom else None,
                     presiding_judge_id=presiding_judge.id if presiding_judge else None,
                     amount_claimed=amount_claimed,
                     amount_claimed_category_id=DetainerWarrant.amount_claimed_categories[
                         amount_claimed_category.upper()],
                     is_cares=is_cares,
                     is_legacy=is_legacy,
                     nonpayment=nonpayment,
                     judgement_id=DetainerWarrant.judgements[judgement.upper(
                     )],
                     notes=notes
                     )

    insert_stmt = insert(DetainerWarrant).values(
        **dw_values
    )

    do_update_stmt = insert_stmt.on_conflict_do_update(
        constraint=DetainerWarrant.__table__.primary_key,
        set_=dw_values
    )

    db.session.execute(do_update_stmt)
    db.session.commit()

    try:
        if defendant:
            link_defendant(docket_id, defendant)
        if defendant2:
            link_defendant(docket_id, defendant2)
        if defendant3:
            link_defendant(docket_id, defendant3)

    except IntegrityError:
        pass

    db.session.commit()


def from_spreadsheet(warrants):
    district, _ = get_or_create(db.session, District, name="Davidson County")

    db.session.add(district)
    db.session.commit()

    defaults = {'district': district}

    for warrant in warrants:
        _from_spreadsheet_row(warrant, defaults)
