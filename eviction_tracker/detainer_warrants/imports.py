from .models import db
from .models import Attorney, Courtroom, Defendant, DetainerWarrant, District, Judge, Plantiff, detainer_warrant_defendants
from .util import get_or_create
from sqlalchemy.exc import IntegrityError, InternalError
from sqlalchemy.dialects.postgresql import insert

DOCKET_ID = 'Docket #'
FILE_DATE = 'File Date'
STATUS = 'Status'
PLANTIFF = 'Plantiff'
PLTF_ATTORNEY = 'Pltf. Attorney'
COURT_DATE = 'Court Date'
COURTROOM = 'Courtroom'
JUDGE = 'Presiding Judge'
AMT_CLAIMED = 'Amt Claimed ($)'
AMT_CLAIMED_CAT = 'Amount Claimed (CATEGORY)'
IS_CARES = 'CARES covered property?'
IS_LEGACY = 'LEGACY Case'
ADDRESS = 'Defendant Address'
ZIP_CODE = 'Zip code'
JUDGEMENT = 'Judgement'


def normalize(value):
    if type(value) is int:
        return value
    elif type(value) is str:
        return value.strip() if value.strip() else None
    else:
        return None


def create_defendant(defaults, number, warrant):
    name = warrant[f'Def #{number} Name']
    phones = warrant[f'Def #{number} Phone']
    address = warrant[ADDRESS]

    defendant = None
    if bool(name) or bool(phones):
        defendant, _ = get_or_create(
            db.session, Defendant, name=name, potential_phones=phones, address=address, defaults=defaults
        )
    return defendant


def link_defendant(docket_id, defendant):
    db.session.execute(insert(detainer_warrant_defendants)
                       .values(detainer_warrant_docket_id=docket_id, defendant_id=defendant.id))


def _from_spreadsheet_row(raw_warrant, defaults):
    warrant = {k: normalize(v) for k, v in raw_warrant.items()}

    docket_id = warrant[DOCKET_ID]
    file_date = warrant[FILE_DATE]
    status = warrant[STATUS]
    attorney, _ = get_or_create(
        db.session, Attorney, name=warrant[PLTF_ATTORNEY], defaults=defaults)

    plantiff = None
    if warrant[PLANTIFF]:
        plantiff, _ = get_or_create(
            db.session, Plantiff, name=warrant[PLANTIFF], attorney=attorney, defaults=defaults)

    court_date = warrant[COURT_DATE]

    courtroom = None
    if warrant[COURTROOM]:
        courtroom, _ = get_or_create(
            db.session, Courtroom, name=warrant[COURTROOM], defaults=defaults)

    presiding_judge = None
    if warrant[JUDGE]:
        presiding_judge, _ = get_or_create(
            db.session, Judge, name=warrant[JUDGE], defaults=defaults)

    amount_claimed = warrant[AMT_CLAIMED]
    amount_claimed_category = warrant[AMT_CLAIMED_CAT] or 'N/A'
    is_cares = warrant[IS_CARES] == 'Yes' if warrant[IS_CARES] else None
    is_legacy = warrant[IS_LEGACY] == 'Yes' if warrant[IS_LEGACY] else None
    zip_code = warrant[ZIP_CODE]

    defendant = create_defendant(defaults, 1, warrant)
    defendant2 = create_defendant(defaults, 2, warrant)
    defendant3 = create_defendant(defaults, 3, warrant)

    judgement = warrant[JUDGEMENT] or 'N/A'

    dw_values = dict(docket_id=docket_id,
                     file_date=file_date,
                     status_id=DetainerWarrant.statuses[status],
                     plantiff_id=plantiff.id if plantiff else None,
                     court_date=court_date,
                     courtroom_id=courtroom.id if courtroom else None,
                     presiding_judge_id=presiding_judge.id if presiding_judge else None,
                     amount_claimed=amount_claimed,
                     amount_claimed_category_id=DetainerWarrant.amount_claimed_categories[
                         amount_claimed_category.upper()],
                     is_cares=is_cares,
                     is_legacy=is_legacy,
                     zip_code=zip_code,
                     judgement_id=DetainerWarrant.judgements[judgement.upper()]
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
