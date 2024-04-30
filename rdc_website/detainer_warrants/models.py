from rdc_website.database import (
    db,
    PosixComparator,
    in_millis,
    from_millis,
    Timestamped,
    Column,
    Model,
    relationship,
)
from datetime import datetime, date, timezone
from sqlalchemy import func, text, case
from flask_security import UserMixin, RoleMixin
from rdc_website.direct_action.models import phone_bank_tenants, canvass_warrants
from sqlalchemy.ext.hybrid import hybrid_property
from nameparser import HumanName
from ..util import get_or_create, file_date_guess
import re
from .judgments import regexes


detainer_warrant_defendants = db.Table(
    "detainer_warrant_defendants",
    db.metadata,
    Column(
        "detainer_warrant_docket_id",
        db.ForeignKey("cases.docket_id", ondelete="CASCADE"),
        primary_key=True,
    ),
    Column(
        "defendant_id",
        db.ForeignKey("defendants.id", ondelete="CASCADE"),
        primary_key=True,
    ),
)

hearing_defendants = db.Table(
    "hearing_defendants",
    db.metadata,
    Column(
        "hearing_id", db.ForeignKey("hearings.id", ondelete="CASCADE"), primary_key=True
    ),
    Column(
        "defendant_id",
        db.ForeignKey("defendants.id", ondelete="CASCADE"),
        primary_key=True,
    ),
)


class Defendant(db.Model, Timestamped):
    __tablename__ = "defendants"
    __table_args__ = (
        db.UniqueConstraint(
            "first_name", "middle_name", "last_name", "suffix", "potential_phones"
        ),
    )

    id = Column(db.Integer, primary_key=True)
    first_name = Column(db.String(255))
    middle_name = Column(db.String(255))
    last_name = Column(db.String(255))
    suffix = Column(db.String(255))
    aliases = Column(db.ARRAY(db.String(255)), nullable=False, server_default="{}")
    potential_phones = Column(db.String(255))

    verified_phone_id = Column(
        db.Integer, db.ForeignKey("phone_number_verifications.id")
    )

    detainer_warrants = relationship(
        "DetainerWarrant",
        secondary=detainer_warrant_defendants,
        back_populates="_defendants",
        passive_deletes=True,
    )
    hearings = relationship(
        "Hearing",
        secondary=hearing_defendants,
        back_populates="defendants",
        passive_deletes=True,
    )
    verified_phone = relationship(
        "PhoneNumberVerification", back_populates="defendants"
    )
    phone_bank_attempts = relationship(
        "PhoneBankEvent", secondary=phone_bank_tenants, back_populates="tenants"
    )

    @hybrid_property
    def name(self):
        return " ".join(
            [
                name
                for name in [
                    self.first_name,
                    self.middle_name,
                    self.last_name,
                    self.suffix,
                ]
                if name
            ]
        )

    @name.expression
    def name(cls):
        return func.concat(
            func.coalesce(cls.first_name + " ", ""),
            func.coalesce(cls.middle_name + " ", ""),
            func.coalesce(cls.last_name + " ", ""),
            func.coalesce(cls.suffix, ""),
        )

    @name.setter
    def name(self, full_name):
        human_name = HumanName(full_name.replace("OR ALL OCCUPANTS", ""))

        if human_name.first:
            self.first_name = human_name.first
            self.middle_name = human_name.middle
            self.last_name = human_name.last
            self.suffix = human_name.suffix
        else:
            self.first_name = full_name

    def __repr__(self):
        return f"<Defendant(name='{self.name}', phones='{self.potential_phones}')>"


class Attorney(db.Model, Timestamped):
    __tablename__ = "attorneys"
    id = Column(db.Integer, primary_key=True)
    name = Column(db.String(255), nullable=False)
    aliases = Column(db.ARRAY(db.String(255)), nullable=False, server_default="{}")
    detainer_warrants = relationship(
        "DetainerWarrant", back_populates="_plaintiff_attorney"
    )

    def __repr__(self):
        return f"<Attorney(name='{self.name}'>"


