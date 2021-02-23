import argparse
import gspread
from app.models import db
from app.models import Attorney, Courtroom, Defendant, DetainerWarrant, District, Judge, Plantiff
from app.spreadsheets.util import get_or_create

parser = argparse.ArgumentParser()
parser.add_argument("sheet_name")
parser.add_argument("--service_account_key", help="Google Service Account filepath")
args = parser.parse_args()

connect_kwargs = dict()
if args.service_account_key:
   connect_kwargs['filename'] = args.service_account_key

gc = gspread.service_account(**connect_kwargs)

sh = gc.open(args.sheet_name)

ws = sh.worksheet("All Detainer Warrants")

def init_status(warrant):
    statuses = {
        'CLOSED': 0,
        'PENDING': 1
    }
    return statuses[warrant[3].upper()]

def init_amount_claimed_category(warrant):
    categories = {
        'POSS': 0,
        'FEES': 1,
        'BOTH': 2,
        'N/A': 3,
        '': 4
    }
    return categories[warrant[12].upper()]

district, _ = get_or_create(db.session, District, name="Davidson County")

db.session.add(district)
db.session.commit()

defaults = {'district': district}

def detainer_warrant(warrant):
    docket_id = warrant[0]
    file_date = warrant[2]
    status = init_status(warrant)
    attorney, _ = get_or_create(db.session, Attorney, name=warrant[7], defaults=defaults)
    plantiff, _ = get_or_create(db.session, Plantiff, name=warrant[6], attorney=attorney, defaults=defaults)
    court_date = warrant[8]
    courtroom, _ = get_or_create(db.session, Courtroom, name=warrant[9], defaults=defaults)
    presiding_judge, _ = get_or_create(db.session, Judge, name=warrant[10], defaults=defaults)
    amount_claimed = warrant[11]
    amount_claimed_category = init_amount_claimed_category(warrant)
    defendant, _ = get_or_create(db.session, Defendant, address=warrant[15], name=warrant[14], phone=warrant[16], defaults=defaults)

    return DetainerWarrant(
        docket_id=docket_id,
        file_date=file_date,
        status=status,
        plantiff=plantiff,
        court_date=court_date,
        courtroom=courtroom,
        presiding_judge=presiding_judge,
        amount_claimed=amount_claimed,
        amount_claimed_category=amount_claimed_category,
        defendants=[defendant]
        )

NUM_WARRANTS_TO_INSERT = 5 # insert just a bit of data to play with

for warrant in ws.get_all_values()[1:NUM_WARRANTS_TO_INSERT]:
    db.session.add(detainer_warrant(warrant))

db.session.commit()
