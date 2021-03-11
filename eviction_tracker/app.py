from flask import Flask, render_template
from eviction_tracker.extensions import assets, db, marshmallow, migrate, api
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
    register_shellcontext(app)
    register_commands(app)

    # logg.info("encoding: " + locale.getpreferredencoding())
    # logg.info("locale: "+ locale.getdefaultlocale())

    @app.route('/')
    def index():
        return render_template('index.html')

    return app


def register_extensions(app):
    """Register Flask extensions."""
    db.init_app(app)
    migrate.init_app(app, db)
    marshmallow.init_app(app)
    assets.init_app(app)
    api.init_app(app)

    api.add_resource('/attorneys/', detainer_warrants.views.AttorneyListResource, detainer_warrants.views.AttorneyResource, app=app)
    api.add_resource('/defendants/', detainer_warrants.views.DefendantListResource, detainer_warrants.views.DefendantResource, app=app)
    api.add_resource('/courtrooms/', detainer_warrants.views.CourtroomListResource, detainer_warrants.views.CourtroomResource, app=app)
    api.add_resource('/plantiffs/', detainer_warrants.views.PlantiffListResource, detainer_warrants.views.PlantiffResource, app=app)
    api.add_resource('/judges/', detainer_warrants.views.JudgeListResource, detainer_warrants.views.JudgeResource, app=app)
    api.add_resource('/detainer-warrants/', detainer_warrants.views.DetainerWarrantListResource, detainer_warrants.views.DetainerWarrantResource, app=app)
    api.add_resource('/phone-number-verifications/', detainer_warrants.views.PhoneNumberVerificationListResource, detainer_warrants.views.PhoneNumberVerificationResource, app=app)


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
