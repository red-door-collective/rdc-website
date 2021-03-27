from eviction_tracker.database import db, Column, Model, relationship
from datetime import datetime
from sqlalchemy import func
from flask_security import UserMixin, RoleMixin


class Timestamped():
    created_at = Column(db.DateTime, nullable=False, server_default=func.now())
    updated_at = Column(
        db.DateTime, nullable=False, server_default=func.now(), onupdate=func.now())


class District(db.Model, Timestamped):
    __tablename__ = 'districts'
    id = Column(db.Integer, primary_key=True)
    name = Column(db.String(255), nullable=False)

    attorneys = relationship('Attorney', back_populates='district')
    plantiffs = relationship('Plantiff', back_populates='district')
    defendants = relationship('Defendant', back_populates='district')
    judges = relationship('Judge', back_populates='district')
    courtrooms = relationship('Courtroom', back_populates='district')

    def __repr__(self):
        return "<District(name='%s')>" % (self.name)


detainer_warrant_defendants = db.Table(
    'detainer_warrant_defendants',
    db.metadata,
    Column('detainer_warrant_docket_id', db.ForeignKey(
        'detainer_warrants.docket_id'), primary_key=True),
    Column('defendant_id', db.ForeignKey('defendants.id'), primary_key=True)
)

defendant_phone_verifications = db.Table(
    'defendant_phone_verifications',
    db.metadata,
    Column('defendant_id', db.ForeignKey('defendants.id'), primary_key=True),
    Column('phone_number_verification_id', db.ForeignKey(
        'phone_number_verifications.id'), primary_key=True)
)


class Defendant(db.Model, Timestamped):
    __tablename__ = 'defendants'
    id = Column(db.Integer, primary_key=True)
    name = Column(db.String(255))
    potential_phones = Column(db.String(255))
    address = Column(db.String(255))

    district_id = Column(db.Integer, db.ForeignKey(
        'districts.id'), nullable=False)

    db.UniqueConstraint('name', 'district_id')

    district = relationship('District', back_populates='defendants')
    detainer_warrants = relationship('DetainerWarrant',
                                     secondary=detainer_warrant_defendants,
                                     back_populates='defendants'
                                     )
    phone_number_verifications = relationship('PhoneNumberVerification',
                                              secondary=defendant_phone_verifications,
                                              back_populates='defendants')

    def __repr__(self):
        return f"<Defendant(name='{name}', , address='%s')>" % (self.name, self.phone, self.address)


class Attorney(db.Model, Timestamped):
    __tablename__ = 'attorneys'
    id = Column(db.Integer, primary_key=True)
    name = Column(db.String(255), nullable=False)
    district_id = Column(db.Integer, db.ForeignKey(
        'districts.id'), nullable=False)

    db.UniqueConstraint('name', 'district_id')

    district = relationship('District', back_populates='attorneys')
    plantiff_clients = relationship('Plantiff', back_populates='attorney')

    def __repr__(self):
        return "<Attorney(name='%s', district_id='%s')>" % (self.name, self.district_id)


class Courtroom(db.Model, Timestamped):
    __tablename__ = 'courtrooms'
    id = Column(db.Integer, primary_key=True)
    name = Column(db.String(255), nullable=False)
    district_id = Column(db.Integer, db.ForeignKey(
        'districts.id'), nullable=False)

    db.UniqueConstraint('name', 'district_id')

    district = relationship('District', back_populates='courtrooms')
    cases = relationship('DetainerWarrant', back_populates='courtroom')

    def __repr__(self):
        return "<Courtroom(name='%s')>" % (self.name)


class Plantiff(db.Model, Timestamped):
    __tablename__ = 'plantiffs'
    id = Column(db.Integer, primary_key=True)
    name = Column(db.String(255), nullable=False)
    attorney_id = Column(db.Integer, db.ForeignKey('attorneys.id'))
    district_id = Column(db.Integer, db.ForeignKey(
        'districts.id'), nullable=False)

    db.UniqueConstraint('name', 'district_id')

    district = relationship('District', back_populates='plantiffs')
    attorney = relationship('Attorney', back_populates='plantiff_clients')
    detainer_warrants = relationship(
        'DetainerWarrant', back_populates='plantiff')

    def __repr__(self):
        return "<Plantiff(name='%s', attorney_id='%s', district_id='%s')>" % (self.name, self.attorney_id, self.district_id)


class Judge(db.Model, Timestamped):
    __tablename__ = "judges"
    id = Column(db.Integer, primary_key=True)
    name = Column(db.String(255), nullable=False)
    district_id = Column(db.Integer, db.ForeignKey(
        'districts.id'), nullable=False)

    db.UniqueConstraint('name', 'district_id')

    district = relationship('District', back_populates='judges')
    cases = relationship('DetainerWarrant', back_populates='presiding_judge')

    def __repr__(self):
        return "<Judge(name='%s')>" % (self.name)