class Courtroom(db.Model, Timestamped):
    __tablename__ = "courtrooms"
    id = Column(db.Integer, primary_key=True)
    name = Column(db.String(255), nullable=False)

    hearings = relationship("Hearing", back_populates="courtroom")

    def __repr__(self):
        return f"<Courtroom(name='{self.name}')>"


class Plaintiff(db.Model, Timestamped):
    __tablename__ = "plaintiffs"
    id = Column(db.Integer, primary_key=True)
    name = Column(db.String(255), nullable=False)
    aliases = Column(db.ARRAY(db.String(255)), nullable=False, server_default="{}")

    detainer_warrants = relationship("DetainerWarrant", back_populates="_plaintiff")
    _judgments = relationship("Judgment", back_populates="_plaintiff")
    hearings = relationship("Hearing", back_populates="plaintiff")

    def __repr__(self):
        return f"<Plaintiff(name='{self.name}')>"


class Judge(db.Model, Timestamped):
    __tablename__ = "judges"
    id = Column(db.Integer, primary_key=True)
    name = Column(db.String(255), nullable=False)
    aliases = Column(db.ARRAY(db.String(255)), nullable=False, server_default="{}")

    _rulings = relationship("Judgment", back_populates="_judge")

    def __repr__(self):
        return f"<Judge(name='{self.name}')>"


class Hearing(db.Model, Timestamped):
    __tablename__ = "hearings"
    __table_args__ = (db.UniqueConstraint("court_date", "docket_id"),)

    id = Column(db.Integer, primary_key=True)
    _court_date = Column(db.DateTime, name="court_date", nullable=False)
    address = Column(db.String(255))
    court_order_number = Column(db.Integer)

    _continuance_on = Column(db.Date, name="continuance_on")

    docket_id = Column(db.String(255), db.ForeignKey("cases.docket_id"), nullable=False)
    courtroom_id = Column(db.Integer, db.ForeignKey("courtrooms.id"))
    plaintiff_id = Column(
        db.Integer, db.ForeignKey("plaintiffs.id", ondelete="CASCADE")
    )
    plaintiff_attorney_id = Column(
        db.Integer, db.ForeignKey("attorneys.id", ondelete=("CASCADE"))
    )
    defendant_attorney_id = Column(
        db.Integer, db.ForeignKey("attorneys.id", ondelete=("CASCADE"))
    )

    judgment = relationship("Judgment", uselist=False, backref="hearing")
    case = relationship("Case", back_populates="hearings")
    courtroom = relationship("Courtroom", back_populates="hearings")
    plaintiff = relationship("Plaintiff", back_populates="hearings")
    plaintiff_attorney = relationship("Attorney", foreign_keys=plaintiff_attorney_id)
    defendant_attorney = relationship("Attorney", foreign_keys=defendant_attorney_id)

    defendants = relationship(
        "Defendant",
        secondary=hearing_defendants,
        back_populates="hearings",
        cascade="all, delete",
    )

    @hybrid_property
    def court_date(self):
        if self._court_date:
            return in_millis(self._court_date.timestamp())
        else:
            return None

    @court_date.comparator
    def court_date(cls):
        return PosixComparator(cls._court_date)

    @hybrid_property
    def continuance_on(self):
        if self._continuance_on:
            return in_millis(
                datetime.combine(self._continuance_on, datetime.min.time()).timestamp()
            )
        else:
            return None

    @continuance_on.comparator
    def continuance_on(cls):
        return PosixComparator(cls._continuance_on)

    @continuance_on.setter
    def continuance_on(self, posix):
        self._continuance_on = from_millis(posix)

    @court_date.setter
    def court_date(self, posix):
        self._court_date = from_millis(posix)

    def __repr__(self):
        return (
            f"<Hearing(court_date='{self._court_date}', docket_id='{self.docket_id}')>"
        )

    def update_judgment_from_document(self, document):
        attrs = Judgment.attributes_from_pdf(document.text)
        if not attrs:
            return self
        attrs["document_url"] = document.url
        if self.judgment:
            self.judgment.update(**attrs)
        else:
            self.judgment = Judgment.create(**attrs)
        return self


