from nameparser import HumanName
from pyquery import PyQuery as pq
import re
import requests
from sqlalchemy.exc import IntegrityError, InternalError
from sqlalchemy.orm.exc import MultipleResultsFound
from sqlalchemy.dialects.postgresql import insert
from datetime import date, datetime, timedelta

from ..models import db, Attorney, Case, Courtroom, Defendant, District, Judge, Hearing, Plaintiff, hearing_defendants
from ..util import get_or_create, normalize, district_defaults

SITE = "http://circuitclerk.nashville.gov/dockets/viewdocket_c.asp"

DDID = "ddid"
DATE = "date"
TIME = "time"
LOC = "loc"
SN = "sn"
SN2 = "sn2"

COURT_DATE_INDEX = 14
COURT_DATE_TIME_LABEL_INDEX = 28
COURT_DATE_TIME_INDEX = 34
DOCKET_ID_INDEX = 0
CONT_INDEX = 17
PLAINTIFF_INDEX = 28
DEFENDANT_INDEX = 77
PLAINTIFF_ATTORNEY_INDEX = 148
DEFENDANT_ADDRESS_INDEX = 197
DEFENDANT_ADDRESS_2_INDEX = 315
DEFENDANT_ADDRESS_3_INDEX = 400

COURTROOMS = {
    '1A': 91,
    '1B': 73
}

LOCATIONS = {
    '1A': 72,
    '1B': 12
}


def create_defendant(defaults, docket_id, listing):
    if 'ALL OTHER OCCUPANTS' in listing['name']:
        return None

    name = HumanName(listing['name'].replace('OR ALL OCCUPANTS', ''))
    if Hearing.query.filter(
        Hearing.docket_id == docket_id,
        Hearing.defendants.any(
            first_name=name.first, last_name=name.last)
    ).first():
        return

    address = listing['address']

    defendant = None
    if name.first:
        try:
            defendant, _ = get_or_create(
                db.session, Defendant,
                first_name=name.first,
                middle_name=name.middle,
                last_name=name.last,
                suffix=name.suffix,
                address=address,
                defaults=defaults
            )
        except MultipleResultsFound:
            return Defendant.query.filter_by(first_name=name.first,
                                             middle_name=name.middle,
                                             last_name=name.last,
                                             suffix=name.suffix,
                                             address=address).first()

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
                               address=defendants[0].address
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


def normalize_multiline_field(text):
    return re.sub(r'\s{2}', ' ', re.sub(r'\s{2,}|\n|\r', ' ', text)).strip()


def parse_court_date(tr):
    text = [line for line in tr.splitlines() if line.startswith('Court Date')][0]
    court_date = text[COURT_DATE_INDEX:COURT_DATE_TIME_LABEL_INDEX].strip()
    time = text[COURT_DATE_TIME_INDEX:COURT_DATE_TIME_INDEX + 6].strip()
    return datetime.strptime(court_date + ' ' + time, '%m.%d.%y %H:%M')


def parse(courtroom, text):
    d = pq(text)
    content = d("pre").eq(0).text(squash_space=False)

    docket_id_regex = re.compile(r'(\d{2}\w{2}\d+)\s+')
    cur_docket_id = None
    latest_court_date = None
    cases = {}
    court_order_number = 0
    for tr in re.sub(r'\r\n', '', re.sub(r'-{4,}', '|', content)).split('|'):
        docket_match = docket_id_regex.search(tr[DOCKET_ID_INDEX:CONT_INDEX])
        if docket_match:  # new docket
            attorney = tr[PLAINTIFF_ATTORNEY_INDEX:DEFENDANT_ADDRESS_INDEX].strip()
            cur_docket_id = docket_match.group(1)
            print('cur_docket_id:', cur_docket_id)
            cases[cur_docket_id] = {
                'plaintiff': tr[PLAINTIFF_INDEX:DEFENDANT_INDEX].strip(),
                'plaintiff_attorney': 'Plaintiff Representing Self' if attorney in [', PRS', 'PRS'] else attorney,
                'defendants': [{
                    'name': tr[DEFENDANT_INDEX:PLAINTIFF_ATTORNEY_INDEX].strip(),
                    'address': normalize_multiline_field(tr[DEFENDANT_ADDRESS_INDEX:])
                }],
                'court_date': latest_court_date,
                'courtroom': courtroom,
                'court_order_number': court_order_number
            }
            court_order_number += 1
        elif 'GENERAL SESSIONS' in tr:
            latest_court_date = parse_court_date(tr)
            continue
        else:  # still in an existing docket entry
            cases[cur_docket_id]['defendants'].append({
                'name': tr[DEFENDANT_INDEX:PLAINTIFF_ATTORNEY_INDEX].strip(),
                'address': normalize_multiline_field(tr[DEFENDANT_ADDRESS_INDEX:])
            })

    print(cases)

    defaults = district_defaults()
    return [insert_hearing(defaults, docket_id, listing) for docket_id, listing in cases.items()]


def scrape(courtroom, date):
    r = requests.get(SITE, params={
        DDID: COURTROOMS[courtroom],
        DATE: date,
        TIME: '10:00',
        LOC: LOCATIONS[courtroom],
        SN: 2,
        SN2: 3
    })
    if 'No GS-Civil docket for' in r.text:  # no longer or not yet published
        return

    return parse(courtroom, r.text)


def scrape_entire_site():
    today = date.today()
    day_delta = timedelta(days=1)
    week = [day_delta * num + today for num in range(7)]
    for day in week:
        date_str = datetime.strftime(day, '%m/%d/%Y')
        print(f'scraping court dates for {date_str}')
        scrape('1A', date_str)
        scrape('1B', date_str)
