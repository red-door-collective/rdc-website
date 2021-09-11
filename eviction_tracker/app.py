import flask
from flask import Flask, request, redirect
from flask_security import hash_password, auth_token_required
from eviction_tracker.extensions import cors, db, marshmallow, migrate, api, login_manager, security
from eviction_tracker.admin.models import User, user_datastore
import yaml
import os
import time

from sqlalchemy import and_, or_, func, desc
from eviction_tracker import commands, detainer_warrants, admin, direct_action
import json
from datetime import datetime, date, timedelta
from dateutil.rrule import rrule, MONTHLY
from collections import OrderedDict
import flask_wtf
from flask_security import current_user
from flask_apscheduler import APScheduler
from datadog import initialize, statsd
import logging.config
import eviction_tracker.config as config

logging.config.dictConfig(config.LOGGING)
logger = logging.getLogger(__name__)

options = {
    'statsd_host': '127.0.0.1',
    'statsd_port': 8125
}

Attorney = detainer_warrants.models.Attorney
DetainerWarrant = detainer_warrants.models.DetainerWarrant
Defendant = detainer_warrants.models.Defendant
Plaintiff = detainer_warrants.models.Plaintiff
Judgement = detainer_warrants.models.Judgement

security_config = dict(
    SECURITY_PASSWORD_SALT=os.environ['SECURITY_PASSWORD_SALT'],
    SECURITY_FLASH_MESSAGES=False,
    # Need to be able to route backend flask API calls. Use 'accounts'
    # to be the Flask-Security endpoints.
    SECURITY_URL_PREFIX='/api/v1/accounts',

    # These need to be defined to handle redirects
    # As defined in the API documentation - they will receive the relevant context
    SECURITY_POST_CONFIRM_VIEW="/confirmed",
    SECURITY_CONFIRM_ERROR_VIEW="/confirm-error",
    SECURITY_RESET_VIEW="/reset-password",
    SECURITY_RESET_ERROR_VIEW="/reset-password",
    SECURITY_REDIRECT_BEHAVIOR="spa",

    # CSRF protection is critical for all session-based browser UIs
    # enforce CSRF protection for session / browser - but allow token-based
    # API calls to go through
    SECURITY_CSRF_PROTECT_MECHANISMS=["session", "basic"],
    SECURITY_CSRF_IGNORE_UNAUTH_ENDPOINTS=True,
    SECURITY_CSRF_COOKIE={"key": "XSRF-TOKEN"},
    WTF_CSRF_CHECK_DEFAULT=False,
    WTF_CSRF_TIME_LIMIT=None
)


def create_app(testing=False):
    app = Flask(__name__.split('.')[0])
    app.config['SQLALCHEMY_DATABASE_URI'] = os.environ['SQLALCHEMY_DATABASE_URI']
    app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = os.environ['SQLALCHEMY_TRACK_MODIFICATIONS']
    app.config['SECRET_KEY'] = os.environ['SECRET_KEY']
    app.config['TWILIO_ACCOUNT_SID'] = os.environ['TWILIO_ACCOUNT_SID']
    app.config['TWILIO_AUTH_TOKEN'] = os.environ['TWILIO_AUTH_TOKEN']
    app.config['GOOGLE_ACCOUNT_PATH'] = os.environ['GOOGLE_ACCOUNT_PATH']
    app.config['ROLLBAR_CLIENT_TOKEN'] = os.environ['ROLLBAR_CLIENT_TOKEN']
    app.config['VERSION'] = os.environ['VERSION']
    app.config['SCHEDULER_API_ENABLED'] = True
    app.config['TESTING'] = testing
    app.config.update(**security_config)
    if app.config['ENV'] == 'production':
        initialize(**options)

    register_extensions(app)
    register_shellcontext(app)
    register_commands(app)

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
    return between_dates(start, end, db.session.query(Plaintiff, func.count(DetainerWarrant.plaintiff_id)))\
        .join(Plaintiff)\
        .group_by(DetainerWarrant.plaintiff_id, Plaintiff.id)\
        .order_by(desc(func.count('*')))\
        .limit(10)\
        .all()


