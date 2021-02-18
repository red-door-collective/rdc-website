import argparse
import gspread

parser = argparse.ArgumentParser()
parser.add_argument("sheet_name")
parser.add_argument("--service_account_key", help="Google Service Account filepath")
args = parser.parse_args()
print(args)

connect_kwargs = dict()
if args.service_account_key:
   connect_kwargs['filename'] = args.service_account_key

gc = gspread.service_account(**connect_kwargs)

sh = gc.open(args.sheet_name)

print(sh.worksheet("All Detainer Warrants").get('A1'))
