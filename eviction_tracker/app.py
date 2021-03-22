import flask
from flask import Flask, render_template, request
from eviction_tracker.extensions import assets, db, marshmallow, migrate, api
import yaml
import os
import logging
import time

from sqlalchemy import and_, or_, func, desc
from eviction_tracker import commands, detainer_warrants
import json
from datetime import datetime, date, timedelta
from dateutil.rrule import rrule, MONTHLY
from collections import OrderedDict

Attorney = detainer_warrants.models.Attorney
DetainerWarrant = detainer_warrants.models.DetainerWarrant
Defendant = detainer_warrants.models.Defendant
Plantiff = detainer_warrants.models.Plantiff
Organizer = detainer_warrants.models.Organizer

logg = logging.getLogger(__name__)


def is_authenticated(form_data):
    defendant = db.session.query(Defendant)\
        .filter_by(name=form_data['name'], phone=form_data['phone'])\
        .first()

    valid_contact = db.session.query(Organizer)\
        .filter(or_(
            Organizer.first_name == form_data['rdc_contact'],
            Organizer.last_name == form_data['rdc_contact']
        ))\
        .first()

    return bool(defendant) and bool(valid_contact)


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

    @app.route('/', defaults={'path': ''})
    @app.route('/<path:path>')
    def index(path):
        return render_template('index.html')

    return app


def between_dates(start, end, query):
    return query.filter(
        and_(
            func.date(DetainerWarrant.file_date) >= start,
            func.date(DetainerWarrant.file_date) <= end
        )
    )


def months_since(start):
    end = date.today()
    dates = [(dt, next_month(dt))
             for dt in rrule(MONTHLY, dtstart=start, until=end)]
    return dates, end


def count_between_dates(start, end):
    return between_dates(start, end, db.session.query(DetainerWarrant)).count()


def next_month(dt):
    return datetime(dt.year + (1 if dt.month == 12 else 0), max(1, (dt.month + 1) % 13), 1)


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


def top_plantiff_attorneys_bet(start, end):
    # TODO: perhaps figure this out in python
    return db.session.execute("""
    with top as 
        (select a.name, count(dw.docket_id) as warrantCount
    from attorneys a
    inner join plantiffs p on p.attorney_id = a.id
    inner join detainer_warrants dw on dw.plantiff_id = p.id
    group by a.id, a.name
    order by count(dw.docket_id) desc)
    select *
    from top
    union 
    (select 'ALL OTHER' as name,
        sum(top.warrantCount) as warrantCount
    from top
    where top.name not in 
        (select top.name
        from top
        limit 5))
    order by warrantCount desc
    limit 6;
    """)


def top_judges_bet(start, end):
    # TODO: perhaps figure this out in python
    return db.session.execute("""
    with top as 
        (select j.name, count(dw.docket_id) as warrantCount
    from judges j
    inner join detainer_warrants dw on dw.presiding_judge_id = j.id
    group by j.id, j.name
    order by count(dw.docket_id) desc)
    select *
    from top
    union 
    (select 'ALL OTHER' as name,
        sum(top.warrantCount) as warrantCount
    from top
    where top.name not in 
        (select top.name
        from top
        limit 5))
    order by warrantCount desc
    limit 6;
    """)


def top_plantiff_ranges_bet(start, end):
    # TODO: perhaps figure this out in python
    return db.session.execute("""
    with top as 
        (select p.name, 
         count(dw.docket_id) as warrant_count,
         sum(CASE WHEN dw.amount_claimed > 2000 THEN 1 ELSE 0 END) as high,
         sum(case when dw.amount_claimed > 1500 and dw.amount_claimed <= 2000 then 1 else 0 end) as medium_high,
         sum(case when dw.amount_claimed > 1000 and dw.amount_claimed <= 1500 then 1 else 0 end) as medium,
         sum(case when dw.amount_claimed > 500 and dw.amount_claimed <= 1000 then 1 else 0 end) as medium_low,
         sum(CASE WHEN dw.amount_claimed < 500 THEN 1 ELSE 0 END) as low
    from plantiffs p
    inner join detainer_warrants dw on dw.plantiff_id = p.id
    group by p.id, p.name
    order by warrant_count desc)
    select *
    from top
    union 
    (select 'ALL OTHER' as name,
        sum(top.warrant_count) as warrant_count,
        sum(top.high),
        sum(top.medium_high),
        sum(top.medium),
        sum(top.medium_low),
        sum(top.low)
    from top
    where top.name not in 
        (select top.name
        from top
        limit 5))
    order by warrant_count desc
    limit 6;
    """)


def pending_scheduled_case_count(start, end):
    return db.session.query(DetainerWarrant)\
        .filter(
            and_(
                func.date(DetainerWarrant.court_date) >= start,
                func.date(DetainerWarrant.court_date) < end,
                DetainerWarrant.status_id == DetainerWarrant.statuses['PENDING']
            )
    )\
        .count()


def round_dec(dec):
    return int(round(dec))


def millisTimestamp(dt):
    return round(dt.timestamp() * 1000)


def millis(d):
    return millisTimestamp(datetime.combine(d, datetime.min.time()))


