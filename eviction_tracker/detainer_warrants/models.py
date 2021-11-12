from eviction_tracker.database import db, PosixComparator, in_millis, from_millis, Timestamped, Column, Model, relationship
from datetime import datetime, date, timezone
from sqlalchemy import func, text
from flask_security import UserMixin, RoleMixin
from eviction_tracker.direct_action.models import phone_bank_tenants, canvass_warrants
from sqlalchemy.ext.hybrid import hybrid_property
from nameparser import HumanName
from ..util import get_or_create
import re


def district_defaults():
    district = District.query.filter_by(name="Davidson County").first()
    return {'district': district}


class District(db.Model, Timestamped):
    __tablename__ = 'districts'
    __table_args__ = (
        db.UniqueConstraint('name'),
    )
    id = Column(db.Integer, primary_key=True)
    name = Column(db.String(255), nullable=False)

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
    __table_args__ = (
        db.UniqueConstraint('first_name', 'middle_name',
                            'last_name', 'suffix', 'address', 'district_id', 'potential_phones'),
    )

    id = Column(db.Integer, primary_key=True)
    first_name = Column(db.String(255))
    middle_name = Column(db.String(50))
    last_name = Column(db.String(50))
    suffix = Column(db.String(20))
    aliases = Column(db.ARRAY(db.String(255)),
                     nullable=False, server_default='{}')
    potential_phones = Column(db.String(255))
    address = Column(db.String(255))

    district_id = Column(db.Integer, db.ForeignKey(
        'districts.id'), nullable=False)
    verified_phone_id = Column(db.Integer, db.ForeignKey(
        'phone_number_verifications.id'))

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

    @hybrid_property
    def name(self):
        return ' '.join([name for name in [self.first_name, self.middle_name, self.last_name, self.suffix] if name])

    @name.expression
    def name(cls):
        return func.concat(
            func.coalesce(cls.first_name + ' ', ''),
            func.coalesce(cls.middle_name + ' ', ''),
            func.coalesce(cls.last_name + ' ', ''),
            func.coalesce(cls.suffix, '')
        )

    @name.setter
    def name(self, full_name):
        human_name = HumanName(full_name.replace('OR ALL OCCUPANTS', ''))

        if human_name.first:
            self.first_name = human_name.first
            self.middle_name = human_name.middle
            self.last_name = human_name.last
            self.suffix = human_name.suffix
        else:
            self.first_name = full_name

    def __repr__(self):
        return f"<Defendant(name='{self.name}', phones='{self.potential_phones}', address='{self.address}')>"


class Attorney(db.Model, Timestamped):
    __tablename__ = 'attorneys'
    __table_args__ = (
        db.UniqueConstraint('name', 'district_id'),
    )
    id = Column(db.Integer, primary_key=True)
    name = Column(db.String(255), nullable=False)
    aliases = Column(db.ARRAY(db.String(255)),
                     nullable=False, server_default='{}')
    district_id = Column(db.Integer, db.ForeignKey(
        'districts.id'), nullable=False)

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
    __table_args__ = (
        db.UniqueConstraint('name', 'district_id'),
    )
    id = Column(db.Integer, primary_key=True)
    name = Column(db.String(255), nullable=False)
    district_id = Column(db.Integer, db.ForeignKey(
        'districts.id'), nullable=False)

    district = relationship('District', back_populates='courtrooms')
    _judgements = relationship('Judgement', back_populates='_courtroom')

    def __repr__(self):
        return "<Courtroom(name='%s')>" % (self.name)


