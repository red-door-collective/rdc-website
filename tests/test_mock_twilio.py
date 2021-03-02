import unittest
import json
import os

from flask import Flask
from flask_sqlalchemy import SQLAlchemy
from app.models import PhoneNumberVerification

from helpers import db


class TestTwilioResponse(unittest.TestCase):
  def setUp(self):
        db.session.close()
        db.drop_all()
        db.create_all()

  '''
  Testing json response with caller_name but null carrier
  '''
  def test_insert_phone_with_caller_name(self):
    with open('tests/fixtures/phone_number_with_caller_name.json') as twilio_response:
      phone_dict = json.load(twilio_response)
    phone_number = PhoneNumberVerification.from_twilio_response(phone_dict)

    db.session.add(phone_number)
    db.session.commit()
    phone_number_entry = db.session.query(PhoneNumberVerification).first()

    self.assertEqual(phone_dict['caller_name']['caller_name'], phone_number_entry.caller_name)
    self.assertEqual(phone_dict['caller_name']['caller_type'], phone_number_entry.caller_type)
    self.assertEqual(phone_dict['caller_name']['error_code'], phone_number_entry.name_error_code)
    self.assertEqual(phone_dict['carrier'], phone_number_entry.carrier_error_code)
    self.assertEqual(phone_dict['carrier'], phone_number_entry.mobile_country_code)
    self.assertEqual(phone_dict['carrier'], phone_number_entry.mobile_network_code)
    self.assertEqual(phone_dict['carrier'], phone_number_entry.carrier_name)
    self.assertEqual(phone_dict['carrier'], phone_number_entry.phone_type)
    self.assertEqual(phone_dict['country_code'], phone_number_entry.country_code)
    self.assertEqual(phone_dict['national_format'], phone_number_entry.national_format)
    self.assertEqual(phone_dict['phone_number'], phone_number_entry.phone_number)

  '''
  Testing json response with carrier but null caller_name
  '''
  def test_insert_phone_missing_caller_name(self):
    with open('tests/fixtures/phone_number_missing_caller_name.json') as twilio_response:
      phone_dict = json.load(twilio_response)
  
    output_missing_name = PhoneNumberVerification.from_twilio_response(phone_dict)

    db.session.add(output_missing_name)
    db.session.commit()

    phone_number_entry = db.session.query(PhoneNumberVerification).first()

    self.assertEqual(phone_dict['caller_name'], phone_number_entry.caller_name)
    self.assertEqual(phone_dict['caller_name'], phone_number_entry.caller_type)
    self.assertEqual(phone_dict['caller_name'], phone_number_entry.name_error_code)
    self.assertEqual(phone_dict['carrier']['error_code'], phone_number_entry.carrier_error_code)
    self.assertEqual(phone_dict['carrier']['mobile_country_code'], phone_number_entry.mobile_country_code)
    self.assertEqual(phone_dict['carrier']['mobile_network_code'], phone_number_entry.mobile_network_code)
    self.assertEqual(phone_dict['carrier']['name'], phone_number_entry.carrier_name)
    self.assertEqual(phone_dict['carrier']['type'], phone_number_entry.phone_type)
    self.assertEqual(phone_dict['country_code'], phone_number_entry.country_code)
    self.assertEqual(phone_dict['national_format'], phone_number_entry.national_format)
    self.assertEqual(phone_dict['phone_number'], phone_number_entry.phone_number)

    '''
  Testing json response with caller_name but null carrier
  '''
  def test_insert_phone_with_all_data(self):
    with open('tests/fixtures/phone_number_with_all_data.json') as twilio_response:
      phone_dict = json.load(twilio_response)
    phone_number = PhoneNumberVerification.from_twilio_response(phone_dict)

    db.session.add(phone_number)
    db.session.commit()
    phone_number_entry = db.session.query(PhoneNumberVerification).first()

    self.assertEqual(phone_dict['caller_name']['caller_name'], phone_number_entry.caller_name)
    self.assertEqual(phone_dict['caller_name']['caller_type'], phone_number_entry.caller_type)
    self.assertEqual(phone_dict['caller_name']['error_code'], phone_number_entry.name_error_code)
    self.assertEqual(phone_dict['carrier']['error_code'], phone_number_entry.carrier_error_code)
    self.assertEqual(phone_dict['carrier']['mobile_country_code'], phone_number_entry.mobile_country_code)
    self.assertEqual(phone_dict['carrier']['mobile_network_code'], phone_number_entry.mobile_network_code)
    self.assertEqual(phone_dict['carrier']['name'], phone_number_entry.carrier_name)
    self.assertEqual(phone_dict['carrier']['type'], phone_number_entry.phone_type)
    self.assertEqual(phone_dict['country_code'], phone_number_entry.country_code)
    self.assertEqual(phone_dict['national_format'], phone_number_entry.national_format)
    self.assertEqual(phone_dict['phone_number'], phone_number_entry.phone_number)
