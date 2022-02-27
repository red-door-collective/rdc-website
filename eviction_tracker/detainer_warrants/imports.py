from .models import db
from .models import Attorney, Courtroom, Defendant, DetainerWarrant, Judge, Plaintiff, detainer_warrant_defendants
from .util import get_or_create, normalize, open_workbook, dw_rows
from sqlalchemy.exc import IntegrityError, InternalError
from sqlalchemy.orm.exc import MultipleResultsFound
from sqlalchemy.dialects.postgresql import insert
from decimal import Decimal
from datetime import datetime

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
        if value in ['No', 'Yes']:
            return value == 'Yes'
        else:
            return no_trailing if no_trailing not in ['', 'NA', 'Not Specified', 'Unknown'] else None
    else:
        return None


def create_defendant(number, warrant):
    prefix = f'Def_{number}_'
    first_name = warrant[prefix + 'first']
    middle_name = warrant[prefix + 'middle']
    last_name = warrant[prefix + 'last']
    suffix = warrant[prefix + 'suffix']
    phones = warrant.get(prefix + 'phone')

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


def money_to_dec(amt):
    return Decimal(str(amt).replace(
        '$', '').replace(',', ''))


def _from_workbook_row(raw_warrant):
    warrant = {k: normalize(v) for k, v in raw_warrant.items()}

    docket_id = warrant[DOCKET_ID]
    address = warrant[ADDRESS] if warrant[ADDRESS] else None
    is_cares = warrant[IS_CARES] in [
        True, 'MDHA'] if warrant[IS_CARES] else None
    is_legacy = warrant[IS_LEGACY] if warrant[IS_LEGACY] else None

    notes_from_nonpayment, is_nonpayment = None, None
    if type(warrant[NONPAYMENT]) is str:
        notes_from_nonpayment = warrant[NONPAYMENT]
    else:
        is_nonpayment = warrant[NONPAYMENT]

    amount_claimed = None
    if warrant[AMT_CLAIMED]:
        amount_claimed = money_to_dec(warrant[AMT_CLAIMED])
    claims_possession = warrant[AMT_CLAIMED_CAT] in [
        'POSS', 'BOTH'] if warrant[AMT_CLAIMED_CAT] else None
    notes = warrant[NOTES] if warrant[NOTES] else None
    if notes_from_nonpayment:
        notes = (notes if notes else '') + '\n' + notes_from_nonpayment

    defendant = create_defendant(1, warrant)
    defendant2 = create_defendant(2, warrant)
    defendant3 = create_defendant(3, warrant)

    dw = DetainerWarrant.query.get(docket_id)
    if dw:
        audit_status = 'CONFIRMED' if dw.audit_status == 'JUDGMENT_CONFIRMED' else 'ADDRESS_CONFIRMED'
        dw.update(
            address=address,
            amount_claimed=amount_claimed,
            claims_possession=claims_possession,
            is_cares=is_cares,
            is_legacy=is_legacy,
            nonpayment=is_nonpayment,
            notes=notes,
            audit_status_id=DetainerWarrant.audit_statuses[audit_status]
        )
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


def address_rows(workbook):
    all_rows = []
    for sheet in workbook.worksheets():
        all_rows.extend(sheet.get_all_records())

    return all_rows


def from_address_audits(workbook_name, service_account_key=None):
    wb = open_workbook(workbook_name, service_account_key)

    warrants = address_rows(wb)

    for warrant in warrants:
        dw = DetainerWarrant.query.get(warrant['Docket ID'])
        attrs = dict(address_certainty=1.0)

        if warrant['Correct Address'].strip():
            attrs['address'] = warrant['Correct Address'].strip()
        else:
            attrs['address'] = warrant['Automated Address Extraction Result'].strip()

        dw.update(**attrs)
        db.session.commit()


def from_historical_records(workbook_name, service_account_key=None):
    wb = open_workbook(workbook_name, service_account_key)

    warrants = wb.worksheet('01 2017 to 12 2019').get_all_records()

    for raw_warrant in warrants:
        warrant = {k: normalize(v) for k, v in raw_warrant.items()}
        docket_id = warrant['Docket_number']
        dw = DetainerWarrant.query.get(docket_id)

        if not dw:
            dw = DetainerWarrant.create(
                docket_id=warrant['Docket_number'],
                _file_date=datetime.strptime(warrant['File_date'], '%m/%d/%Y'),
                status=warrant['Status'],
                plaintiff=warrant['Plaintiff'],
                plaintiff_attorney=warrant['Plaintiff_atty']
            )
            db.session.commit()

        if warrant['Address']:
            dw.update(
                address=warrant['Address'],
                address_certainty=1.0
            )
            db.session.commit()

        defendant = create_defendant(1, warrant)
        defendant2 = create_defendant(2, warrant)
        defendant3 = create_defendant(3, warrant)

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

        # TODO: gather hearing and judgment dates via CaseLink
        # claims_possession, in_favor_of = None, None
        # if warrant['Judgment']:
        #     if 'POSS' in warrant['Judgment']:
        #         claims_possession = True

        #     in_favor_of = 'PLAINTIFF'
        #     if warrant['Judgment'] in ['Dismissed', 'Non-suit']:
        #         in_favor_of = 'DEFENDANT'

        # awards_fees = None
        # if warrant['Judgment_amt'] and warrant['Judgment_amt'] != '$0.00':
        #     awards_fees = money_to_dec(warrant['Judgment_amt'])