def evictions_between_dates(start, end, plaintiff_id):
    return between_dates(start, end, db.session.query(Plaintiff))\
        .join(DetainerWarrant)\
        .filter_by(plaintiff_id=plaintiff_id)\
        .count()


def top_plaintiff_attorneys_bet(start, end):
    # TODO: perhaps figure this out in python
    return db.session.execute("""
    with top as 
        (select a.name, count(dw.docket_id) as warrantCount
    from attorneys a
    inner join detainer_warrants dw on dw.plaintiff_attorney_id = a.id
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


def top_plaintiff_ranges_bet(start, end):
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
    from plaintiffs p
    inner join detainer_warrants dw on dw.plaintiff_id = p.id
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


def amount_awarded_between(start, end):
    amount = db.session.query(func.sum(Judgement.awards_fees))\
        .filter(
            and_(
                Judgement.detainer_warrant_id.ilike('%\\G\\T%'),
                func.date(Judgement.court_date) >= start,
                func.date(Judgement.court_date) < end
            )
    ).scalar()
    if amount is None:
        return 0
    else:
        return amount


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
    api.init_app(app)
    login_manager.init_app(app)
    login_manager.login_view = None
    security.init_app(app, user_datastore)
    cors.init_app(app)
    flask_wtf.CSRFProtect(app)

    api.add_resource('/attorneys/', detainer_warrants.views.AttorneyListResource,
                     detainer_warrants.views.AttorneyResource, app=app)
    api.add_resource('/defendants/', detainer_warrants.views.DefendantListResource,
                     detainer_warrants.views.DefendantResource, app=app)
    api.add_resource('/courtrooms/', detainer_warrants.views.CourtroomListResource,
                     detainer_warrants.views.CourtroomResource, app=app)
    api.add_resource('/plaintiffs/', detainer_warrants.views.PlaintiffListResource,
                     detainer_warrants.views.PlaintiffResource, app=app)
    api.add_resource('/judgements/', detainer_warrants.views.JudgementListResource,
                     detainer_warrants.views.JudgementResource, app=app)
    api.add_resource('/judges/', detainer_warrants.views.JudgeListResource,
                     detainer_warrants.views.JudgeResource, app=app)
    api.add_resource('/detainer-warrants/', detainer_warrants.views.DetainerWarrantListResource,
                     detainer_warrants.views.DetainerWarrantResource, app=app)
    api.add_resource('/phone-number-verifications/', detainer_warrants.views.PhoneNumberVerificationListResource,
                     detainer_warrants.views.PhoneNumberVerificationResource, app=app)
    api.add_resource('/users/', admin.views.UserListResource,
                     admin.views.UserResource, app=app)
    api.add_resource('/roles/', admin.views.RoleListResource,
                     admin.views.RoleResource, app=app)
    api.add_resource('/campaigns/', direct_action.views.CampaignListResource,
                     direct_action.views.CampaignResource, app=app)
    api.add_resource('/events/', direct_action.views.EventListResource,
                     direct_action.views.EventResource, app=app)
    api.add_resource('/phone_bank_events/', direct_action.views.PhoneBankEventListResource,
                     direct_action.views.PhoneBankEventResource, app=app)

    @app.route('/api/v1/rollup/detainer-warrants')
    def detainer_warrant_rollup_by_month():
        start_dt = (date.today() - timedelta(weeks=52)).replace(day=1)
        end_dt = date.today()
        dates = [(dt, next_month(dt))
                 for dt in rrule(MONTHLY, dtstart=start_dt, until=end_dt)]
        counts = [{'time': millisTimestamp(start), 'total_warrants': count_between_dates(
            start, end)} for start, end in dates]

        return flask.jsonify(counts)

    @app.route('/api/v1/rollup/plaintiffs')
    def plaintiff_rollup_by_month():
        start_dt = (date.today() - timedelta(weeks=52)).replace(day=1)
        end_dt = date.today()
        dates = [(dt, next_month(dt))
                 for dt in rrule(MONTHLY, dtstart=start_dt, until=end_dt)]

        top_ten = top_evictions_between_dates(start_dt, end_dt)

        counts = {plaintiff.name: [] for plaintiff, eviction_court in top_ten}
        for (start, end) in dates:
            for plaintiff, plaintiff_total_evictions in top_ten:
                eviction_count = evictions_between_dates(
                    start, end, plaintiff.id)
                plaintiff_evictions = counts[plaintiff.name]
                stats = {'date': millisTimestamp(
                    start), 'eviction_count': eviction_count}
                counts[plaintiff.name] = plaintiff_evictions + [stats]

        top_evictors = [{'name': plaintiff, 'history': history}
                        for plaintiff, history in counts.items()]

        return flask.jsonify(top_evictors)

    @app.route('/api/v1/rollup/plaintiffs/amount_claimed_bands')
    def plaintiffs_by_amount_claimed():
        start_dt = (date.today() - timedelta(weeks=52)).replace(day=1)
        dates, end_dt = months_since(start_dt)

        top_six = top_plaintiff_ranges_bet(start_dt, end_dt)

        top_plaintiffs = [{
            'plaintiff_name': result[0],
            'warrant_count': round_dec(result[1]),
            'greater_than_2k': round_dec(result[2]),
            'between_1.5k_and_2k': round_dec(result[3]),
            'between_1k_and_1.5k': round_dec(result[4]),
            'between_500_and_1k': round_dec(result[5]),
            'less_than_500': round_dec(result[6]),
            'start_date': millis(start_dt),
            'end_date': millis(end_dt)
        } for result in top_six]

        return flask.jsonify(top_plaintiffs)

    @app.route('/api/v1/rollup/plaintiff-attorney')
    def plaintiff_attorney_warrant_share():
        start_dt = date(2020, 1, 1)
        dates, end_dt = months_since(start_dt)

        top_six = top_plaintiff_attorneys_bet(start_dt, end_dt)

        top_plaintiffs = [{
            'warrant_count': int(round(warrant_count)),
            'plaintiff_attorney_name': attorney_name,
            'start_date': millis(start_dt),
            'end_date': millis(end_dt)
        } for attorney_name, warrant_count in top_six]

        return flask.jsonify(top_plaintiffs)

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

    @app.route('/api/v1/rollup/amount-awarded')
    def amount_awarded():
        start_of_month = date.today().replace(day=1)
        end_of_month = (date.today().replace(day=1) +
                        timedelta(days=32)).replace(day=1)
        return flask.jsonify({'data': round_dec(amount_awarded_between(start_of_month, end_of_month))})

    @app.route('/api/v1/rollup/amount-awarded/history')
    def amount_awarded_history():
        start_dt = date(2021, 3, 1)
        end_dt = date.today()
        dates = [(dt, next_month(dt))
                 for dt in rrule(MONTHLY, dtstart=start_dt, until=end_dt)]
        awards = [{'time': millisTimestamp(start), 'total_amount': round_dec(amount_awarded_between(
            start, end))} for start, end in dates]
        return flask.jsonify({'data': awards})

    @app.route('/api/v1/rollup/meta')
    def data_meta():
        last_warrant = db.session.query(DetainerWarrant).order_by(
            desc(DetainerWarrant.updated_at)).first()
        return flask.jsonify({
            'last_detainer_warrant_update': millisTimestamp(last_warrant.updated_at) if last_warrant else None
        })

    @app.route('/api/v1/current_user')
    @auth_token_required
    def me():
        return admin.serializers.user_schema.dump(current_user)


def register_shellcontext(app):
    def shell_context():
        return {
            'user_datastore': user_datastore,
            'hash_password': hash_password
        }

    app.shell_context_processor(shell_context)


def register_commands(app):
    """Register Click commands."""
    app.cli.add_command(commands.test)
    app.cli.add_command(commands.sync)
    app.cli.add_command(commands.sync_judgements)
    app.cli.add_command(commands.scrape_sessions_site)
    app.cli.add_command(commands.scrape_sessions_week)
    app.cli.add_command(commands.export)
    app.cli.add_command(commands.export_courtroom_dockets)
    app.cli.add_command(commands.verify_phone)
    app.cli.add_command(commands.verify_phones)
    app.cli.add_command(commands.bootstrap)
