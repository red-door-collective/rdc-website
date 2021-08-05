from .models import db
from .models import Attorney, Courtroom, Defendant, DetainerWarrant, District, Judge, Judgement, Plaintiff, detainer_warrant_defendants
from .util import open_workbook, get_gc
from sqlalchemy.exc import IntegrityError, InternalError
from sqlalchemy.dialects.postgresql import insert
from decimal import Decimal
from itertools import chain
import gspread
from gspread_formatting import *
from datetime import datetime, date, timedelta
import usaddress
from eviction_tracker.monitoring import log_on_exception
import jellyfish
import itertools

import logging
import logging.config
import traceback
import eviction_tracker.config as config

logging.config.dictConfig(config.LOGGING)
logger = logging.getLogger(__name__)

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


def defendant_name(defendant):
    if defendant:
        return defendant.name
    else:
        return ''


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


def get_or_create_sheet(wb, name, rows=100, cols=25):
    try:
        return wb.worksheet(name)
    except gspread.exceptions.GSpreadException:
        return wb.add_worksheet(
            title=name, rows=str(rows), cols=str(cols))


@log_on_exception
def to_spreadsheet(workbook_name, service_account_key=None):
    wb = open_workbook(workbook_name, service_account_key)

    warrants = DetainerWarrant.query.filter(
        DetainerWarrant.docket_id.ilike('%\G\T%'))

    total = warrants.count()

    wks = get_or_create_sheet(wb,
                              'Detainer Warrants', rows=total + 1, cols=len(header))

    wks.update('A1:AP1', [header])

    rows = [_to_spreadsheet_row(warrant) for warrant in warrants]

    wks.update(f'A2:AP{total + 1}', rows)


judgement_headers = ['Court Date', 'Docket #', 'Courtroom', 'Plaintiff', 'Pltf Lawyer', 'Defendant', 'Def Lawyer', 'Def. Address', 'Reason',
                     'Amount', '"Mediation Letter"', 'Notes (anything unusual on detainer or in', 'Judgement', 'Judge',	'Judgement Basis']


def defendant_names_column(warrant):
    return ' | '.join([defendant.name for defendant in warrant.defendants])


def defendant_names_column_newline(warrant):
    names = [defendant.name for defendant in warrant.defendants]
    dupes = [a for a, b in itertools.combinations(
        list(names), 2) if jellyfish.damerau_levenshtein_distance(a, b) <= 1]
    deduped = list(
        set(list(names)) - set(dupes))
    return '\n'.join(deduped)


