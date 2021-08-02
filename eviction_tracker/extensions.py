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

# fsqla.FsModels.set_db_info(db)

assets = Environment()

js = Bundle('js/main.js', output='gen/packed.js')
assets.register('js_all', js)

login_manager = LoginManager()
marshmallow = Marshmallow()
migrate = Migrate(compare_type=True)
api = Api(prefix='/api/v1')
security = Security()
