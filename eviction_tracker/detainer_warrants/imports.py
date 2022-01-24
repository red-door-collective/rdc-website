from .models import db
from .models import Attorney, Courtroom, Defendant, DetainerWarrant, Judge, Plaintiff, detainer_warrant_defendants
from .util import get_or_create, normalize, open_workbook, dw_rows
from sqlalchemy.exc import IntegrityError, InternalError
from sqlalchemy.orm.exc import MultipleResultsFound
from sqlalchemy.dialects.postgresql import insert
from decimal import Decimal

DOCKET_ID = 'Docket #'
FILE_DATE = 'File_date'
STATUS = 'Status'
PLAINTIFF = 'Plaintiff'
PLTF_ATTORNEY = 'Plaintiff_atty'
RECURRING_COURT_DATE = 'Any_day'
AMT_CLAIMED = 'Amount_claimed_num'
AMT_CLAIMED_CAT = 'Amount_claimed_cat'
IS_CARES = 'CARES'
IS_LEGACY = 'LEGACY'
NONPAYMENT = 'Nonpayment'
ADDRESS = 'Address'
NOTES = 'Notes'


def normalize(value):
    if type(value) is int:
        return value
    elif type(value) is str:
        no_trailing = value.strip()
        return no_trailing if no_trailing not in ['', 'NA'] else None
    else:
        return None


def create_defendant(number, warrant):
    prefix = f'Def_{number}_'
    first_name = warrant[prefix + 'first']
    middle_name = warrant[prefix + 'middle']
    last_name = warrant[prefix + 'last']
    suffix = warrant[prefix + 'suffix']
    phones = warrant[prefix + 'phone']

    defendant = None
    if bool(first_name) or bool(phones):
        try:
            defendant, _ = get_or_create(
                db.session, Defendant,
                first_name=first_name,
                middle_name=middle_name,
                last_name=last_name,
                suffix=suffix,
                potential_phones=phones
            )
        except MultipleResultsFound:
            return Defendant.query.filter_by(first_name=first_name,
                                             middle_name=middle_name,
                                             last_name=last_name,
                                             suffix=suffix,
                                             potential_phones=phones).first()
    return defendant


def link_defendant(docket_id, defendant):
    db.session.execute(insert(detainer_warrant_defendants)
                       .values(detainer_warrant_docket_id=docket_id, defendant_id=defendant.id))


def _from_workbook_row(raw_warrant):
    warrant = {k: normalize(v) for k, v in raw_warrant.items()}

    docket_id = warrant[DOCKET_ID]
    address = warrant[ADDRESS] if warrant[ADDRESS] else None

    defendant = create_defendant(1, warrant)
    defendant2 = create_defendant(2, warrant)
    defendant3 = create_defendant(3, warrant)

    dw = DetainerWarrant.query.get(docket_id)
    if dw:
        dw.update(address=address)
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


def from_workbook_help(warrants):
    for warrant in warrants:
        _from_workbook_row(warrant)


def from_workbook(workbook_name, limit=None, service_account_key=None):
    wb = open_workbook(workbook_name, service_account_key)

    warrants = dw_rows(limit, wb)

    from_workbook_help(warrants)