class Plaintiff(db.Model, Timestamped):
    __tablename__ = 'plaintiffs'
    __table_args__ = (
        db.UniqueConstraint('name', 'district_id'),
    )
    id = Column(db.Integer, primary_key=True)
    name = Column(db.String(255), nullable=False)
    aliases = Column(db.ARRAY(db.String(255)),
                     nullable=False, server_default='{}')
    district_id = Column(db.Integer, db.ForeignKey(
        'districts.id'), nullable=False)

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
    __table_args__ = (
        db.UniqueConstraint('name', 'district_id'),
    )
    id = Column(db.Integer, primary_key=True)
    name = Column(db.String(255), nullable=False)
    aliases = Column(db.ARRAY(db.String(255)),
                     nullable=False, server_default='{}')
    district_id = Column(db.Integer, db.ForeignKey(
        'districts.id'), nullable=False)

    district = relationship('District', back_populates='judges')
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
    _court_date = Column(db.Date, name='court_date')
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

    @hybrid_property
    def court_date(self):
        if self._court_date:
            return in_millis(datetime.combine(self._court_date, datetime.min.time()).timestamp())
        else:
            return None

    @court_date.comparator
    def court_date(cls):
        return PosixComparator(cls._court_date)

    @court_date.setter
    def court_date(self, posix):
        self._court_date = from_millis(posix)

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
        self.dismissal_basis_id = dismissal_basis and Judgement.dismissal_bases[
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
        return "<Judgement(in_favor_of='%s', docket_id='%s')>" % (self.in_favor_of, self.detainer_warrant_id)

    def from_pdf_as_text(pdf):
        defaults = district_defaults()
        checked = u''
        unchecked = u''

        dw_regex = re.compile(r'DOCKET NO.:\s*(\w+)\s*')
        detainer_warrant_id = dw_regex.search(pdf).group(1)

        if detainer_warrant_id and not DetainerWarrant.query.get(detainer_warrant_id):
            DetainerWarrant.create(docket_id=detainer_warrant_id)
            db.session.commit()

        plaintiff_regex = re.compile(
            r'COUNTY, TENNESSEE\s*([\w\s]+?)\s*Plaintiff')
        plaintiff_name = plaintiff_regex.search(pdf).group(1)

        plaintiff = None
        if plaintiff_name:
            plaintiff, _ = get_or_create(
                db.session, Plaintiff, name=plaintiff_name, defaults=defaults)

        judge_regex = re.compile(
            r'The foregoing is hereby.+Judge (.+?),{0,1}\s+Division')
        judge_name = judge_regex.search(pdf).group(1)

        judge = None
        if judge_name:
            judge, _ = get_or_create(
                db.session, Judge, name=judge_name, defaults=defaults)

        in_favor_plaintiff_regex = re.compile(
            r'Order\s*(.+)\s*Judgment is granted')
        in_favor_plaintiff = checked in in_favor_plaintiff_regex.search(
            pdf).group(1)

        in_favor_defendant_regex = re.compile(
            r'per annum\s*(.+)\s*Case is dismissed')
        in_favor_defendant = checked in in_favor_defendant_regex.search(
            pdf).group(1)

        in_favor_of = None
        if in_favor_defendant:
            in_favor_of = 'DEFENDANT'
        elif in_favor_plaintiff:
            in_favor_of = 'PLAINTIFF'

        fees_regex = re.compile(
            r'against\s*(.+)\s*for possession of the described property in the Detainer Warrant and all costs')
        possession_regex = re.compile(
            r'issue\.\s*(.+)\s*for possession of the described property in the Detainer Warrant, plus a monetary')
        awards_possession = checked in possession_regex.search(pdf).group(1)

        awards_fees_amount_regex = re.compile(r'\$\s*([\d\.]+?)\s+')

        awards_fees = None
        if awards_fees_amount_regex.search(pdf):
            awards_fees = awards_fees_amount_regex.search(pdf).group(1)

        entered_by_default_regex = re.compile(
            r'Judgment is entered by:\s*(.+)\s*Default.')
        entered_by_agreement_regex = re.compile(
            r'Default.\s*(.+)\s*Agreement of parties.')
        entered_by_trial_regex = re.compile(
            r'parties.\s*(.+)\s*Trial in Court')
        entered_by = None
        if checked in entered_by_default_regex.search(pdf).group(1):
            entered_by = 'DEFAULT'
        elif checked in entered_by_agreement_regex.search(pdf).group(1):
            entered_by = 'AGREEMENT_OF_PARTIES'
        elif checked in entered_by_trial_regex.search(pdf).group(1):
            entered_by = 'TRIAL_IN_COURT'

        interest_follows_site = checked in re.compile(
            r'granted as follows:\s*(.+)\s*at the rate posted').search(pdf).group(1)
        interest_rate_regex = re.compile(
            r'Courts.\s*(.+)\s*at the rate of %\s*([\d\.]*)\s*per annum')
        interest_rate_match = interest_rate_regex.search(pdf)
        if checked in interest_rate_match.group(1):
            interest_rate = interest_rate_match.group(2)
        else:
            interest_rate = None
        interest = interest_follows_site or interest_rate

        dismissal_basis, with_prejudice = None, None
        if in_favor_defendant:
            dismissal_failure_regex = re.compile(
                r'Dismissal is based on:\s*(.+)\s*Failure to prosecute.')
            dismissal_favor_regex = re.compile(
                r'prosecute\.\s*(.+)\s*Finding in favor of Defendant')
            dismissal_non_suit = re.compile(
                r'after trial.\s*(.+)\s*Non-suit by Plaintiff')

            if checked in dismissal_failure_regex.search(pdf).group(1):
                dismissal_basis = 'FAILURE_TO_PROSECUTE'
            elif checked in dismissal_favor_regex.search(pdf).group(1):
                dismissal_basis = 'FINDING_IN_FAVOR_OF_DEFENDANT'
            elif checked in dismissal_non_suit_regex.search(pdf).group(1):
                dismissal_basis = 'NON_SUIT_BY_PLAINTIFF'

            with_prejudice_regex = re.compile(
                r'Dismissal is:\s*(.+)\s*Without prejudice')
            with_prejudice = not checked in with_prejudice_regex.search(
                pdf).group(1)

        notes_regex = re.compile(
            r'Other terms of this Order, if any, are as follows:\s*(.+?)\s*EFILED')
        notes = notes_regex.search(pdf).group(1)

        return Judgement.create(
            awards_possession=awards_possession,
            awards_fees=awards_fees,
            entered_by_id=Judgement.entrances[entered_by],
            interest=interest,
            interest_rate=interest_rate,
            interest_follows_site=interest_follows_site,
            dismissal_basis_id=Judgement.dismissal_bases[dismissal_basis] if dismissal_basis else None,
            with_prejudice=with_prejudice,
            notes=notes,
            in_favor_of_id=Judgement.parties[in_favor_of],
            detainer_warrant_id=detainer_warrant_id,
            plaintiff_id=plaintiff.id if plaintiff else None,
            judge_id=judge.id if judge else None
        )


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
    _docket_id = Column(db.String(255), primary_key=True, name="docket_id")
    order_number = Column(db.BigInteger, nullable=False)
    _file_date = Column(db.Date, name="file_date")
    status_id = Column(db.Integer)
    plaintiff_id = Column(db.Integer, db.ForeignKey(
        'plaintiffs.id', ondelete='CASCADE'))
    plaintiff_attorney_id = Column(db.Integer, db.ForeignKey(
        'attorneys.id', ondelete=('CASCADE')
    ))
    court_date_recurring_id = Column(db.Integer)
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
        return "<DetainerWarrant(docket_id='%s', file_date='%s')>" % (self.docket_id, self._file_date)

    @hybrid_property
    def docket_id(self):
        return self._docket_id

    @docket_id.setter
    def docket_id(self, id):
        self._docket_id = id
        self.order_number = DetainerWarrant.calc_order_number(id)

    def calc_order_number(docket_id):
        num = docket_id.replace('GT', '').replace('GC', '')
        if num.isnumeric():
            return int(num)
        else:
            return 0

    @hybrid_property
    def file_date(self):
        if self._file_date:
            return in_millis(datetime.combine(self._file_date, datetime.min.time()).timestamp())
        else:
            return None

    @file_date.comparator
    def file_date(cls):
        return PosixComparator(cls._file_date)

    @file_date.setter
    def file_date(self, posix):
        self._file_date = from_millis(posix) if posix else None

    @hybrid_property
    def court_date(self):
        if self._court_date:
            return in_millis(datetime.combine(self._court_date, datetime.min.time()).timestamp())
        else:
            return None

    @court_date.comparator
    def court_date(cls):
        return PosixComparator(cls._court_date)

    @court_date.setter
    def court_date(self, posix):
        self._court_date = from_millis(posix) if posix else None

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
