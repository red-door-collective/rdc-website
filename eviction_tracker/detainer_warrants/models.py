from eviction_tracker.database import db, Timestamped, Column, Model, relationship
from datetime import datetime
from sqlalchemy import func, text
from flask_security import UserMixin, RoleMixin
from eviction_tracker.direct_action.models import phone_bank_tenants, canvass_warrants


class District(db.Model, Timestamped):
    __tablename__ = 'districts'
    id = Column(db.Integer, primary_key=True)
    name = Column(db.String(255), nullable=False)

    db.UniqueConstraint('name')

    attorneys = relationship('Attorney', back_populates='district')
    plaintiffs = relationship('Plaintiff', back_populates='district')
    defendants = relationship('Defendant', back_populates='district')
    judges = relationship('Judge', back_populates='district')
    courtrooms = relationship('Courtroom', back_populates='district')

    def __repr__(self):
        return "<District(name='%s')>" % (self.name)


detainer_warrant_defendants = db.Table(
    'detainer_warrant_defendants',
    db.metadata,
    Column('detainer_warrant_docket_id', db.ForeignKey(
        'detainer_warrants.docket_id', ondelete="CASCADE"), primary_key=True),
    Column('defendant_id', db.ForeignKey(
        'defendants.id', ondelete="CASCADE"), primary_key=True)
)


class Defendant(db.Model, Timestamped):
    __tablename__ = 'defendants'
    id = Column(db.Integer, primary_key=True)
    first_name = Column(db.String(255))
    middle_name = Column(db.String(50))
    last_name = Column(db.String(50))
    suffix = Column(db.String(20))
    potential_phones = Column(db.String(255))
    address = Column(db.String(255))

    district_id = Column(db.Integer, db.ForeignKey(
        'districts.id'), nullable=False)
    verified_phone_id = Column(db.Integer, db.ForeignKey(
        'phone_number_verifications.id'))

    db.UniqueConstraint('first_name', 'middle_name',
                        'last_name', 'suffix', 'address', 'district_id', 'potential_phones')

    district = relationship('District', back_populates='defendants')
    detainer_warrants = relationship('DetainerWarrant',
                                     secondary=detainer_warrant_defendants,
                                     back_populates='_defendants',
                                     passive_deletes=True
                                     )
    verified_phone = relationship(
        'PhoneNumberVerification', back_populates='defendants')
    phone_bank_attempts = relationship(
        'PhoneBankEvent', secondary=phone_bank_tenants, back_populates='tenants')

    @property
    def name(self):
        return ' '.join([name for name in [self.first_name, self.middle_name, self.last_name, self.suffix] if name])

    def __repr__(self):
        return f"<Defendant(name='{self.name}', phones='{self.potential_phones}', address='{self.address}')>"


class Attorney(db.Model, Timestamped):
    __tablename__ = 'attorneys'
    id = Column(db.Integer, primary_key=True)
    name = Column(db.String(255), nullable=False)
    district_id = Column(db.Integer, db.ForeignKey(
        'districts.id'), nullable=False)

    db.UniqueConstraint('name', 'district_id')

    district = relationship('District', back_populates='attorneys')
    detainer_warrants = relationship(
        'DetainerWarrant', back_populates='_plaintiff_attorney')
    # _prosecutions = relationship(
    #     'Judgement', back_populates='_plaintiff_attorney'
    # )
    # _defenses = relationship(
    #     'Judgement', back_populates='_defendant_attorney'
    # )

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
    cases = relationship('DetainerWarrant', back_populates='_courtroom')
    _judgements = relationship('Judgement', back_populates='_courtroom')

    def __repr__(self):
        return "<Courtroom(name='%s')>" % (self.name)


class Plaintiff(db.Model, Timestamped):
    __tablename__ = 'plaintiffs'
    id = Column(db.Integer, primary_key=True)
    name = Column(db.String(255), nullable=False)
    district_id = Column(db.Integer, db.ForeignKey(
        'districts.id'), nullable=False)

    db.UniqueConstraint('name', 'district_id')

    district = relationship('District', back_populates='plaintiffs')
    detainer_warrants = relationship(
        'DetainerWarrant', back_populates='_plaintiff')
    _judgements = relationship(
        'Judgement', back_populates='_plaintiff'
    )

    def __repr__(self):
        return "<Plaintiff(name='%s', district_id='%s')>" % (self.name, self.district_id)


