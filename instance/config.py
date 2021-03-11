import os

basedir = os.path.abspath(os.path.dirname(__file__))

# Your App secret key
SECRET_KEY = os.environ.get('EVICTION_TRACKER_SECRET_KEY', 'secret')

# The SQLAlchemy connection string.
# SQLALCHEMY_DATABASE_URI = "sqlite:///" + os.path.join(basedir, "app.db")
SQLALCHEMY_DATABASE_URI = 'postgresql://gziegan:dev@localhost/eviction-tracker'

SQLALCHEMY_TRACK_MODIFICATIONS = False

# ---------------------------------------------------
# Babel config for translations
# ---------------------------------------------------
# Setup default language
BABEL_DEFAULT_LOCALE = "en"
# Your application default translation path
BABEL_DEFAULT_FOLDER = "translations"
# The allowed translation for your app
LANGUAGES = {
    "en": {"flag": "gb", "name": "English"},
}
