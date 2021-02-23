from . import db
from sqlalchemy import Column, Integer, String, ForeignKey, Table, Text, UniqueConstraint
from sqlalchemy.orm import relationship

class District(db.Model):
    __tablename__ = 'districts'
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(String(255), nullable=False)

    attorneys = relationship('Attorney', back_populates='district')
    plantiffs = relationship('Plantiff', back_populates='district')
    defendants = relationship('Defendant', back_populates='district')
    judges = relationship('Judge', back_populates='district')
    courtrooms = relationship('Courtroom', back_populates='district')

    def __repr__(self):
        return "<District(name='%s')>" % (self.name)


detainer_warrant_defendants = Table(
    'detainer_warrant_defendants',
    db.metadata,
    db.Column('detainer_warrant_docket_id', ForeignKey('detainer_warrants.docket_id'), primary_key=True),
    db.Column('defendant_id', ForeignKey('defendants.id'), primary_key=True)
)

class Defendant(db.Model):
    __tablename__ = 'defendants'
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(String(255), nullable=False)
    phone = db.Column(String)
    address = db.Column(String(255), nullable=False)

    district_id = db.Column(db.Integer, ForeignKey('districts.id'), nullable=False)

    UniqueConstraint('name', 'district_id')

    district = relationship('District', back_populates='defendants')
    detainer_warrants = relationship('DetainerWarrant',
                                     secondary=detainer_warrant_defendants,
                                     back_populates='defendants'
                                    )

    def __repr__(self):
        return "<Defendant(name='%s', phone='%s', address='%s')>" % (self.name, self.phone, self.address)

class Attorney(db.Model):
    __tablename__ = 'attorneys'
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(String(255), nullable=False)
    district_id = db.Column(db.Integer, ForeignKey('districts.id'), nullable=False)

    UniqueConstraint('name', 'district_id')

    district = relationship('District', back_populates='attorneys')
    plantiff_clients = relationship('Plantiff', back_populates='attorney')

    def __repr__(self):
        return "<Attorney(name='%s', district_id='%s')>" % (self.name, self.district_id)

class Courtroom(db.Model):
    __tablename__ = 'courtrooms'
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(String(255), nullable=False)
    district_id = db.Column(db.Integer, ForeignKey('districts.id'), nullable=False)

    UniqueConstraint('name', 'district_id')

    district = relationship('District', back_populates='courtrooms')
    cases = relationship('DetainerWarrant', back_populates='courtroom')

    def __repr__(self):
        return "<Courtroom(name='%s')>" % (self.name)

class Plantiff(db.Model):
    __tablename__ = 'plantiffs'
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(String(255), nullable=False)
    attorney_id = db.Column(db.Integer, ForeignKey('attorneys.id'))
    district_id = db.Column(db.Integer, ForeignKey('districts.id'), nullable=False)

    UniqueConstraint('name', 'district_id')

    district = relationship('District', back_populates='plantiffs')
    attorney = relationship('Attorney', back_populates='plantiff_clients')
    detainer_warrants = relationship('DetainerWarrant', back_populates='plantiff')

    def __repr__(self):
        return "<Plantiff(name='%s', attorney_id='%s', district_id='%s')>" % (self.name, self.attorney_id, self.district_id)

class Judge(db.Model):
    __tablename__ = "judges"
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(String(255), nullable=False)
    district_id = db.Column(db.Integer, ForeignKey('districts.id'), nullable=False)

    UniqueConstraint('name', 'district_id')

    district = relationship('District', back_populates='judges')
    cases = relationship('DetainerWarrant', back_populates='presiding_judge')

    def __repr__(self):
        return "<Judge(name='%s')>" % (self.name)

class DetainerWarrant(db.Model):
    __tablename__ = 'detainer_warrants'
    docket_id = db.Column(String(255), primary_key=True)
    file_date = db.Column(String(255), nullable=False)
    status = db.Column(db.Integer, nullable=False) # union?
    plantiff_id = db.Column(db.Integer, ForeignKey('plantiffs.id'))
    court_date = db.Column(String(255), nullable=False) # date
    courtroom_id = db.Column(db.Integer, ForeignKey('courtrooms.id'), nullable=False)
    presiding_judge_id = db.Column(db.Integer, ForeignKey('judges.id'))
    amount_claimed = db.Column(String) # USD
    amount_claimed_category = db.Column(db.Integer, nullable=False) # enum (POSS | FEES | BOTH | NA)
    judgement = db.Column(Integer)
    judgement_notes = db.Column(String)

    plantiff = relationship('Plantiff', back_populates='detainer_warrants')
    courtroom = relationship('Courtroom', back_populates='cases')
    presiding_judge = relationship('Judge', back_populates='cases')

    defendants = relationship('Defendant',
                              secondary=detainer_warrant_defendants,
                              back_populates='detainer_warrants'
                             )
    def __repr__(self):
        return "<DetainerWarrant(docket_id='%s', file_date='%s')>" % (self.docket_id, self.file_date)

class PhoneNumberVerification(db.Model):
    __tablename__ = 'phone_number_verifications'
    id = db.Column(db.Integer, primary_key=True)
    caller_name = db.Column(db.String(255))
    caller_type = db.Column(db.Integer) # smaller column than String
    error_code = db.Column(db.Integer)
    carrier = db.Column(db.String(255))
    country_code = db.Column(db.String(10))
    national_format = db.Column(db.String(20))
    phone_number = db.Column(db.String(30))

    def __repr__(self):
        return "<PhoneNumberVerification(caller_name='%s', caller_type='%s', phone_number='%s')>" % (self.caller_name, self.caller_type, self.phone_number)
