import unittest
import json
import os

from flask import Flask
from flask_sqlalchemy import SQLAlchemy
from flask_testing import TestCase
from eviction_tracker.detainer_warrants.models import PhoneNumberVerification
from eviction_tracker.database import db
from eviction_tracker.app import create_app
from eviction_tracker.commands import validate_phone_number, twilio_client


class MockTwilioLookup:
    def __init__(self, dictionary):
        for k, v in dictionary.items():
            setattr(self, k, v)

    def from_fixture(file_name):
        with open(file_name) as twilio_response:
            phone_dict = json.load(twilio_response)
        return MockTwilioLookup(phone_dict)


class TestTwilioResponse(TestCase):

    def create_app(self):
        app = create_app(self)
        app.config['TESTING'] = True
        app.config['SQLALCHEMY_DATABASE_URI'] = 'postgresql+psycopg2://eviction_tracker_test:junkdata@localhost:5432/eviction_tracker_test'
        app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
        return app

    def setUp(self):
        db.create_all()

    def tearDown(self):
        db.session.remove()
        db.drop_all()

    def test_insert_phone_with_caller_name(self):
        '''
        Testing json response with caller_name but null carrier
        '''
        twilio_response = MockTwilioLookup.from_fixture(
            'tests/fixtures/phone_number_with_caller_name.json')
        phone_number = PhoneNumberVerification.from_twilio_response(
            twilio_response)

        db.session.add(phone_number)
        db.session.commit()
        phone_number_entry = db.session.query(PhoneNumberVerification).first()

        self.assertEqual(
            twilio_response.caller_name['caller_name'], phone_number_entry.caller_name)
        self.assertEqual(
            twilio_response.caller_name['caller_type'], phone_number_entry.caller_type)
        self.assertEqual(
            twilio_response.caller_name['error_code'], phone_number_entry.name_error_code)
        self.assertEqual(twilio_response.carrier,
                         phone_number_entry.carrier_error_code)
        self.assertEqual(twilio_response.carrier,
                         phone_number_entry.mobile_country_code)
        self.assertEqual(twilio_response.carrier,
                         phone_number_entry.mobile_network_code)
        self.assertEqual(twilio_response.carrier,
                         phone_number_entry.carrier_name)
        self.assertEqual(twilio_response.carrier,
                         phone_number_entry.phone_type)
        self.assertEqual(twilio_response.country_code,
                         phone_number_entry.country_code)
        self.assertEqual(twilio_response.national_format,
                         phone_number_entry.national_format)
        self.assertEqual(twilio_response.phone_number,
                         phone_number_entry.phone_number)

    def test_insert_phone_missing_caller_name(self):
        '''
        Testing json response with carrier but null caller_name
        '''
        twilio_response = MockTwilioLookup.from_fixture(
            'tests/fixtures/phone_number_missing_caller_name.json')
        phone_number = PhoneNumberVerification.from_twilio_response(
            twilio_response)

        output_missing_name = PhoneNumberVerification.from_twilio_response(
            twilio_response)

        db.session.add(output_missing_name)
        db.session.commit()

        phone_number_entry = db.session.query(PhoneNumberVerification).first()

        self.assertEqual(twilio_response.caller_name,
                         phone_number_entry.caller_name)
        self.assertEqual(twilio_response.caller_name,
                         phone_number_entry.caller_type)
        self.assertEqual(twilio_response.caller_name,
                         phone_number_entry.name_error_code)
        self.assertEqual(
            twilio_response.carrier['error_code'], phone_number_entry.carrier_error_code)
        self.assertEqual(
            twilio_response.carrier['mobile_country_code'], phone_number_entry.mobile_country_code)
        self.assertEqual(
            twilio_response.carrier['mobile_network_code'], phone_number_entry.mobile_network_code)
        self.assertEqual(twilio_response.carrier['name'],
                         phone_number_entry.carrier_name)
        self.assertEqual(twilio_response.carrier['type'],
                         phone_number_entry.phone_type)
        self.assertEqual(twilio_response.country_code,
                         phone_number_entry.country_code)
        self.assertEqual(twilio_response.national_format,
                         phone_number_entry.national_format)
        self.assertEqual(twilio_response.phone_number,
                         phone_number_entry.phone_number)

    def test_insert_phone_with_all_data(self):
        '''
        Testing json response with caller_name but null carrier
        '''
        twilio_response = MockTwilioLookup.from_fixture(
            'tests/fixtures/phone_number_with_all_data.json')
        phone_number = PhoneNumberVerification.from_twilio_response(
            twilio_response)

        db.session.add(phone_number)
        db.session.commit()
        phone_number_entry = db.session.query(PhoneNumberVerification).first()

        self.assertEqual(
            twilio_response.caller_name['caller_name'], phone_number_entry.caller_name)
        self.assertEqual(
            twilio_response.caller_name['caller_type'], phone_number_entry.caller_type)
        self.assertEqual(
            twilio_response.caller_name['error_code'], phone_number_entry.name_error_code)
        self.assertEqual(
            twilio_response.carrier['error_code'], phone_number_entry.carrier_error_code)
        self.assertEqual(
            twilio_response.carrier['mobile_country_code'], phone_number_entry.mobile_country_code)
        self.assertEqual(
            twilio_response.carrier['mobile_network_code'], phone_number_entry.mobile_network_code)
        self.assertEqual(twilio_response.carrier['name'],
                         phone_number_entry.carrier_name)
        self.assertEqual(twilio_response.carrier['type'],
                         phone_number_entry.phone_type)
        self.assertEqual(twilio_response.country_code,
                         phone_number_entry.country_code)
        self.assertEqual(twilio_response.national_format,
                         phone_number_entry.national_format)
        self.assertEqual(twilio_response.phone_number,
                         phone_number_entry.phone_number)
