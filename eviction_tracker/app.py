from flask import Flask, render_template
from eviction_tracker.extensions import assets, db, marshmallow, migrate
import yaml
import os
import logging

from eviction_tracker import commands, detainer_warrants

logg = logging.getLogger(__name__)

def create_app(testing=False):
    app = Flask(__name__.split('.')[0])
    app.config['SQLALCHEMY_DATABASE_URI'] = os.environ['SQLALCHEMY_DATABASE_URI']
    app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = os.environ['SQLALCHEMY_TRACK_MODIFICATIONS']
    app.config['SECRET_KEY'] = os.environ['SECRET_KEY']

    register_extensions(app)
    register_blueprints(app)
    register_shellcontext(app)
    register_commands(app)

    # logg.info("encoding: " + locale.getpreferredencoding())
    # logg.info("locale: "+ locale.getdefaultlocale())

    @app.route('/')
    def index():
        return render_template('index.html')

    return app


def register_blueprints(app):
    app.register_blueprint(
        detainer_warrants.views.blueprint, url_prefix='/api/v1/')


def register_extensions(app):
    """Register Flask extensions."""
    db.init_app(app)
    migrate.init_app(app, db)
    marshmallow.init_app(app)
    assets.init_app(app)


def register_shellcontext(app):
    def shell_context():
        return {
            'db': db,
            'DetainerWarrant': detainer_warrants.models.DetainerWarrant,
            'Attorney': detainer_warrants.models.Attorney,
            'Defendant': detainer_warrants.models.Defendant
        }

    app.shell_context_processor(shell_context)


def register_commands(app):
    """Register Click commands."""
    app.cli.add_command(commands.test)
    app.cli.add_command(commands.sync)
