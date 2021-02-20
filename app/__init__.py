import logging

from flask import Flask, render_template
from flask_sqlalchemy import SQLAlchemy
from flask_marshmallow import Marshmallow
from flask_restful import Api, Resource
from flask_assets import Environment, Bundle

"""
 Logging configuration
"""

logging.basicConfig(format="%(asctime)s:%(levelname)s:%(name)s:%(message)s")
logging.getLogger().setLevel(logging.DEBUG)

app = Flask(__name__)
app.config.from_object("config")
assets = Environment(app)

js = Bundle('js/main.js', output='gen/packed.js')
assets.register('js_all', js)

db = SQLAlchemy(app)
ma = Marshmallow(app)
api = Api(app)

@app.route('/')
def index():
    return render_template('index.html')

from . import models, resources, spreadsheets