class Judge(db.Model, Timestamped):
    __tablename__ = "judges"
    id = Column(db.Integer, primary_key=True)
    name = Column(db.String(255), nullable=False)
    district_id = Column(db.Integer, db.ForeignKey(
        'districts.id'), nullable=False)

    db.UniqueConstraint('name', 'district_id')

    district = relationship('District', back_populates='judges')
    cases = relationship('DetainerWarrant', back_populates='_presiding_judge')
    _rulings = relationship('Judgement', back_populates='_judge')

    def __repr__(self):
        return "<Judge(name='%s')>" % (self.name)


class Judgement(db.Model, Timestamped):
    parties = {
        'PLAINTIFF': 0,
        'DEFENDANT': 1
    }

    entrances = {
        'DEFAULT': 0,
        'AGREEMENT_OF_PARTIES': 1,
        'TRIAL_IN_COURT': 2
    }

    dismissal_bases = {
        'FAILURE_TO_PROSECUTE': 0,
        'FINDING_IN_FAVOR_OF_DEFENDANT': 1,
        'NON_SUIT_BY_PLAINTIFF': 2
    }

    __tablename__ = "judgements"
    id = Column(db.Integer, primary_key=True)
    in_favor_of_id = Column(db.Integer)
    awards_possession = Column(db.Boolean)
    awards_fees = Column(db.Numeric(scale=2))
    entered_by_id = Column(db.Integer)
    interest = Column(db.Boolean)
    interest_rate = Column(db.Numeric)
    interest_follows_site = Column(db.Boolean)
    dismissal_basis_id = Column(db.Integer)
    with_prejudice = Column(db.Boolean)
    court_date = Column(db.Date)
    mediation_letter = Column(db.Boolean)
    court_order_number = Column(db.Integer)
    notes = Column(db.String(255))

    detainer_warrant_id = Column(
        db.String(255), db.ForeignKey('detainer_warrants.docket_id'), nullable=False)
    judge_id = Column(db.Integer, db.ForeignKey('judges.id'))
    courtroom_id = Column(db.Integer, db.ForeignKey('courtrooms.id'))
    plaintiff_id = Column(db.Integer, db.ForeignKey(
        'plaintiffs.id', ondelete='CASCADE'))
    plaintiff_attorney_id = Column(db.Integer, db.ForeignKey(
        'attorneys.id', ondelete=('CASCADE')
    ))
    defendant_attorney_id = Column(db.Integer, db.ForeignKey(
        'attorneys.id', ondelete=('CASCADE')
    ))
    last_edited_by_id = Column(db.Integer, db.ForeignKey('user.id'))

    _courtroom = relationship(
        'Courtroom', back_populates='_judgements'
    )
    _detainer_warrant = relationship(
        'DetainerWarrant', back_populates='_judgements')

    _plaintiff = relationship(
        'Plaintiff', back_populates='_judgements'
    )
    _plaintiff_attorney = relationship(
        'Attorney', foreign_keys=plaintiff_attorney_id
    )
    _defendant_attorney = relationship(
        'Attorney', foreign_keys=defendant_attorney_id
    )
    _judge = relationship(
        'Judge', back_populates='_rulings')
    last_edited_by = relationship(
        'User', back_populates='edited_judgements'
    )

    @property
    def courtroom(self):
        return self._courtroom

    @courtroom.setter
    def courtroom(self, courtroom):
        c_id = courtroom and courtroom.get('id')
        if (c_id):
            self._courtroom = db.session.query(Courtroom).get(c_id)
        else:
            self._courtroom = courtroom

    @property
    def in_favor_of(self):
        parties_by_id = {v: k for k, v in Judgement.parties.items()}
        return parties_by_id[self.in_favor_of_id] if self.in_favor_of_id is not None else None

    @in_favor_of.setter
    def in_favor_of(self, in_favor_of):
        self.in_favor_of_id = in_favor_of and Judgement.parties[in_favor_of]

    @property
    def entered_by(self):
        entrances_by_id = {v: k for k, v in Judgement.entrances.items()}
        return entrances_by_id[self.entered_by_id] if self.entered_by_id is not None else 'DEFAULT'

    @entered_by.setter
    def entered_by(self, entered_by):
        self.entered_by_id = entered_by and Judgement.entrances[entered_by]

    @property
    def dismissal_basis(self):
        dismissal_bases_by_id = {v: k for k,
                                 v in Judgement.dismissal_bases.items()}
        return dismissal_bases_by_id[self.dismissal_basis_id] if self.dismissal_basis_id is not None else None

    @dismissal_basis.setter
    def dismissal_basis(self, dismissal_basis):
        self.dismissal_basis_id = self.dismissal_basis_id and Judgement.dismissal_bases[
            dismissal_basis]

    @property
    def judge(self):
        return self._judge

    @judge.setter
    def judge(self, judge):
        j_id = judge and judge.get('id')
        if (j_id):
            self._judge = db.session.query(Judge).get(j_id)
        else:
            self._judge = judge

    @property
    def plaintiff(self):
        return self._plaintiff

    @plaintiff.setter
    def plaintiff(self, plaintiff):
        p_id = plaintiff and plaintiff.get('id')
        if (p_id):
            self._plaintiff = db.session.query(Plaintiff).get(p_id)
        else:
            self._plaintiff = plaintiff

    @property
    def plaintiff_attorney(self):
        return self._plaintiff_attorney

    @plaintiff_attorney.setter
    def plaintiff_attorney(self, attorney):
        a_id = attorney and attorney.get('id')
        if (a_id):
            self._plaintiff_attorney = db.session.query(Attorney).get(a_id)
        else:
            self._plaintiff_attorney = attorney

    @property
    def defendant_attorney(self):
        return self._defendant_attorney

    @defendant_attorney.setter
    def defendant_attorney(self, attorney):
        a_id = attorney and attorney.get('id')
        if (a_id):
            self._defendant_attorney = db.session.query(Attorney).get(a_id)
        else:
            self._defendant_attorney = attorney

    @property
    def courtroom(self):
        return self._courtroom

    @courtroom.setter
    def courtroom(self, courtroom):
        c_id = courtroom and courtroom.get('id')
        if (c_id):
            self._courtroom = db.session.query(Courtroom).get(c_id)
        else:
            self._courtroom = courtroom

    @property
    def detainer_warrant(self):
        return self._detainer_warrant

    @detainer_warrant.setter
    def detainer_warrant(self, warrant):
        w_id = warrant and warrant.get('docket_id')
        if (w_id):
            self._detainer_warrant = db.session.query(
                DetainerWarrant).get(w_id)
        else:
            self._detainer_warrant = warrant

    @property
    def summary(self):
        if bool(self.awards_fees) and bool(self.awards_possession):
            return 'POSS + Payment'
        elif self.awards_possession:
            return 'POSS'
        elif self.awards_fees:
            return 'Fees only'
        elif self.dismissal_basis_id == 2:
            return 'Non-suit'
        elif self.dismissal_basis_id is not None:
            return 'Dismissed'
        else:
            return ''

    def __repr__(self):
        return "<Judgement(in_favor_of='%s')>" % (self.in_favor_of)


