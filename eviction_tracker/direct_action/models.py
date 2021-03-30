from eviction_tracker.database import db, Timestamped, Column, Model, relationship
from datetime import datetime
from sqlalchemy import func

events_users = db.Table(
    'events_users',
    db.metadata,
    Column('event_id', db.ForeignKey(
        'events.id'), primary_key=True),
    Column('user_id', db.ForeignKey('user.id'), primary_key=True)
)


class Event(db.Model, Timestamped):
    __tablename__ = 'events'

    id = Column(db.Integer, primary_key=True)
    name = Column(db.String(50))
    type = Column(db.String(50))

    campaign_id = Column(db.Integer, db.ForeignKey('campaigns.id'))

    campaign = relationship('Campaign', back_populates='events')

    attendees = relationship(
        'User', secondary=events_users, back_populates='attended_events')

    __mapper_args__ = {
        'polymorphic_identity': 'event',
        'polymorphic_on': type
    }

    def __repr__(self):
        return f"<Event id='{self.id}' name='{self.name}' type='{self.type}'>"


phone_bank_tenants = db.Table(
    'phone_bank_tenants',
    db.metadata,
    Column('phone_bank_event_id', db.ForeignKey(
        'phone_bank_events.id'), primary_key=True),
    Column('defendant_id', db.ForeignKey(
        'defendants.id'), primary_key=True)
)


class PhoneBankEvent(Event):
    __tablename__ = 'phone_bank_events'

    id = Column(db.ForeignKey('events.id'), primary_key=True)

    tenants = relationship(
        'Defendant', secondary=phone_bank_tenants, back_populates='phone_bank_attempts')

    __mapper_args__ = {"polymorphic_identity": "phone_bank_event"}

    def __repr__(self):
        return f"<PhoneBankEvent name='{self.name}'>"


class Campaign(db.Model, Timestamped):
    __tablename__ = 'campaigns'

    id = Column(db.Integer, primary_key=True)
    name = Column(db.String(50))

    events = relationship('Event', back_populates='campaign')

    def __repr__(self):
        return f"<Campaign name='{self.name}'>"
