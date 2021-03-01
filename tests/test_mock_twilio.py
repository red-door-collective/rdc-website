import unittest
import json
import os

from flask import Flask
from flask_sqlalchemy import SQLAlchemy
from app.models import db, PhoneNumberVerification

db.create_all()

#Testing json response with caller_name but null carrier

with open('tests/fixtures/phone_number_with_caller_name.json') as twilio_response:
  input_with_name = json.load(twilio_response)
  
output_with_name = PhoneNumberVerification.from_twilio_response(input_with_name)

db.session.add(output_with_name)
db.session.commit()

phone_number_entry = db.session.query(PhoneNumberVerification).first()

class TestTwilioResponse(unittest.TestCase):
  def test_equality(self):
    self.assertEqual(input_with_name['caller_name']['caller_name'], phone_number_entry.caller_name)
    self.assertEqual(input_with_name['caller_name']['caller_type'], phone_number_entry.caller_type)
    self.assertEqual(input_with_name['caller_name']['error_code'], phone_number_entry.name_error_code)
    self.assertEqual(input_with_name['carrier'], phone_number_entry.carrier_error_code)
    self.assertEqual(input_with_name['carrier'], phone_number_entry.mobile_country_code)
    self.assertEqual(input_with_name['carrier'], phone_number_entry.mobile_wireless_code)
    self.assertEqual(input_with_name['carrier'], phone_number_entry.carrier_name)
    self.assertEqual(input_with_name['carrier'], phone_number_entry.phone_type)
    self.assertEqual(input_with_name['country_code'], phone_number_entry.country_code)
    self.assertEqual(input_with_name['national_format'], phone_number_entry.national_format)
    self.assertEqual(input_with_name['phone_number'], phone_number_entry.phone_number)

#Testing json response with carrier but null caller_name

with open('tests/fixtures/phone_number_missing_caller_name.json') as twilio_response:
  input_missing_name = json.load(twilio_response)
  
output_missing_name = PhoneNumberVerification.from_twilio_response(input_missing_name)

db.session.add(output_missing_name)
db.session.commit()

phone_number_entry_noname = db.session.query(PhoneNumberVerification).first()

class TestTwilioResponse(unittest.TestCase):
  def test_equality(self):
    self.assertEqual(input_missing_name['caller_name'], phone_number_entry_noname.caller_name)
    self.assertEqual(input_missing_name['caller_name'], phone_number_entry_noname.caller_type)
    self.assertEqual(input_missing_name['caller_name'], phone_number_entry_noname.name_error_code)
    self.assertEqual(input_missing_name['carrier']['error_code'], phone_number_entry_noname.carrier_error_code)
    self.assertEqual(input_missing_name['carrier']['mobile_country_code'], phone_number_entry_noname.mobile_country_code)
    self.assertEqual(input_missing_name['carrier']['mobile_wireless_code'], phone_number_entry_noname.mobile_wireless_code)
    self.assertEqual(input_missing_name['carrier']['name'], phone_number_entry_noname.carrier_name)
    self.assertEqual(input_missing_name['carrier']['type'], phone_number_entry_noname.phone_type)
    self.assertEqual(input_missing_name['country_code'], phone_number_entry_noname.country_code)
    self.assertEqual(input_missing_name['national_format'], phone_number_entry_noname.national_format)
    self.assertEqual(input_missing_name['phone_number'], phone_number_entry_noname.phone_number)