def search(regex, text, default=None):
    match = regex.search(text)
    return match.group(1) if match else default


def match(regex, text, default=None):
    match = regex.search(text)
    return match if match else default


checked = ""  # \uf0fd
unchecked = ""  # \uf06f


class Judgment(db.Model, Timestamped):
    parties = {"PLAINTIFF": 0, "DEFENDANT": 1}

    entrances = {"DEFAULT": 0, "AGREEMENT_OF_PARTIES": 1, "TRIAL_IN_COURT": 2}

    dismissal_bases = {
        "FAILURE_TO_PROSECUTE": 0,
        "FINDING_IN_FAVOR_OF_DEFENDANT": 1,
        "NON_SUIT_BY_PLAINTIFF": 2,
    }

    __tablename__ = "judgments"
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
    _file_date = Column(db.Date, name="file_date")
    mediation_letter = Column(db.Boolean)
    notes = Column(db.Text)

    hearing_id = Column(
        db.Integer, db.ForeignKey("hearings.id", ondelete="CASCADE")
    )  # TODO: make non-nullable after data cleanup
    detainer_warrant_id = Column(
        db.String(255), db.ForeignKey("cases.docket_id"), nullable=False
    )
    judge_id = Column(db.Integer, db.ForeignKey("judges.id"))
    plaintiff_id = Column(
        db.Integer, db.ForeignKey("plaintiffs.id", ondelete="CASCADE")
    )
    plaintiff_attorney_id = Column(
        db.Integer, db.ForeignKey("attorneys.id", ondelete=("CASCADE"))
    )
    defendant_attorney_id = Column(
        db.Integer, db.ForeignKey("attorneys.id", ondelete=("CASCADE"))
    )
    document_url = Column(db.String, db.ForeignKey("pleading_documents.url"))
    last_edited_by_id = Column(db.Integer, db.ForeignKey("user.id"))

    _plaintiff = relationship("Plaintiff", back_populates="_judgments")
    _plaintiff_attorney = relationship("Attorney", foreign_keys=plaintiff_attorney_id)
    _defendant_attorney = relationship("Attorney", foreign_keys=defendant_attorney_id)
    _judge = relationship("Judge", back_populates="_rulings")
    document = relationship("PleadingDocument", back_populates="judgments")
    last_edited_by = relationship("User", back_populates="edited_judgments")
    detainer_warrant = relationship("DetainerWarrant", back_populates="judgments")

    @hybrid_property
    def file_date(self):
        if self._file_date:
            return in_millis(
                datetime.combine(self._file_date, datetime.min.time()).timestamp()
            )
        else:
            return None

    @file_date.comparator
    def file_date(cls):
        return PosixComparator(cls._file_date)

    @file_date.setter
    def file_date(self, posix):
        self._file_date = from_millis(posix)

    @property
    def in_favor_of(self):
        parties_by_id = {v: k for k, v in Judgment.parties.items()}
        return (
            parties_by_id[self.in_favor_of_id]
            if self.in_favor_of_id is not None
            else None
        )

    @in_favor_of.setter
    def in_favor_of(self, in_favor_of):
        self.in_favor_of_id = in_favor_of and Judgment.parties[in_favor_of]

    @property
    def entered_by(self):
        entrances_by_id = {v: k for k, v in Judgment.entrances.items()}
        return (
            entrances_by_id[self.entered_by_id]
            if self.entered_by_id is not None
            else "DEFAULT"
        )

    @entered_by.setter
    def entered_by(self, entered_by):
        self.entered_by_id = entered_by and Judgment.entrances[entered_by]

    @property
    def dismissal_basis(self):
        dismissal_bases_by_id = {v: k for k, v in Judgment.dismissal_bases.items()}
        return (
            dismissal_bases_by_id[self.dismissal_basis_id]
            if self.dismissal_basis_id is not None
            else None
        )

    @dismissal_basis.setter
    def dismissal_basis(self, dismissal_basis):
        self.dismissal_basis_id = (
            dismissal_basis and Judgment.dismissal_bases[dismissal_basis]
        )

    @property
    def judge(self):
        return self._judge

    @judge.setter
    def judge(self, judge):
        j_id = judge and judge.get("id")
        if j_id:
            self._judge = db.session.query(Judge).get(j_id)
        else:
            self._judge = judge

    @property
    def plaintiff(self):
        return self._plaintiff

    @plaintiff.setter
    def plaintiff(self, plaintiff):
        p_id = plaintiff and plaintiff.get("id")
        if p_id:
            self._plaintiff = db.session.query(Plaintiff).get(p_id)
        else:
            self._plaintiff = plaintiff

    @property
    def plaintiff_attorney(self):
        return self._plaintiff_attorney

    @plaintiff_attorney.setter
    def plaintiff_attorney(self, attorney):
        a_id = attorney and attorney.get("id")
        if a_id:
            self._plaintiff_attorney = db.session.query(Attorney).get(a_id)
        else:
            self._plaintiff_attorney = attorney

    @property
    def defendant_attorney(self):
        return self._defendant_attorney

    @defendant_attorney.setter
    def defendant_attorney(self, attorney):
        a_id = attorney and attorney.get("id")
        if a_id:
            self._defendant_attorney = db.session.query(Attorney).get(a_id)
        else:
            self._defendant_attorney = attorney

    @property
    def courtroom(self):
        return self._courtroom

    @courtroom.setter
    def courtroom(self, courtroom):
        c_id = courtroom and courtroom.get("id")
        if c_id:
            self._courtroom = db.session.query(Courtroom).get(c_id)
        else:
            self._courtroom = courtroom

    @property
    def summary(self):
        if bool(self.awards_fees) and bool(self.awards_possession):
            return "POSS + Payment"
        elif self.awards_possession:
            return "POSS"
        elif self.awards_fees:
            return "Fees only"
        elif self.dismissal_basis_id == 2:
            return "Non-suit"
        elif self.dismissal_basis_id is not None:
            return "Dismissed"
        else:
            return ""

    def __repr__(self):
        return f"<Judgment(in_favor_of='{self.in_favor_of}', docket_id='{self.detainer_warrant_id}')>"

    def attributes_from_pdf(pdf):
        pdf = pdf.replace("\n", " ").replace("\r", " ")

        docket_match = regexes.DOCKET_ID.search(pdf)
        if not docket_match:
            return

        docket_id = docket_match.group(1)

        if docket_id and not DetainerWarrant.query.get(docket_id):
            DetainerWarrant.create(docket_id=docket_id)
            db.session.commit()

        plaintiff_name = search(regexes.PLAINTIFF, pdf)

        plaintiff = None
        if plaintiff_name:
            plaintiff, _ = get_or_create(db.session, Plaintiff, name=plaintiff_name)

        judge_name = search(regexes.JUDGE, pdf)

        judge = None
        if judge_name:
            judge, _ = get_or_create(db.session, Judge, name=judge_name)

        in_favor_plaintiff = checked in search(
            regexes.IN_FAVOR_PLAINTIFF, pdf, default=""
        )

        in_favor_defendant = checked in search(
            regexes.IN_FAVOR_DEFENDANT, pdf, default=""
        )

        in_favor_of = None
        if in_favor_defendant:
            in_favor_of = "DEFENDANT"
        elif in_favor_plaintiff:
            in_favor_of = "PLAINTIFF"

        awards_match = regexes.AWARDS.search(pdf)
        awards_possession = None
        if awards_match:
            awards_possession_and_suit = checked in awards_match.group(1)
            awards_possession_and_fees = checked in awards_match.group(2)
            awards_possession = awards_possession_and_suit or awards_possession_and_fees

        awards_fees = search(regexes.AWARDS_FEES_AMOUNT, pdf)
        if awards_fees:
            awards_fees = awards_fees.replace(",", "").strip()
            if awards_fees.endswith("."):
                awards_fees = awards_fees[:-1]

        entered_by = None
        if checked in search(regexes.ENTERED_BY_DEFAULT, pdf, default=""):
            entered_by = "DEFAULT"
        elif checked in search(regexes.ENTERED_BY_AGREEMENT, pdf, default=""):
            entered_by = "AGREEMENT_OF_PARTIES"
        elif checked in search(regexes.ENTERED_BY_TRIAL, pdf, default=""):
            entered_by = "TRIAL_IN_COURT"

        interest_follows_site = checked in search(
            regexes.INTEREST_FOLLOWS_SITE, pdf, default=""
        )
        interest_rate_match = match(regexes.INTEREST_RATE, pdf, default="")
        if (
            interest_rate_match
            and checked in interest_rate_match.group(1)
            and interest_rate_match.group(2) != ""
        ):
            interest_rate = interest_rate_match.group(2)
        else:
            interest_rate = None
        interest = interest_follows_site or interest_rate

        dismissal_basis, with_prejudice = None, None
        if in_favor_defendant:
            if checked in search(regexes.DISMISSAL_FAILURE, pdf, default=""):
                dismissal_basis = "FAILURE_TO_PROSECUTE"
            elif checked in search(regexes.DISMISSAL_FAVOR, pdf, default=""):
                dismissal_basis = "FINDING_IN_FAVOR_OF_DEFENDANT"
            elif checked in search(regexes.DISMISSAL_NON_SUIT, pdf, default=""):
                dismissal_basis = "NON_SUIT_BY_PLAINTIFF"

            with_prejudice = not checked in search(
                regexes.WITH_PREJUDICE, pdf, default=""
            )

        notes = search(regexes.NOTES, pdf)

        return dict(
            awards_possession=awards_possession,
            awards_fees=awards_fees,
            entered_by_id=Judgment.entrances[entered_by] if entered_by else None,
            interest=interest,
            interest_rate=interest_rate,
            interest_follows_site=interest_follows_site if awards_fees else None,
            dismissal_basis_id=Judgment.dismissal_bases[dismissal_basis]
            if dismissal_basis
            else None,
            with_prejudice=with_prejudice,
            notes=notes,
            in_favor_of_id=Judgment.parties[in_favor_of] if in_favor_of else None,
            detainer_warrant_id=docket_id,
            _file_date=file_date_guess(pdf),
            plaintiff_id=plaintiff.id if plaintiff else None,
            judge_id=judge.id if judge else None,
        )


