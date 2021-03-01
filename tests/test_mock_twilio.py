import unittest

from flask import Flask
from flask_sqlalchemy import SQLAlchemy
from app.models import db, PhoneNumberVerification
import app.spreadsheets as spreadsheet

from app import app
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:////tmp/test.db'
db.drop_all()
db.create_all()

input = {
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
}

class PhoneNumberVerification(db.Model):
    __tablename__ = 'phone_number_verifications'
    id = Column(Integer, foreign_key=True)
    caller_name = Column(String)
    caller_type = Column(Integer)
    error_code = Column(Integer)
    carrier = Column(String)
    country_code = Column(String)
    national_format = Column(String)
    phone_number = Column(String)
    def from_twilio_response(input):
      return PhoneNumberVerification(
        caller_name = input.caller_name.caller_name
        caller_type = input.caller_name.caller_type
        error_code = input.caller_name.error_code
        carrier = input.carrier
        country_code = input.country_code
        national_format = input.national_format
        phone_number = input.phone_number
      )
  
output = PhoneNumberVerification.from_twilio_response(input)

class TestInputToOutput(unittest.TestCase):
  def test_json_conversion(self)
    self.assertEqual(input.caller_name.caller_name, output.caller_name)
    self.assertEqual(input.caller_name.caller_type, output.caller_type)
    self.assertEqual(input.caller_name.caller_name, output.caller_name)
    self.assertEqual(input.caller_name.error_code, output.error_code)
    self.assertEqual(input.carrier, output.carrier)
    self.assertEqual(input.country_code, output.country_code)
    self.assertEqual(input.national_format, output.national_format)
    self.assertEqual(input.phone_number, output.phone_number)

class TestTwilioResponseSave(unittest.TestCase): 
    spreadsheet.imports.phone_number_verifications(output)
    saved_verification = db.session.query(PhoneNumberVerification).first
    def test_twilio_save(self)
      self.assertEqual(input.caller_name.caller_name, saved_verification.caller_name)
      self.assertEqual(input.caller_name.caller_type, saved_verification.caller_type)
      self.assertEqual(input.caller_name.caller_name, saved_verification.caller_name)
      self.assertEqual(input.caller_name.error_code, saved_verification.error_code)
      self.assertEqual(input.carrier, saved_verification.carrier)
      self.assertEqual(input.country_code, saved_verification.country_code)
      self.assertEqual(input.national_format, saved_verification.national_format)
      self.assertEqual(input.phone_number, saved_verification.phone_number)

if __name__ == '__main__':
    unittest.main()
