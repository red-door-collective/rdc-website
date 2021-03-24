from flask_sqlalchemy import SQLAlchemy, Model
from sqlalchemy.orm import relationship, backref
from flask_marshmallow import Marshmallow
from flask_migrate import Migrate
from flask_assets import Environment, Bundle
from flask_resty import Api
from flask_login import LoginManager
from flask_security import Security, SQLAlchemyUserDatastore, UserMixin, RoleMixin
from flask_security.models import fsqla_v2 as fsqla


class CRUDMixin(Model):
    """Mixin that adds convenience methods for CRUD (create, read, update, delete) operations."""

    @classmethod
    def create(cls, **kwargs):
        """Create a new record and save it the database."""
        instance = cls(**kwargs)
        return instance.save()

    def update(self, commit=True, **kwargs):
        """Update specific fields of a record."""
        for attr, value in kwargs.items():
            setattr(self, attr, value)
        return commit and self.save() or self

    def save(self, commit=True):
        """Save the record."""
        db.session.add(self)
        if commit:
            db.session.commit()
        return self

    def delete(self, commit=True):
        """Remove the record from the database."""
        db.session.delete(self)
        return commit and db.session.commit()


db = SQLAlchemy(model_class=CRUDMixin)
Column = db.Column


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

    # def name(self):
    # return self.first_name + ' ' + self.last_name

    def __repr__(self):
        return "<User(name='%s', email='%s'>" % (self.first_name, self.email)


# fsqla.FsModels.set_db_info(db)

assets = Environment()

js = Bundle('js/main.js', output='gen/packed.js')
assets.register('js_all', js)

login_manager = LoginManager()
marshmallow = Marshmallow()
migrate = Migrate(compare_type=True)
api = Api(prefix='/api/v1')
user_datastore = SQLAlchemyUserDatastore(db, User, Role)
security = Security()