class PleadingDocument(db.Model, Timestamped):
    kinds = {"JUDGMENT": 0, "DETAINER_WARRANT": 1}

    statuses = {
        "FAILED_TO_EXTRACT_TEXT": 0,
        "FAILED_TO_UPDATE_DETAINER_WARRANT": 1,
        "FAILED_TO_UPDATE_JUDGMENT": 2,
        "FAILED_TO_EXTRACT_TEXT_OCR": 3,
    }

    __tablename__ = "pleading_documents"
    url = Column(db.String(255), primary_key=True)
    text = Column(db.Text)
    kind_id = Column(db.Integer)
    docket_id = Column(db.String(255), db.ForeignKey("cases.docket_id"), nullable=False)
    status_id = Column(db.Integer)

    judgments = relationship("Judgment", back_populates="document")
    detainer_warrant = relationship(
        "DetainerWarrant", foreign_keys=docket_id, back_populates="pleadings"
    )

    @hybrid_property
    def kind(self):
        kind_by_id = {v: k for k, v in PleadingDocument.kinds.items()}
        return kind_by_id[self.kind_id] if self.kind_id is not None else None

    @kind.setter
    def kind(self, kind_name):
        self.kind_id = PleadingDocument.kinds[kind_name] if kind_name else None

    @kind.expression
    def kind(cls):
        return case(
            [(cls.kind_id == 0, "JUDGMENT"), (cls.kind_id == 1, "DETAINER_WARRANT")],
            else_=None,
        ).label("kind")

    @hybrid_property
    def status(self):
        status_by_id = {v: k for k, v in PleadingDocument.statuses.items()}
        return status_by_id[self.status_id] if self.status_id is not None else None

    @status.setter
    def status(self, status_name):
        self.status_id = PleadingDocument.statuses[status_name] if status_name else None

    @status.expression
    def status(cls):
        return case(
            [
                (cls.status_id == 0, "FAILED_TO_EXTRACT_TEXT"),
                (cls.status_id == 1, "FAILED_TO_UPDATE_DETAINER_WARRANT"),
                (cls.status_id == 2, "FAILED_TO_UPDATE_JUDGMENT"),
                (cls.status_id == 3, "FAILED_TO_EXTRACT_TEXT_OCR"),
            ],
            else_=None,
        ).label("status")

    def __repr__(self):
        return f"<PleadingDocument(docket_id='{self.docket_id}', kind='{self.kind}', url='{self.url}')>"


