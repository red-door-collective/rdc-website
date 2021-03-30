from eviction_tracker.database import db, Column, Model, relationship
from datetime import datetime
from sqlalchemy import func
from eviction_tracker.direct_action.models import events_users
from flask_security import Security, SQLAlchemyUserDatastore, UserMixin, RoleMixin

roles_users = db.Table(
    'roles_users', db.metadata,
    db.Column('user_id',
              db.ForeignKey('user.id'), primary_key=True),
    db.Column('role_id', db.ForeignKey('role.id'), primary_key=True))


class Role(db.Model, RoleMixin):
    __tablename__ = 'role'
    id = Column(db.Integer(), primary_key=True)
    name = Column(db.String(80), unique=True)
    description = Column(db.String(255))
    users = relationship('User', secondary=roles_users, back_populates='roles')

    def __repr__(self):
        return f"<Role(name='{self.name}')>"


class User(db.Model, UserMixin):
    __tablename__ = 'user'
    id = Column(db.Integer, primary_key=True)
    email = Column(db.String(255), unique=True)
    first_name = Column(db.String(255), nullable=False)
    last_name = Column(db.String(255), nullable=False)
    password = Column(db.String(255), nullable=False)
    last_login_at = Column(db.DateTime())
    current_login_at = Column(db.DateTime())
    last_login_ip = Column(db.String(100))
    current_login_ip = Column(db.String(100))
    login_count = Column(db.Integer)
    active = Column(db.Boolean())
    fs_uniquifier = Column(db.String(255), unique=True, nullable=False)
    confirmed_at = Column(db.DateTime())
    roles = relationship('Role',
                         secondary=roles_users,
                         back_populates='users'
                         )
    attended_events = relationship(
        'Event', secondary=events_users, back_populates='attendees')

    @property
    def name(self):
        return self.first_name + ' ' + self.last_name

    def __repr__(self):
        return f"<User(name='{self.name}', email='{self.email}')>"


user_datastore = SQLAlchemyUserDatastore(db, User, Role)