def register_extensions(app):
    """Register Flask extensions."""
    db.init_app(app)
    migrate.init_app(app, db)
    marshmallow.init_app(app)
    assets.init_app(app)
    api.init_app(app)

    api.add_resource('/attorneys/', detainer_warrants.views.AttorneyListResource,
                     detainer_warrants.views.AttorneyResource, app=app)
    api.add_resource('/defendants/', detainer_warrants.views.DefendantListResource,
                     detainer_warrants.views.DefendantResource, app=app)
    api.add_resource('/courtrooms/', detainer_warrants.views.CourtroomListResource,
                     detainer_warrants.views.CourtroomResource, app=app)
    api.add_resource('/plantiffs/', detainer_warrants.views.PlantiffListResource,
                     detainer_warrants.views.PlantiffResource, app=app)
    api.add_resource('/judges/', detainer_warrants.views.JudgeListResource,
                     detainer_warrants.views.JudgeResource, app=app)
    api.add_resource('/detainer-warrants/', detainer_warrants.views.DetainerWarrantListResource,
                     detainer_warrants.views.DetainerWarrantResource, app=app)
    api.add_resource('/phone-number-verifications/', detainer_warrants.views.PhoneNumberVerificationListResource,
                     detainer_warrants.views.PhoneNumberVerificationResource, app=app)

    @app.route('/api/v1/auth', methods=['POST'])
    def auth():
        return flask.jsonify({'is_authenticated': is_authenticated(request.get_json())})

    @app.route('/api/v1/rollup/detainer-warrants')
    def detainer_warrant_rollup_by_month():
        start_dt = date(2020, 1, 1)
        end_dt = date.today()
        dates = [(dt, next_month(dt))
                 for dt in rrule(MONTHLY, dtstart=start_dt, until=end_dt)]
        counts = [{'time': millisTimestamp(start), 'totalWarrants': count_between_dates(
            start, end)} for start, end in dates]

        return flask.jsonify(counts)

    @app.route('/api/v1/rollup/plantiffs')
    def plantiff_rollup_by_month():
        start_dt = date(2020, 1, 1)
        end_dt = date.today()
        dates = [(dt, next_month(dt))
                 for dt in rrule(MONTHLY, dtstart=start_dt, until=end_dt)]

        top_ten = top_evictions_between_dates(start_dt, end_dt)

        counts = {plantiff.name: [] for plantiff, eviction_court in top_ten}
        for (start, end) in dates:
            for plantiff, plantiff_total_evictions in top_ten:
                eviction_count = evictions_between_dates(
                    start, end, plantiff.id)
                plantiff_evictions = counts[plantiff.name]
                stats = {'date': millisTimestamp(
                    start), 'eviction_count': eviction_count}
                counts[plantiff.name] = plantiff_evictions + [stats]

        top_evictors = [{'name': plantiff, 'history': history}
                        for plantiff, history in counts.items()]

        return flask.jsonify(top_evictors)

    @app.route('/api/v1/rollup/plantiffs/amount_claimed_bands')
    def plantiffs_by_amount_claimed():
        start_dt = date(2020, 1, 1)
        dates, end_dt = months_since(start_dt)

        top_six = top_plantiff_ranges_bet(start_dt, end_dt)

        top_plantiffs = [{
            'plantiff_name': result[0],
            'warrant_count': round_dec(result[1]),
            'greater_than_2k': round_dec(result[2]),
            'between_1.5k_and_2k': round_dec(result[3]),
            'between_1k_and_1.5k': round_dec(result[4]),
            'between_500_and_1k': round_dec(result[5]),
            'less_than_500': round_dec(result[6]),
            'start_date': millis(start_dt),
            'end_date': millis(end_dt)
        } for result in top_six]

        return flask.jsonify(top_plantiffs)

    @app.route('/api/v1/rollup/plantiff-attorney')
    def plantiff_attorney_warrant_share():
        start_dt = date(2020, 1, 1)
        dates, end_dt = months_since(start_dt)

        top_six = top_plantiff_attorneys_bet(start_dt, end_dt)

        top_plantiffs = [{
            'warrant_count': int(round(warrant_count)),
            'plantiff_attorney_name': attorney_name,
            'start_date': millis(start_dt),
            'end_date': millis(end_dt)
        } for attorney_name, warrant_count in top_six]

        return flask.jsonify(top_plantiffs)

    @app.route('/api/v1/rollup/judges')
    def judge_warrant_share():
        start_dt = date(2020, 1, 1)
        dates, end_dt = months_since(start_dt)

        top_six = top_judges_bet(start_dt, end_dt)

        top_judges = [{
            'warrant_count': int(round(warrant_count)),
            'presiding_judge_name': judge_name,
            'start_date': millis(start_dt),
            'end_date': millis(end_dt)
        } for judge_name, warrant_count in top_six]

        return flask.jsonify(top_judges)

    @app.route('/api/v1/rollup/detainer-warrants/pending')
    def pending_detainer_warrants():
        start_of_month = date.today().replace(day=1)
        end_of_month = (date.today().replace(day=1) +
                        timedelta(days=32)).replace(day=1)

        return flask.jsonify({'pending_scheduled_case_count': pending_scheduled_case_count(start_of_month, end_of_month)})

    @app.route('/api/v1/rollup/meta')
    def data_meta():
        last_warrant = db.session.query(DetainerWarrant).order_by(
            desc(DetainerWarrant.updated_at)).first()
        return flask.jsonify({
            'last_detainer_warrant_update': millisTimestamp(last_warrant.updated_at) if last_warrant else None
        })


def register_shellcontext(app):
    def shell_context():
        return {
            'db': db,
            'DetainerWarrant': detainer_warrants.models.DetainerWarrant,
            'Attorney': detainer_warrants.models.Attorney,
            'Defendant': detainer_warrants.models.Defendant,
            'Organizer': Organizer
        }

    app.shell_context_processor(shell_context)


def register_commands(app):
    """Register Click commands."""
    app.cli.add_command(commands.test)
    app.cli.add_command(commands.sync)