detainer_warrant_addresses = db.Table(
    "detainer_warrant_addresses",
    db.metadata,
    Column(
        "docket_id",
        db.ForeignKey("cases.docket_id", ondelete="CASCADE"),
        primary_key=True,
    ),
    Column(
        "address_id",
        db.ForeignKey("addresses.text", ondelete="CASCADE"),
        primary_key=True,
    ),
)


class Address(db.Model, Timestamped):
    __tablename__ = "addresses"

    text = Column(db.String(255), nullable=False, primary_key=True)

    potential_detainer_warrants = relationship(
        "DetainerWarrant",
        secondary=detainer_warrant_addresses,
        back_populates="potential_addresses",
        passive_deletes=True,
    )


MAX_CASES_PER_YEAR = 10_000_000


class Case(db.Model, Timestamped):
    statuses = {"CLOSED": 0, "PENDING": 1}

    def calc_order_number(docket_id):
        num = docket_id.replace("GT", "").replace("GC", "")
        if num.isnumeric():
            current_year = int(num[:2])
            this_century = current_year < 70
            full_year = current_year + 2000 if this_century else current_year + 1900

            return full_year * MAX_CASES_PER_YEAR + int(num[2:])
        else:
            return 0

    __tablename__ = "cases"
    _docket_id = Column(db.String(255), primary_key=True, name="docket_id")
    order_number = Column(db.BigInteger, nullable=False)
    _file_date = Column(db.Date, name="file_date")
    status_id = Column(db.Integer)
    plaintiff_id = Column(
        db.Integer, db.ForeignKey("plaintiffs.id", ondelete="CASCADE")
    )
    plaintiff_attorney_id = Column(
        db.Integer, db.ForeignKey("attorneys.id", ondelete=("CASCADE"))
    )
    type = Column(db.String(50))

    hearings = relationship("Hearing", back_populates="case")
    _plaintiff = relationship("Plaintiff", back_populates="detainer_warrants")
    _plaintiff_attorney = relationship("Attorney", back_populates="detainer_warrants")

    _defendants = relationship(
        "Defendant",
        secondary=detainer_warrant_defendants,
        back_populates="detainer_warrants",
        cascade="all, delete",
    )

    __mapper_args__ = {"polymorphic_on": type, "polymorphic_identity": "cases"}

    @hybrid_property
    def docket_id(self):
        return self._docket_id

    @docket_id.setter
    def docket_id(self, id):
        self._docket_id = id
        self.order_number = Case.calc_order_number(id)
        if "GT" in id:
            self.type = "detainer_warrant"
        elif "GC" in id:
            self.type = "civil_warrant"
        else:
            self.type = "uncategorized_case"

    @hybrid_property
    def file_date(self):
        if self._file_date:
            return in_millis(
                datetime.combine(self._file_date, datetime.min.time()).timestamp()
            )
        else:
            return None

    @file_date.comparator
    def file_date(cls):
        return PosixComparator(cls._file_date)

    @file_date.setter
    def file_date(self, posix):
        self._file_date = from_millis(posix) if posix else None

    @hybrid_property
    def status(self):
        status_by_id = {v: k for k, v in DetainerWarrant.statuses.items()}
        return status_by_id[self.status_id] if self.status_id is not None else None

    @status.expression
    def status(cls):
        return case(
            [(cls.status_id == 0, "CLOSED"), (cls.status_id == 1, "PENDING")],
            else_=None,
        ).label("status")

    @status.setter
    def status(self, status_name):
        self.status_id = DetainerWarrant.statuses[status_name] if status_name else None

    @property
    def plaintiff(self):
        return self._plaintiff

    @plaintiff.setter
    def plaintiff(self, plaintiff):
        p_id = plaintiff and plaintiff.get("id")
        if p_id:
            self._plaintiff = db.session.query(Plaintiff).get(p_id)
        else:
            self._plaintiff = plaintiff

    @property
    def plaintiff_attorney(self):
        return self._plaintiff_attorney

    @plaintiff_attorney.setter
    def plaintiff_attorney(self, attorney):
        a_id = attorney and attorney.get("id")
        if a_id:
            self._plaintiff_attorney = db.session.query(Attorney).get(a_id)
        else:
            self._plaintiff_attorney = attorney

    @property
    def defendants(self):
        return self._defendants

    @defendants.setter
    def defendants(self, defendants):
        if all(isinstance(d, Defendant) for d in defendants):
            self._defendants = defendants
        else:
            self._defendants = [
                db.session.query(Defendant).get(d.get("id")) for d in defendants
            ]


