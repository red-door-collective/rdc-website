import unittest
import json

from flask import Flask
from flask_sqlalchemy import SQLAlchemy
from app.models import db, PhoneNumberVerification

db.create_all()

input = json.loads('''{
  "caller_name": {
    "caller_name": "Delicious Cheese Cake",
    "caller_type": "CONSUMER",
    "error_code": null
  },
  "carrier": null,
  "country_code": "US",
  "national_format": "(510) 867-5310",
  "phone_number": "+15108675310",
  "add_ons": null,
  "url": "https://lookups.twilio.com/v1/PhoneNumbers/+15108675310"
}''')
  
output = PhoneNumberVerification.from_twilio_response(input)

class TestTwilioResponse(unittest.TestCase):
  def test_equality(self):
    self.assertEqual(input['caller_name']['caller_name'], output.caller_name)
    self.assertEqual(input['caller_name']['caller_type'], output.caller_type)
    self.assertEqual(input['caller_name']['error_code'], output.error_code)
    self.assertEqual(input['carrier'], output.carrier)
    self.assertEqual(input['country_code'], output.country_code)
    self.assertEqual(input['national_format'], output.national_format)
    self.assertEqual(input['phone_number'], output.phone_number)