class DetainerWarrant(db.Model, Timestamped):
    statuses = {
        'CLOSED': 0,
        'PENDING': 1
    }

    recurring_court_dates = {
        'SUNDAY': 0,
        'MONDAY': 1,
        'TUESDAY': 2,
        'WEDNESDAY': 3,
        'THURSDAY': 4,
        'FRIDAY': 5,
        'SATURDAY': 6
    }

    amount_claimed_categories = {
        'POSS': 0,
        'FEES': 1,
        'BOTH': 2,
        'N/A': 3,
    }

    __tablename__ = 'detainer_warrants'
    docket_id = Column(db.String(255), primary_key=True)
    file_date = Column(db.Date)
    status_id = Column(db.Integer)
    plaintiff_id = Column(db.Integer, db.ForeignKey(
        'plaintiffs.id', ondelete='CASCADE'))
    plaintiff_attorney_id = Column(db.Integer, db.ForeignKey(
        'attorneys.id', ondelete=('CASCADE')
    ))
    court_date = Column(db.Date)
    court_date_recurring_id = Column(db.Integer)
    courtroom_id = Column(db.Integer, db.ForeignKey('courtrooms.id'))
    presiding_judge_id = Column(db.Integer, db.ForeignKey('judges.id'))
    amount_claimed = Column(db.Numeric(scale=2))  # USD
    amount_claimed_category_id = Column(
        db.Integer, nullable=False, default=3, server_default=text("3"))
    is_cares = Column(db.Boolean)
    is_legacy = Column(db.Boolean)
    zip_code = Column(db.String(10))
    nonpayment = Column(db.Boolean)
    notes = Column(db.String(255))
    last_edited_by_id = Column(db.Integer, db.ForeignKey('user.id'))

    _plaintiff = relationship('Plaintiff', back_populates='detainer_warrants')
    _plaintiff_attorney = relationship(
        'Attorney', back_populates='detainer_warrants')
    _courtroom = relationship('Courtroom', back_populates='cases')
    _presiding_judge = relationship('Judge', back_populates='cases')

    _defendants = relationship('Defendant',
                               secondary=detainer_warrant_defendants,
                               back_populates='detainer_warrants',
                               cascade="all, delete",
                               )
    _judgements = relationship('Judgement', back_populates='_detainer_warrant')
    last_edited_by = relationship('User', back_populates='edited_warrants')

    canvass_attempts = relationship(
        'CanvassEvent', secondary=canvass_warrants, back_populates='warrants', cascade="all, delete")

    def __repr__(self):
        return "<DetainerWarrant(docket_id='%s', file_date='%s')>" % (self.docket_id, self.file_date)

    @property
    def status(self):
        status_by_id = {v: k for k, v in DetainerWarrant.statuses.items()}
        return status_by_id[self.status_id] if self.status_id is not None else None

    @status.setter
    def status(self, status_name):
        self.status_id = DetainerWarrant.statuses[status_name] if status_name else None

    @property
    def recurring_court_date(self):
        date_by_id = {v: k for k,
                      v in DetainerWarrant.recurring_court_dates.items()}
        return date_by_id[self.court_date_recurring_id] if self.court_date_recurring_id else None

    @recurring_court_date.setter
    def recurring_court_date(self, day_of_week):
        self.court_date_recurring_id = DetainerWarrant.recurring_court_dates[
            day_of_week] if day_of_week else None

    @property
    def amount_claimed_category(self):
        if self.amount_claimed_category_id is None:
            return None

        category_by_id = {
            v: k for k, v in DetainerWarrant.amount_claimed_categories.items()}
        return category_by_id[self.amount_claimed_category_id]

    @amount_claimed_category.setter
    def amount_claimed_category(self, amount_claimed_category_name):
        self.amount_claimed_category_id = DetainerWarrant.amount_claimed_categories[
            amount_claimed_category_name] if amount_claimed_category_name else None

    @property
    def plaintiff(self):
        return self._plaintiff

    @plaintiff.setter
    def plaintiff(self, plaintiff):
        p_id = plaintiff and plaintiff.get('id')
        if (p_id):
            self._plaintiff = db.session.query(Plaintiff).get(p_id)
        else:
            self._plaintiff = plaintiff

    @property
    def plaintiff_attorney(self):
        return self._plaintiff_attorney

    @plaintiff_attorney.setter
    def plaintiff_attorney(self, attorney):
        a_id = attorney and attorney.get('id')
        if (a_id):
            self._plaintiff_attorney = db.session.query(Attorney).get(a_id)
        else:
            self._plaintiff_attorney = attorney

    @property
    def courtroom(self):
        return self._courtroom

    @courtroom.setter
    def courtroom(self, courtroom):
        c_id = courtroom and courtroom.get('id')
        if (c_id):
            self._courtroom = db.session.query(Courtroom).get(c_id)
        else:
            self._courtroom = courtroom

    @property
    def presiding_judge(self):
        return self._presiding_judge

    @presiding_judge.setter
    def presiding_judge(self, judge):
        j_id = judge and judge.get('id')
        if (j_id):
            self._presiding_judge = db.session.query(Judge).get(j_id)
        else:
            self._presiding_judge = judge

    @property
    def defendants(self):
        return self._defendants

    @defendants.setter
    def defendants(self, defendants):
        if (all(isinstance(d, Defendant) for d in defendants)):
            self._defendants = defendants
        else:
            self._defendants = [db.session.query(
                Defendant).get(d.get('id')) for d in defendants]

    @property
    def judgements(self):
        return sorted(self._judgements, key=lambda j: (j.court_date is not None, j.court_date), reverse=True)

    @judgements.setter
    def judgements(self, judgements):
        if (all(isinstance(j, Judgement) for j in judgements)):
            self._judgements = judgements
        else:
            if (len(judgements) < len(self._judgements)):
                original = set([j.id for j in self._judgements])
                new = set([j.get("id") for j in judgements])
                judgements_to_delete = original - new
                for j_id in judgements_to_delete:
                    db.session.delete(db.session.query(Judgement).get(j_id))

            self._judgements = [
                db.session.query(Judgement).get(j.get('id')).update(**j)
                if j.get('id') is not None
                else Judgement.create(**j, detainer_warrant_id=self.docket_id)
                for j in judgements
            ]


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

    defendants = relationship('Defendant', back_populates='verified_phone')

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
