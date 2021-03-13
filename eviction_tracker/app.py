import flask
from flask import Flask, render_template
from eviction_tracker.extensions import assets, db, marshmallow, migrate, api
import yaml
import os
import logging
import time

from sqlalchemy import and_, func, desc
from eviction_tracker import commands, detainer_warrants
import json
import datetime
from dateutil.rrule import rrule, MONTHLY
from collections import OrderedDict

DetainerWarrant = detainer_warrants.models.DetainerWarrant
Plantiff = detainer_warrants.models.Plantiff

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

def between_dates(start, end, query):
    return query.filter(
            and_(
                func.date(DetainerWarrant.file_date) >= start,
                func.date(DetainerWarrant.file_date) <= end
            )
        )

def count_between_dates(start, end):
    return between_dates(start, end, db.session.query(DetainerWarrant)).count()

def next_month(dt):
    return datetime.datetime(dt.year + (1 if dt.month == 12 else 0), max(1, (dt.month + 1) % 13), 1)

def top_evictions_between_dates(start, end):
    return between_dates(start, end, db.session.query(Plantiff, func.count(DetainerWarrant.plantiff_id)))\
            .join(Plantiff)\
            .group_by(DetainerWarrant.plantiff_id, Plantiff.id)\
            .order_by(desc(func.count('*')))\
            .limit(10)\
            .all()

def evictions_between_dates(start, end, plantiff_id):
    return between_dates(start, end, db.session.query(Plantiff))\
        .filter_by(id=plantiff_id)\
        .join(DetainerWarrant)\
        .count()

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

    @app.route('/api/v1/rollup/detainer-warrants')
    def detainer_warrant_rollup_by_month():
        start_dt = datetime.date(2020, 1, 1)
        end_dt = datetime.date.today()
        dates = [ (dt, next_month(dt)) for dt in rrule(MONTHLY, dtstart=start_dt, until=end_dt) ]
        counts = [ (start.strftime("%Y %b"), count_between_dates(start, end)) for start, end in dates ]

        return app.response_class(
            response=json.dumps(OrderedDict(counts)),
            status=200,
            mimetype='application/json'
        )

    @app.route('/api/v1/rollup/plantiffs')
    def plantiff_rollup_by_month():
        start_dt = datetime.date(2020, 1, 1)
        end_dt = datetime.date.today()
        dates = [ (dt, next_month(dt))
            for dt in rrule(MONTHLY, dtstart=start_dt, until=end_dt) ]

        top_ten = top_evictions_between_dates(start_dt, end_dt)

        counts = { plantiff.name: [] for plantiff, eviction_court in top_ten }
        for (start, end) in dates:
            for plantiff, plantiff_total_evictions in top_ten:
                eviction_count = evictions_between_dates(start, end, plantiff.id)
                plantiff_evictions = counts[plantiff.name]
                stats = { 'date': start.timestamp() * 1000, 'eviction_count': eviction_count }
                counts[plantiff.name] = plantiff_evictions + [ stats ]

        top_evictors = [ { 'name': plantiff, 'history': history } for plantiff, history in counts.items() ]

        return app.response_class(
            response=json.dumps(top_evictors),
            status=200,
            mimetype='application/json'
        )


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
