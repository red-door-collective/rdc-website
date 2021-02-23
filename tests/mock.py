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
    caller_type = Column(Integer) # smaller column than String
    error_code = Column(Integer)
    carrier = Column(String)
    country_code = Column(String)
    national_format = Column(String)
    phone_number = Column(String)
    def from_twilio_response(json):
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