def _to_judgement_row(judgement):
    return [dw if dw else '' for dw in
            [
                date_str(judgement.court_date) if judgement.court_date else '',
                judgement.detainer_warrant_id,
                judgement.detainer_warrant.courtroom.name if judgement.detainer_warrant.courtroom else '',
                judgement.plaintiff.name if judgement.plaintiff else '',
                judgement.plaintiff_attorney.name if judgement.plaintiff_attorney else '',
                defendant_names_column(judgement.detainer_warrant),
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


@log_on_exception
def to_judgement_sheet(workbook_name, service_account_key=None):
    wb = open_workbook(workbook_name, service_account_key)

    judgements = Judgement.query.filter(
        Judgement.detainer_warrant_id.ilike('%\G\T%'))

    total = judgements.count()

    wks = get_or_create_sheet(wb,
                              'Judgements', rows=total + 1, cols=len(judgement_headers))

    wks.update('A1:O1', [judgement_headers])

    rows = [_to_judgement_row(judgement) for judgement in judgements]

    wks.update(f'A2:O{total + 1}', rows)


court_watch_headers = ['Court Date', 'Docket #', 'Defendant',
                       'Address', 'Zipcode', 'Defendant 2', 'Defendant 3', 'Defendant 4',
                       'Plaintiff', 'Plaintiff Attorney', 'Courtroom', 'Notes']


def format_address(pieces):
    city = pieces.get('PlaceName', '')
    if city:
        city = ', ' + city
    return ' '.join([address for piece, address in pieces.items()
                     if piece not in ['ZipCode', 'StateName', 'PlaceName']]) + city


def bad_export_row(warrant):
    return [warrant.docket_id if index == 1 else '' for index,
            header in enumerate(court_watch_headers)]


def _to_court_watch_row(warrant):
    full_address = warrant.defendants[0].address if len(
        warrant.defendants) > 0 else ''
    if full_address is None:
        return
    address, zip_code = '', ''
    try:
        pieces, label = usaddress.tag(full_address)
        address = format_address(pieces)
        zip_code = pieces.get('ZipCode', '')
    except usaddress.RepeatedLabelError as e:
        address = e.original_string
        logger.info('original ambiguous address', address)
        zip_code_potential = [
            val for (val, iden) in e.parsed_string if iden == 'ZipCode']
        zip_code = zip_code_potential[0] if len(zip_code_potential) > 0 else ''

    return [dw if dw else '' for dw in list(chain.from_iterable([
        [
            date_str(warrant.court_date) if warrant.court_date else '',
            warrant.docket_id,
            warrant.defendants[0].name if len(
                warrant.defendants) > 0 else '',
            address,
            zip_code
        ],
        [defendant_name(safelist(warrant.defendants).get(index))
         for index in range(1, 4)],
        [
            warrant.plaintiff.name if warrant.plaintiff else '',
            warrant.plaintiff_attorney.name if warrant.plaintiff_attorney else '',
            warrant.courtroom.name if warrant.courtroom else '',
            warrant.notes
        ]
    ]))]


def _try_court_watch_row(warrant):
    try:
        return _to_court_watch_row(warrant)
    except:
        logger.error("uncaught exception: %s", traceback.format_exc())
        return bad_export_row(warrant)


@log_on_exception
def to_court_watch_sheet(workbook_name, service_account_key=None):
    wb = open_workbook(workbook_name, service_account_key)

    warrants = DetainerWarrant.query.filter(
        DetainerWarrant.docket_id.ilike('%\G\T%'),
        DetainerWarrant.court_date != None,
        DetainerWarrant.court_date >= date.today()
    ).order_by(DetainerWarrant.plaintiff_id.desc(), DetainerWarrant.court_date.desc())

    total = warrants.count()

    wks = get_or_create_sheet(wb,
                              'Court Watch', rows=total + 1, cols=len(court_watch_headers))

    wks.clear()

    wks.update('A1:L1', [court_watch_headers])

    rows = [_try_court_watch_row(warrant) for warrant in warrants]

    wks.update(f'A2:L{total + 1}', rows)


COURTROOM_DOCKET_HEADERS = ['Defendant Names', 'Present?',
                            'Demographics', 'Plaintiff', 'Plaintiff Attorney', 'Docket #', 'Notes']


def _courtroom_entry_row(docket):
    return [
        defendant_names_column_newline(docket.detainer_warrant),
        '',
        '',
        docket.plaintiff.name if docket.plaintiff else '',
        docket.plaintiff_attorney.name if docket.plaintiff_attorney else '',
        docket.detainer_warrant_id,
        ''
    ]


CELL_FORMAT = cellFormat(
    backgroundColor=color(1, 1, 1),
    textFormat=textFormat(foregroundColor=color(
        0, 0, 0)),
    wrapStrategy='WRAP'
)


def _to_courtroom_entry_sheet(wb, date, courtroom, judgements):
    dockets = judgements.filter_by(courtroom_id=courtroom.id)
    total = dockets.count()
    if total == 0:
        return

    date_of_month = datetime.strftime(date, '%d')
    wks = get_or_create_sheet(wb,
                              f'{date_of_month} {courtroom.name}',
                              rows=total + 1,
                              cols=len(COURTROOM_DOCKET_HEADERS))

    wks.update('A1:G1', [COURTROOM_DOCKET_HEADERS])

    rows = [_courtroom_entry_row(docket) for docket in dockets]

    wks.update(f'A2:G{total + 1}', rows)

    set_row_height(wks, f'1:{total + 1}', 80)
    set_column_width(wks, 'A', 250)
    set_column_width(wks, 'B', 75)
    set_column_width(wks, 'C', 100)
    set_column_width(wks, 'D', 250)
    set_column_width(wks, 'E', 250)
    set_column_width(wks, 'F', 100)
    set_column_width(wks, 'G', 300)

    format_cell_range(wks, f'A1:G1', cellFormat(
        backgroundColor=color(0.925, 0.925, 0.925), textFormat=textFormat(bold=True)))
    format_cell_range(wks, f'A2:G{total + 1}', CELL_FORMAT)


def to_courtroom_entry_workbook(date, service_account_key=None):
    workbook_name = f'{datetime.strftime(date, "%B %Y")} Court Watch'
    try:
        wb = open_workbook(workbook_name, service_account_key)
    except gspread.exceptions.SpreadsheetNotFound:
        wb = get_gc(service_account_key).create(workbook_name)
        wb.share('reddoormidtn@gmail.com', perm_type='user', role='owner')

    courtroom_1a = Courtroom.query.filter_by(name='1A').first()
    courtroom_1b = Courtroom.query.filter_by(name='1B').first()
    if not courtroom_1a or not courtroom_1b:
        logger.error('cannot find courtrooms for entry sheet generation!')
        return

    judgements = Judgement.query.filter(
        Judgement.court_date != None,
        Judgement.court_date == date,
    ).order_by(Judgement.court_order_number)

    _to_courtroom_entry_sheet(wb, date, courtroom_1a, judgements)
    _to_courtroom_entry_sheet(wb, date, courtroom_1b, judgements)
    logger.info(f'Exported courtroom sheets for 1A + 1B on {date_str(date)}')


def weekly_courtroom_entry_workbook(date, service_account_key=None):
    day_delta = timedelta(days=1)
    week = [day_delta * num + date for num in range(7)]
    for day in week:
        to_courtroom_entry_workbook(
            day, service_account_key=service_account_key)