class UncategorizedCase(Case):
    __mapper_args__ = {"polymorphic_identity": "uncategorized_case"}


class CivilWarrant(Case):
    __mapper_args__ = {"polymorphic_identity": "civil_warrant"}


class DetainerWarrant(Case):
    __mapper_args__ = {"polymorphic_identity": "detainer_warrant"}

    recurring_court_dates = {
        "SUNDAY": 0,
        "MONDAY": 1,
        "TUESDAY": 2,
        "WEDNESDAY": 3,
        "THURSDAY": 4,
        "FRIDAY": 5,
        "SATURDAY": 6,
    }

    audit_statuses = {
        "CONFIRMED": 0,
        "ADDRESS_CONFIRMED": 1,
        "JUDGMENT_CONFIRMED": 2,
    }

    address = Column(db.String(255))
    address_certainty = Column(db.Float)
    court_date_recurring_id = Column(db.Integer)
    amount_claimed = Column(db.Numeric(scale=2))  # USD
    claims_possession = Column(db.Boolean)
    is_cares = Column(db.Boolean)
    is_legacy = Column(db.Boolean)
    nonpayment = Column(db.Boolean)
    notes = Column(db.Text)
    document_url = Column(
        db.String,
        db.ForeignKey(
            "pleading_documents.url", use_alter=True, name="cases_document_url_fkey"
        ),
    )
    _last_pleading_documents_check = Column(
        db.DateTime, name="last_pleading_documents_check"
    )
    pleading_document_check_was_successful = Column(db.Boolean)
    pleading_document_check_mismatched_html = Column(db.Text)
    last_edited_by_id = Column(db.Integer, db.ForeignKey("user.id"))
    audit_status_id = Column(db.Integer)

    document = relationship("PleadingDocument", foreign_keys=document_url)
    pleadings = relationship(
        "PleadingDocument",
        foreign_keys=PleadingDocument.docket_id,
        back_populates="detainer_warrant",
    )
    last_edited_by = relationship("User", back_populates="edited_warrants")
    judgments = relationship("Judgment", back_populates="detainer_warrant")

    potential_addresses = relationship(
        "Address",
        secondary=detainer_warrant_addresses,
        back_populates="potential_detainer_warrants",
        cascade="all, delete",
    )

    @hybrid_property
    def audit_status(self):
        status_by_id = {v: k for k, v in DetainerWarrant.audit_statuses.items()}
        return (
            status_by_id[self.audit_status_id]
            if self.audit_status_id is not None
            else None
        )

    @audit_status.setter
    def audit_status(self, name):
        self.audit_status_id = DetainerWarrant.audit_statuses[name] if name else None

    @audit_status.expression
    def audit_status(cls):
        return case(
            [
                (cls.audit_status_id == 0, "CONFIRMED"),
                (cls.audit_status_id == 1, "ADDRESS_CONFIRMED"),
                (cls.audit_status_id == 2, "JUDGMENT_CONFIRMED"),
            ],
            else_=None,
        ).label("audit_status")

    canvass_attempts = relationship(
        "CanvassEvent",
        secondary=canvass_warrants,
        back_populates="warrants",
        cascade="all, delete",
    )

    def __repr__(self):
        return f"<DetainerWarrant(docket_id='{self.docket_id}', file_date='{self._file_date}')>"

    @hybrid_property
    def court_date(self):
        if self._court_date:
            return in_millis(
                datetime.combine(self._court_date, datetime.min.time()).timestamp()
            )
        else:
            return None

    @court_date.comparator
    def court_date(cls):
        return PosixComparator(cls._court_date)

    @court_date.setter
    def court_date(self, posix):
        self._court_date = from_millis(posix) if posix else None

    @property
    def recurring_court_date(self):
        date_by_id = {v: k for k, v in DetainerWarrant.recurring_court_dates.items()}
        return (
            date_by_id[self.court_date_recurring_id]
            if self.court_date_recurring_id
            else None
        )

    @recurring_court_date.setter
    def recurring_court_date(self, day_of_week):
        self.court_date_recurring_id = (
            DetainerWarrant.recurring_court_dates[day_of_week] if day_of_week else None
        )

    @hybrid_property
    def last_pleading_documents_check(self):
        if self._last_pleading_documents_check:
            return in_millis(self._last_pleading_documents_check.timestamp())
        else:
            return None

    @last_pleading_documents_check.comparator
    def last_pleading_documents_check(cls):
        return PosixComparator(cls._last_pleading_documents_check)

    @last_pleading_documents_check.setter
    def last_pleading_documents_check(self, posix):
        if isinstance(posix, datetime):
            self._last_pleading_documents_check = posix
        else:
            self._last_pleading_documents_check = from_millis(posix)

    @property
    def courtroom(self):
        return self._courtroom

    @courtroom.setter
    def courtroom(self, courtroom):
        c_id = courtroom and courtroom.get("id")
        if c_id:
            self._courtroom = db.session.query(Courtroom).get(c_id)
        else:
            self._courtroom = courtroom


