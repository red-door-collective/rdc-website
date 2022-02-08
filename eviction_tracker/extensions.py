from flask_sqlalchemy import SQLAlchemy, Model
from sqlalchemy.orm import relationship, backref
from flask_marshmallow import Marshmallow
from flask_migrate import Migrate
from flask_resty import Api
from flask_login import LoginManager
from flask_security import Security, SQLAlchemyUserDatastore, UserMixin, RoleMixin
from flask_security.models import fsqla_v2 as fsqla
from flask_apscheduler import APScheduler
from flask_cors import CORS
from flask_mail import Mail
from flask_wtf import CSRFProtect


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


db = SQLAlchemy(model_class=CRUDMixin, session_options={"autoflush": False})

# fsqla.FsModels.set_db_info(db)

login_manager = LoginManager()
marshmallow = Marshmallow()
migrate = Migrate(compare_type=True)
api = Api(prefix='/api/v1')
security = Security()
scheduler = APScheduler()
cors = CORS()
mail = Mail()
csrf = CSRFProtect()
