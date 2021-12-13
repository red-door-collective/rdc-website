from nameparser import HumanName
from pyquery import PyQuery as pq
import re
import requests
from sqlalchemy.exc import IntegrityError, InternalError
from sqlalchemy.orm.exc import MultipleResultsFound
from sqlalchemy.dialects.postgresql import insert
from datetime import date, datetime, timedelta
from pdfminer.layout import LAParams
from pdfminer.high_level import extract_text_to_fp
import io

from ..models import db, Attorney, Case, Courtroom, Defendant, District, Judge, Hearing, Plaintiff, hearing_defendants
from ..util import get_or_create, normalize, district_defaults

CASELINK_URL = 'https://caselink.nashville.gov'
URL = f'{CASELINK_URL}/cgi-bin/webshell.asp'
DATA = {
    'GATEWAY': 'GATEWAY',
    'XGATEWAY': 'SessionsDocketInfo',
    'CGISCRIPT': 'webshell.asp',
    'XEVENT': 'VERIFY',
    'WEBIOHANDLE': '1639361164289',
    'MYPARENT': 'px',
    'APPID': 'dav',
    'WEBWORDSKEY': 'SAMPLE',
    'DEVPATH': '/INNOVISION/DEVELOPMENT/DAVMAIN.DEV',
    'OPERCODE': 'dummy',
    'PASSWD': 'dummy'
}

DOCKET_INDENT = 30


def create_defendant(defaults, docket_id, name):
    if 'ALL OTHER OCCUPANTS' in name:
        return None

    name = HumanName(name.replace('OR ALL OCCUPANTS', ''))
    if Hearing.query.filter(
        Hearing.docket_id == docket_id,
        Hearing.defendants.any(
            first_name=name.first, last_name=name.last)
    ).first():
        return

    defendant = None
    if name.first:
        try:
            defendant, _ = get_or_create(
                db.session, Defendant,
                first_name=name.first,
                middle_name=name.middle,
                last_name=name.last,
                suffix=name.suffix,
                defaults=defaults
            )
        except:
            return Defendant.query.filter_by(first_name=name.first,
                                             middle_name=name.middle,
                                             last_name=name.last,
                                             suffix=name.suffix,
                                             ).first()

    return defendant


def insert_hearing(defaults, docket_id, listing):
    attorney = None
    if listing['plaintiff_attorney']:
        attorney, _ = get_or_create(
            db.session, Attorney, name=listing['plaintiff_attorney'], defaults=defaults)

    plaintiff = None
    if listing['plaintiff']:
        plaintiff, _ = get_or_create(
            db.session, Plaintiff, name=listing['plaintiff'], defaults=defaults)

    court_date = listing['court_date']

    courtroom = None
    if listing['courtroom']:
        courtroom, _ = get_or_create(
            db.session, Courtroom, name=listing['courtroom'], defaults=defaults)

    existing_case, _ = get_or_create(
        db.session, Case, docket_id=docket_id)

    defendants = [create_defendant(defaults, docket_id, defendant)
                  for defendant in listing['defendants']]

    hearing, _ = get_or_create(db.session, Hearing,
                               _court_date=court_date,
                               docket_id=docket_id,
                               address=listing['address']
                               )

    hearing.update(
        courtroom_id=courtroom.id if courtroom else None,
        plaintiff_id=plaintiff.id if plaintiff else None,
        plaintiff_attorney_id=attorney.id if attorney else None,
        court_order_number=listing['court_order_number']
    )

    for defendant in defendants:
        if defendant:
            link_defendant(hearing.id, defendant)

    db.session.commit()

    return hearing


def link_defendant(hearing_id, defendant):
    db.session.execute(insert(hearing_defendants)
                       .values(hearing_id=hearing_id, defendant_id=defendant.id))


def parse_court_date(tr):
    text = [line for line in tr.splitlines() if line.startswith('Court Date')][0]
    court_date = text[COURT_DATE_INDEX:COURT_DATE_TIME_LABEL_INDEX].strip()
    time = text[COURT_DATE_TIME_INDEX:COURT_DATE_TIME_INDEX + 6].strip()
    return datetime.strptime(court_date + ' ' + time, '%m.%d.%y %H:%M')


def extract_html_from_pdf(pdf):
    output_string = io.StringIO()
    params = LAParams(
        all_texts=False,
        boxes_flow=0.5,
        line_margin=0.5,
        word_margin=0.1,
        char_margin=2.0,
        detect_vertical=False
    )
    extract_text_to_fp(pdf, output_string,
                       laparams=params, output_type='html', codec=None)

    return output_string.getvalue().strip()


def fetch_pdf(url):
    response = requests.get(url)
    pdf_memory_file = io.BytesIO()
    pdf_memory_file.write(response.content)
    return pdf_memory_file


def via_indent(d, indents):
    style_selectors = ','.join(
        [f'[style*="left:{indent}px"]' for indent in indents])
    return d(f'div{style_selectors}')


def via_top(d, offset):
    return d(f'div[style*="top:{offset}px"]')


def extract_top(node):
    return int(re.compile(r'top:(\d+)').search(node.attr('style')).group(1))


def nearest_page_header(d, docket_top):
    headers = via_indent(d, [306, 289])
    closest_top = 0
    for header in headers:
        candidate = extract_top(pq(header))
        if candidate < docket_top and candidate > closest_top:
            closest_top = candidate

    return via_top(d, closest_top)


COURTROOM_REGEX = re.compile(r'Court\s*Room\s+(\d\w)')

COURT_DATE_REGEX = re.compile(
    r'(\d{2}/\d{2}/\d{4})\s+Time:\s+(\d+:\d+\w{2})')


def parse_court_date(text):
    match = COURT_DATE_REGEX.search(text)
    court_date = match.group(1)
    time = match.group(2)
    return datetime.strptime(court_date + ' ' + time, '%m/%d/%Y %I:%M%p')


def parse_html(html):
    defaults = district_defaults()

    d = pq(html)
    courtroom = COURTROOM_REGEX.search(d.text()).group(1)

    cases = {}
    docket_cells = sorted(via_indent(
        d, [30, 33]), key=lambda c: extract_top(pq(c)))

    for court_order_number, docket_id_cell in enumerate(docket_cells):
        cell = pq(docket_id_cell)
        top = extract_top(cell)
        docket_id = cell.text().strip()
        for index, column in enumerate(via_top(d, top)):
            if index == 0:
                continue
            elif index == 1:
                spans = pq(column).find('span')
                cases[docket_id] = {
                    'court_order_number': court_order_number,
                    'court_date': parse_court_date(nearest_page_header(d, top).text()),
                    'courtroom': courtroom,
                    'plaintiff': spans.eq(0).text().strip(),
                    'plaintiff_attorney': spans.eq(1).text().strip(),
                    'defendants': []
                }
            else:
                defendants = pq(column).text().split('---------------')
                cases[docket_id]['address'] = ' '.join(
                    defendants[0].splitlines()[1:]).strip()
                for defendant in defendants:
                    cases[docket_id]['defendants'].append(
                        defendant.splitlines()[0].strip())
    return [insert_hearing(defaults, docket_id, listing) for docket_id, listing in cases.items()]


def scrape_docket(url):
    return parse_html(extract_html_from_pdf(fetch_pdf(url)))


def scrape():
    links = requests.get(URL, data=DATA).json()
    for link in links:
        docket_url = f'{CASELINK_URL}{link[-1]}'
        scrape_docket(docket_url)
