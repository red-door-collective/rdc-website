from .models import db
from .models import Attorney, Courtroom, Defendant, DetainerWarrant, District, Judge, Judgement, Plaintiff, detainer_warrant_defendants
from .util import get_or_create, normalize
from sqlalchemy.exc import IntegrityError, InternalError
from sqlalchemy.dialects.postgresql import insert
from decimal import Decimal
from itertools import chain
import gspread
from datetime import datetime, date

DOCKET_ID = 'Docket #'
FILE_DATE = 'File_date'
STATUS = 'Status'
PLAINTIFF = 'Plaintiff'
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


class safelist(list):
    def get(self, index, default=None):
        try:
            return self.__getitem__(index)
        except IndexError:
            return default


def defendant_headers(index):
    prefix = f'Def_{index}_'
    return [f'{prefix}name', f'{prefix}first', f'{prefix}middle', f'{prefix}last', f'{prefix}suffix', f'{prefix}phone']


empty_defendant = ['' for i in range(6)]

header = [
    DOCKET_ID, FILE_DATE, STATUS, PLAINTIFF, PLTF_ATTORNEY, COURT_DATE, RECURRING_COURT_DATE, COURTROOM, JUDGE, AMT_CLAIMED, AMT_CLAIMED_CAT,
    IS_CARES, IS_LEGACY, NONPAYMENT, 'Zipcode', ADDRESS] + defendant_headers(1) + defendant_headers(2) + defendant_headers(3) + defendant_headers(4) + [JUDGEMENT, NOTES]


def date_str(d):
    return datetime.strftime(d, '%m/%d/%Y')


def defendant_columns(defendant):
    if defendant:
        return [defendant.name, defendant.first_name, defendant.middle_name, defendant.last_name,
                defendant.suffix, defendant.potential_phones]
    else:
        return empty_defendant


def _to_spreadsheet_row(warrant):
    return [dw if dw else '' for dw in list(chain.from_iterable([
        [
            warrant.docket_id,
            date_str(warrant.file_date) if warrant.file_date else '',
            warrant.status,
            warrant.plaintiff.name if warrant.plaintiff else '',
            warrant.plaintiff_attorney.name if warrant.plaintiff_attorney else '',
            date_str(warrant.court_date) if warrant.court_date else '',
            warrant.recurring_court_date if warrant.recurring_court_date else '',
            warrant.courtroom.name if warrant.courtroom else '',
            warrant.presiding_judge.name if warrant.presiding_judge else '',
            str(warrant.amount_claimed) if warrant.amount_claimed else '',
            warrant.amount_claimed_category,
            warrant.is_cares,
            warrant.is_legacy,
            warrant.nonpayment,
            warrant.zip_code,
            warrant.defendants[0].address if len(
                warrant.defendants) > 0 else ''
        ],
        list(chain.from_iterable([defendant_columns(safelist(
            warrant.defendants).get(index)) for index in range(4)])),
        [warrant.judgements[-1].summary if len(warrant.judgements) > 0 else '',
         warrant.notes
         ]
    ]))]


def to_spreadsheet(sheet_name, service_account_key=None):
    connect_kwargs = dict()
    if service_account_key:
        connect_kwargs['filename'] = service_account_key

    gc = gspread.service_account(**connect_kwargs)

    wks = gc.open(sheet_name).sheet1

    wks.update('A1:AP1', [header])

    warrants = DetainerWarrant.query.filter(
        DetainerWarrant.docket_id.ilike('%\G\T%'))

    rows = [_to_spreadsheet_row(warrant) for warrant in warrants]

    wks.update(f'A2:AP{warrants.count() + 1}', rows)


judgement_headers = ['Court Date', 'Docket #', 'Courtroom', 'Plaintiff', 'Pltf Lawyer', 'Defendant', 'Def Lawyer', 'Def. Address', 'Reason',
                     'Amount', '"Mediation Letter"', 'Notes (anything unusual on detainer or in', 'Judgement', 'Judge',	'Judgement Basis']


def _to_judgement_row(judgement):
    return [dw if dw else '' for dw in
            [
                date_str(judgement.court_date) if judgement.court_date else '',
                judgement.detainer_warrant_id,
                judgement.detainer_warrant.courtroom.name if judgement.detainer_warrant.courtroom else '',
                judgement.plaintiff.name if judgement.plaintiff else '',
                judgement.plaintiff_attorney.name if judgement.plaintiff_attorney else '',
                judgement.detainer_warrant.defendants[0].name if len(
                    judgement.detainer_warrant.defendants) > 0 else '',
                judgement.defendant_attorney.name if judgement.defendant_attorney else '',
                judgement.detainer_warrant.defendants[0].address if len(
                    judgement.detainer_warrant.defendants) > 0 else '',
                '',  # reason?
                str(judgement.awards_fees) if judgement.awards_fees else '',
                judgement.mediation_letter,
                judgement.notes,
                judgement.summary,
                judgement.judge.name if judgement.judge else '',
                judgement.dismissal_basis
            ]]


def to_judgement_sheet(sheet_name, service_account_key=None):
    connect_kwargs = dict()
    if service_account_key:
        connect_kwargs['filename'] = service_account_key

    gc = gspread.service_account(**connect_kwargs)

    judgements = Judgement.query.filter(
        Judgement.detainer_warrant_id.ilike('%\G\T%'))

    total = judgements.count()

    wb = gc.open(sheet_name)

    wks = wb.worksheet('Judgements')
    if not wks:
        wks = wb.add_worksheet(
            title="Judgements", rows=str(total + 1), cols="15")

    wks.update('A1:O1', [judgement_headers])

    rows = [_to_judgement_row(judgement) for judgement in judgements]

    wks.update(f'A2:O{total + 1}', rows)