class PhoneNumberVerification(db.Model, Timestamped):
    caller_types = {
        "CONSUMER": 1,
        "BUSINESS": 2,
    }

    __tablename__ = "phone_number_verifications"
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

    defendants = relationship("Defendant", back_populates="verified_phone")

    def from_twilio_response(lookup):
        caller_info = lookup.caller_name or {
            "caller_name": None,
            "caller_type": None,
            "error_code": None,
        }
        carrier_info = lookup.carrier or {
            "error_code": None,
            "mobile_country_code": None,
            "mobile_network_code": None,
            "name": None,
            "type": None,
        }
        return PhoneNumberVerification(
            caller_name=caller_info["caller_name"],
            caller_type=caller_info["caller_type"],
            name_error_code=caller_info["error_code"],
            carrier_error_code=carrier_info["error_code"],
            mobile_country_code=carrier_info["mobile_country_code"],
            mobile_network_code=carrier_info["mobile_network_code"],
            carrier_name=carrier_info["name"],
            phone_type=carrier_info["type"],
            country_code=lookup.country_code,
            national_format=lookup.national_format,
            phone_number=lookup.phone_number,
        )

    @property
    def caller_type(self):
        caller_type_by_id = {
            v: k for k, v in PhoneNumberVerification.caller_types.items()
        }
        return caller_type_by_id.get(self.caller_type_id)

    @caller_type.setter
    def caller_type(self, caller_type):
        self.caller_type_id = PhoneNumberVerification.caller_types.get(caller_type)

    def __repr__(self):
        return f"<PhoneNumberVerification(caller_name='{self.caller_name}', phone_type='{self.phone_type}', phone_number='{self.phone_number}')>"
