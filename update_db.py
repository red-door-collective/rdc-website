import argparse
import gspread
import app.spreadsheets as spreadsheet
from app.models import db

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

NUM_WARRANTS_TO_INSERT = 5 # insert just a bit of data to play with

spreadsheet.imports.detainer_warrants(ws.get_all_values()[1:NUM_WARRANTS_TO_INSERT])
