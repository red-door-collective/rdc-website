import unittest
import json
import os

from flask import Flask
from flask_sqlalchemy import SQLAlchemy
from flask_testing import TestCase
from eviction_tracker.detainer_warrants.models import PhoneNumberVerification
from eviction_tracker.database import db
from eviction_tracker.app import create_app


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
        with open('tests/fixtures/phone_number_with_caller_name.json') as twilio_response:
            phone_dict = json.load(twilio_response)
        phone_number = PhoneNumberVerification.from_twilio_response(phone_dict)

        db.session.add(phone_number)
        db.session.commit()
        phone_number_entry = db.session.query(PhoneNumberVerification).first()

        self.assertEqual(
            phone_dict['caller_name']['caller_name'], phone_number_entry.caller_name)
        self.assertEqual(
            phone_dict['caller_name']['caller_type'], phone_number_entry.caller_type)
        self.assertEqual(
            phone_dict['caller_name']['error_code'], phone_number_entry.name_error_code)
        self.assertEqual(phone_dict['carrier'],
                         phone_number_entry.carrier_error_code)
        self.assertEqual(phone_dict['carrier'],
                         phone_number_entry.mobile_country_code)
        self.assertEqual(phone_dict['carrier'],
                         phone_number_entry.mobile_network_code)
        self.assertEqual(phone_dict['carrier'],
                         phone_number_entry.carrier_name)
        self.assertEqual(phone_dict['carrier'], phone_number_entry.phone_type)
        self.assertEqual(phone_dict['country_code'],
                         phone_number_entry.country_code)
        self.assertEqual(phone_dict['national_format'],
                         phone_number_entry.national_format)
        self.assertEqual(phone_dict['phone_number'],
                         phone_number_entry.phone_number)

    def test_insert_phone_missing_caller_name(self):
        '''
        Testing json response with carrier but null caller_name
        '''
        with open('tests/fixtures/phone_number_missing_caller_name.json') as twilio_response:
            phone_dict = json.load(twilio_response)

            output_missing_name = PhoneNumberVerification.from_twilio_response(
                phone_dict)

        db.session.add(output_missing_name)
        db.session.commit()

        phone_number_entry = db.session.query(PhoneNumberVerification).first()

        self.assertEqual(phone_dict['caller_name'],
                         phone_number_entry.caller_name)
        self.assertEqual(phone_dict['caller_name'],
                         phone_number_entry.caller_type)
        self.assertEqual(phone_dict['caller_name'],
                         phone_number_entry.name_error_code)
        self.assertEqual(
            phone_dict['carrier']['error_code'], phone_number_entry.carrier_error_code)
        self.assertEqual(
            phone_dict['carrier']['mobile_country_code'], phone_number_entry.mobile_country_code)
        self.assertEqual(
            phone_dict['carrier']['mobile_network_code'], phone_number_entry.mobile_network_code)
        self.assertEqual(phone_dict['carrier']['name'],
                         phone_number_entry.carrier_name)
        self.assertEqual(phone_dict['carrier']['type'],
                         phone_number_entry.phone_type)
        self.assertEqual(phone_dict['country_code'],
                         phone_number_entry.country_code)
        self.assertEqual(phone_dict['national_format'],
                         phone_number_entry.national_format)
        self.assertEqual(phone_dict['phone_number'],
                         phone_number_entry.phone_number)

    def test_insert_phone_with_all_data(self):
        '''
        Testing json response with caller_name but null carrier
        '''
        with open('tests/fixtures/phone_number_with_all_data.json') as twilio_response:
            phone_dict = json.load(twilio_response)
        phone_number = PhoneNumberVerification.from_twilio_response(phone_dict)

        db.session.add(phone_number)
        db.session.commit()
        phone_number_entry = db.session.query(PhoneNumberVerification).first()

        self.assertEqual(
            phone_dict['caller_name']['caller_name'], phone_number_entry.caller_name)
        self.assertEqual(
            phone_dict['caller_name']['caller_type'], phone_number_entry.caller_type)
        self.assertEqual(
            phone_dict['caller_name']['error_code'], phone_number_entry.name_error_code)
        self.assertEqual(
            phone_dict['carrier']['error_code'], phone_number_entry.carrier_error_code)
        self.assertEqual(
            phone_dict['carrier']['mobile_country_code'], phone_number_entry.mobile_country_code)
        self.assertEqual(
            phone_dict['carrier']['mobile_network_code'], phone_number_entry.mobile_network_code)
        self.assertEqual(phone_dict['carrier']['name'],
                         phone_number_entry.carrier_name)
        self.assertEqual(phone_dict['carrier']['type'],
                         phone_number_entry.phone_type)
        self.assertEqual(phone_dict['country_code'],
                         phone_number_entry.country_code)
        self.assertEqual(phone_dict['national_format'],
                         phone_number_entry.national_format)
        self.assertEqual(phone_dict['phone_number'],
                         phone_number_entry.phone_number)
