from app.models import db, DetainerWarrant
from app import app

app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:////tmp/test.db'

db.drop_all()
db.create_all()