class DetainerWarrant(db.Model, Timestamped):
    statuses = {
        'CLOSED': 0,
        'PENDING': 1
    }

    amount_claimed_categories = {
        'POSS': 0,
        'FEES': 1,
        'BOTH': 2,
        'N/A': 3,
    }

    judgements = {
        'NON-SUIT': 0,
        'POSS': 1,
        'POSS + PAYMENT': 2,
        'DISMISSED': 3,
        'N/A': 4
    }

    __tablename__ = 'detainer_warrants'
    docket_id = Column(db.String(255), primary_key=True)
    file_date = Column(db.Date, nullable=False)
    status_id = Column(db.Integer, nullable=False)  # union?
    plantiff_id = Column(db.Integer, db.ForeignKey('plantiffs.id'))
    court_date = Column(db.Date)  # date
    court_date_notes = Column(db.String(50))
    courtroom_id = Column(db.Integer, db.ForeignKey('courtrooms.id'))
    presiding_judge_id = Column(db.Integer, db.ForeignKey('judges.id'))
    amount_claimed = Column(db.Numeric(scale=2))  # USD
    amount_claimed_category_id = Column(
        db.Integer, nullable=False)  # enum (POSS | FEES | BOTH | NA)
    is_cares = Column(db.Boolean)
    is_legacy = Column(db.Boolean)
    zip_code = Column(db.String(10))
    judgement_id = Column(db.Integer, nullable=False, default=4)
    judgement_notes = Column(db.String(255))
    notes = Column(db.String(255))

    plantiff = relationship('Plantiff', back_populates='detainer_warrants')
    courtroom = relationship('Courtroom', back_populates='cases')
    presiding_judge = relationship('Judge', back_populates='cases')

    defendants = relationship('Defendant',
                              secondary=detainer_warrant_defendants,
                              back_populates='detainer_warrants'
                              )

    def __repr__(self):
        return "<DetainerWarrant(docket_id='%s', file_date='%s')>" % (self.docket_id, self.file_date)

    @property
    def status(self):
        status_by_id = {v: k for k, v in DetainerWarrant.statuses.items()}
        return status_by_id[self.status_id]

    @status.setter
    def status(self, status_name):
        self.status_id = DetainerWarrant.statuses[status_name]

    @property
    def amount_claimed_category(self):
        category_by_id = {
            v: k for k, v in DetainerWarrant.amount_claimed_categories.items()}
        return category_by_id[self.amount_claimed_category_id]

    @amount_claimed_category.setter
    def amount_claimed_category(self, amount_claimed_category_name):
        self.amount_claimed_category_id = DetainerWarrant.amount_claimed_categories[
            amount_claimed_category_name]

    @property
    def judgement(self):
        judgement_by_id = {v: k for k, v in DetainerWarrant.judgements.items()}
        return judgement_by_id[self.judgement_id]

    @judgement.setter
    def judgement(self, judgement_name):
        self.judgement_id = DetainerWarrant.judgements[judgement_name]


class PhoneNumberVerification(db.Model, Timestamped):
    caller_types = {
        'CONSUMER': 1,
        'BUSINESS': 2,
    }

    __tablename__ = 'phone_number_verifications'
    id = Column(db.Integer, primary_key=True)
    caller_name = Column(db.String(255))
    caller_type_id = Column(db.Integer)  # smaller column than String
    name_error_code = Column(db.Integer)
    carrier_error_code = Column(db.Integer)
    mobile_country_code = Column(db.String(10))
    mobile_network_code = Column(db.String(10))
    carrier_name = Column(db.String(255))
    phone_type = Column(db.String(10))
    country_code = Column(db.String(10))
    national_format = Column(db.String(30))
    phone_number = Column(db.String(30), unique=True)

    defendants = relationship('Defendant', secondary=defendant_phone_verifications,
                              back_populates='phone_number_verifications')

    def from_twilio_response(lookup):
        caller_info = lookup.caller_name or {
            'caller_name': None, 'caller_type': None, 'error_code': None}
        carrier_info = lookup.carrier or {
            'error_code': None, 'mobile_country_code': None, 'mobile_network_code': None, 'name': None, 'type': None}
        return PhoneNumberVerification(
            caller_name=caller_info['caller_name'],
            caller_type=caller_info['caller_type'],
            name_error_code=caller_info['error_code'],
            carrier_error_code=carrier_info['error_code'],
            mobile_country_code=carrier_info['mobile_country_code'],
            mobile_network_code=carrier_info['mobile_network_code'],
            carrier_name=carrier_info['name'],
            phone_type=carrier_info['type'],
            country_code=lookup.country_code,
            national_format=lookup.national_format,
            phone_number=lookup.phone_number)

    @property
    def caller_type(self):
        caller_type_by_id = {v: k for k,
                             v in PhoneNumberVerification.caller_types.items()}
        return caller_type_by_id.get(self.caller_type_id)

    @caller_type.setter
    def caller_type(self, caller_type):
        self.caller_type_id = PhoneNumberVerification.caller_types.get(
            caller_type)

    def __repr__(self):
        return "<PhoneNumberVerification(caller_name='%s', phone_type='%s', phone_number='%s')>" % (self.caller_name, self.phone_type, self.phone_number)
