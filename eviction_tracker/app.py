import flask
from flask import g, send_file, jsonify, Flask, request, redirect, current_app
from flask_security import hash_password, auth_token_required, send_mail
from flask_security.confirmable import generate_confirmation_link
from flask_security.utils import config_value
from eviction_tracker.extensions import cors, db, mail, marshmallow, csrf, migrate, api, login_manager, security
from eviction_tracker.admin.models import User, user_datastore
import os
import time
import calendar
from threading import Thread

from sqlalchemy import and_, or_, func, desc
from sqlalchemy.sql import text
from eviction_tracker import commands, detainer_warrants, admin, direct_action
import json
from datetime import datetime, date, timedelta
from dateutil.rrule import rrule, MONTHLY
from dateutil.relativedelta import relativedelta
from collections import OrderedDict
from flask_security import current_user
from flask_apscheduler import APScheduler
from datadog import initialize, statsd
import logging.config
import eviction_tracker.config as config
from flask_log_request_id import RequestID, current_request_id
import eviction_tracker.tasks as tasks
from .time_util import millis, millis_timestamp

logging.config.dictConfig(config.LOGGING)
logger = logging.getLogger(__name__)

options = {
    'statsd_host': '127.0.0.1',
    'statsd_port': 8125
}

Attorney = detainer_warrants.models.Attorney
DetainerWarrant = detainer_warrants.models.DetainerWarrant
Defendant = detainer_warrants.models.Defendant
Hearing = detainer_warrants.models.Hearing
Plaintiff = detainer_warrants.models.Plaintiff
Judgment = detainer_warrants.models.Judgment

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

    # Features
    SECURITY_RECOVERABLE=True,
    SECURITY_TRACKABLE=True,
    SECURITY_CHANGEABLE=True,
    SECURITY_CONFIRMABLE=True,

    SECURITY_AUTO_LOGIN_AFTER_CONFIRM=False,

    # CSRF protection is critical for all session-based browser UIs
    # enforce CSRF protection for session / browser - but allow token-based
    # API calls to go through
    SECURITY_CSRF_PROTECT_MECHANISMS=["session", "basic"],
    SECURITY_CSRF_IGNORE_UNAUTH_ENDPOINTS=True,
    SECURITY_CSRF_COOKIE={"key": "XSRF-TOKEN"},
    WTF_CSRF_CHECK_DEFAULT=False,
    WTF_CSRF_TIME_LIMIT=None,
    SECURITY_REDIRECT_HOST=os.environ['SECURITY_REDIRECT_HOST']
)


def env_var_bool(key, default=None):
    return os.getenv(key, default if default else 'False').lower() in ('true', '1', 't')


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
    app.config['SCHEDULER_API_ENABLED'] = env_var_bool('SCHEDULER_API_ENABLED')
    app.config['SCHEDULER_TIMEZONE'] = os.environ.get(
        'SCHEDULER_TIMEZONE', 'UTC')
    app.config['CASELINK_USERNAME'] = os.environ['CASELINK_USERNAME']
    app.config['CASELINK_PASSWORD'] = os.environ['CASELINK_PASSWORD']
    app.config['TESTING'] = testing
    app.config['LOGIN_WAIT'] = float(os.environ['LOGIN_WAIT'])
    app.config['SEARCH_WAIT'] = float(os.environ['SEARCH_WAIT'])
    app.config['SQLALCHEMY_ECHO'] = env_var_bool('SQLALCHEMY_ECHO')
    app.config['CHROMEDRIVER_HEADLESS'] = env_var_bool(
        'CHROMEDRIVER_HEADLESS', default='True')
    app.config['DATA_DIR'] = os.environ['DATA_DIR']
    app.config['MAIL_SERVER'] = os.environ['MAIL_SERVER']
    app.config['MAIL_PORT'] = os.environ['MAIL_PORT']
    app.config['MAIL_USE_TLS'] = False
    app.config['MAIL_USE_SSL'] = True
    app.config['MAIL_USERNAME'] = os.environ['MAIL_USERNAME']
    app.config['MAIL_PASSWORD'] = os.environ['MAIL_PASSWORD']
    app.config['MAIL_ADMIN'] = os.environ['MAIL_ADMIN']
    app.config.update(**security_config)
    if app.config['ENV'] == 'production':
        initialize(**options)

    register_extensions(app)
    RequestID(app)
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
    return between_dates(start, end, db.session.query(Plaintiff.id, Plaintiff.name, func.count(DetainerWarrant.plaintiff_id)))\
        .join(Plaintiff)\
        .group_by(DetainerWarrant.plaintiff_id, Plaintiff.id)\
        .order_by(desc(func.count('*')))\
        .limit(10)\
        .all()


def top_evictions_between_dates(start, end):
    return between_dates(start, end, db.session.query(Plaintiff, func.count(DetainerWarrant.plaintiff_id)))\
        .join(Plaintiff)\
        .group_by(DetainerWarrant.plaintiff_id, Plaintiff.id)\
        .order_by(desc(func.count('*')))\
        .limit(10)\
        .all()


def evictions_by_month(plaintiff_id, months):
    return db.session.execute(text("""
    select
        count(cases.docket_id) filter (where date(cases.file_date)  >= :d_1_start AND date(cases.file_date) <= :d_1_end) as ":1",
        count(cases.docket_id) filter (where date(cases.file_date)  >= :d_2_start AND date(cases.file_date) <= :d_2_end) as ":2",
        count(cases.docket_id) filter (where date(cases.file_date)  >= :d_3_start AND date(cases.file_date) <= :d_3_end) as ":3",
        count(cases.docket_id) filter (where date(cases.file_date)  >= :d_4_start AND date(cases.file_date) <= :d_4_end) as ":4",
        count(cases.docket_id) filter (where date(cases.file_date)  >= :d_5_start AND date(cases.file_date) <= :d_5_end) as ":5",
        count(cases.docket_id) filter (where date(cases.file_date)  >= :d_6_start AND date(cases.file_date) <= :d_6_end) as ":6",
        count(cases.docket_id) filter (where date(cases.file_date)  >= :d_7_start AND date(cases.file_date) <= :d_7_end) as ":7",
        count(cases.docket_id) filter (where date(cases.file_date)  >= :d_8_start AND date(cases.file_date) <= :d_8_end) as ":8",
        count(cases.docket_id) filter (where date(cases.file_date)  >= :d_9_start AND date(cases.file_date) <= :d_9_end) as ":9",
        count(cases.docket_id) filter (where date(cases.file_date)  >= :d_10_start AND date(cases.file_date) <= :d_10_end) as ":10",
        count(cases.docket_id) filter (where date(cases.file_date)  >= :d_11_start AND date(cases.file_date) <= :d_11_end) as ":11",
        count(cases.docket_id) filter (where date(cases.file_date)  >= :d_12_start AND date(cases.file_date) <= :d_12_end) as ":12"
    FROM plaintiffs p JOIN cases ON p.id = cases.plaintiff_id AND cases.type = 'detainer_warrant'
    WHERE cases.plaintiff_id = :plaintiff_id
    """), {"plaintiff_id": plaintiff_id, **months})


def top_plaintiff_attorneys_bet(start, end):
    # TODO: perhaps figure this out in python
    return db.session.execute("""
    with top as
        (select a.name, count(dw.docket_id) as warrantCount
    from attorneys a
    inner join cases dw on dw.plaintiff_attorney_id = a.id
    where a.id <> -1 and dw.type = 'detainer_warrant'
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
        (select j.name, count(jm.detainer_warrant_id) as warrantCount
    from judges j
    inner join judgments jm on jm.judge_id = j.id
    group by j.id, j.name
    order by count(jm.detainer_warrant_id) desc)
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
    inner join cases dw on dw.plaintiff_id = p.id
    where dw.type = 'detainer_warrant'
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
        .join(Hearing)\
        .filter(
            and_(
                func.date(Hearing.court_date) >= start,
                func.date(Hearing.court_date) < end,
                DetainerWarrant.status_id == DetainerWarrant.statuses['PENDING']
            )
    )\
        .count()


def amount_awarded_between(start, end):
    amount = db.session.query(func.sum(Judgment.awards_fees))\
        .join(Hearing)\
        .filter(
            and_(
                func.date(Hearing.court_date) >= start,
                func.date(Hearing.court_date) < end
            )
    ).scalar()
    if amount is None:
        return 0
    else:
        return amount


def round_dec(dec):
    return int(round(dec))


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
    csrf.init_app(app)
    mail.init_app(app)

    api.add_resource('/attorneys/', detainer_warrants.views.AttorneyListResource,
                     detainer_warrants.views.AttorneyResource, app=app)
    api.add_resource('/defendants/', detainer_warrants.views.DefendantListResource,
                     detainer_warrants.views.DefendantResource, app=app)
    api.add_resource('/courtrooms/', detainer_warrants.views.CourtroomListResource,
                     detainer_warrants.views.CourtroomResource, app=app)
    api.add_resource('/hearings/', detainer_warrants.views.HearingListResource,
                     detainer_warrants.views.HearingResource, app=app)
    api.add_resource('/plaintiffs/', detainer_warrants.views.PlaintiffListResource,
                     detainer_warrants.views.PlaintiffResource, app=app)
    api.add_resource('/judgments/', detainer_warrants.views.JudgmentListResource,
                     detainer_warrants.views.JudgmentResource, app=app)
    api.add_resource('/judges/', detainer_warrants.views.JudgeListResource,
                     detainer_warrants.views.JudgeResource, app=app)
    api.add_resource('/detainer-warrants/', detainer_warrants.views.DetainerWarrantListResource,
                     detainer_warrants.views.DetainerWarrantResource, app=app)
    api.add_resource('/pleading-documents/', detainer_warrants.views.PleadingDocumentListResource,
                     detainer_warrants.views.PleadingDocumentResource, app=app)
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

    @app.before_request
    def log_request_info():
        g.start = time.time()

    @app.after_request
    def log_response_info(response):
        now = time.time()
        duration = round(now - g.start, 6)
        dt = datetime.fromtimestamp(now)
        timestamp = dt.isoformat()

        args = dict(request.args)
        log_params = dict(
            method=request.method,
            status=response.status_code,
            duration=duration,
            time=timestamp,
            params=args
        )

        if 'login' not in request.path:
            log_params['request_headers'] = {
                k: v for k, v in request.headers.items()}
            log_params['response_headers'] = {
                k: v for k, v in response.headers.items()}

        logger.info(request.path, extra=log_params)

        return response

    @app.route('/api/v1/rollup/detainer-warrants')
    def detainer_warrant_rollup_by_month():
        start_dt = (date.today() - relativedelta(years=1)).replace(day=1)
        end_dt = date.today()
        dates = [(dt, next_month(dt))
                 for dt in rrule(MONTHLY, dtstart=start_dt, until=end_dt)]
        counts = [{'time': millis_timestamp(start), 'total_warrants': count_between_dates(
            start, end)} for start, end in dates]

        return jsonify(counts)

    @app.route('/api/v1/rollup/plaintiffs')
    def plaintiff_rollup_by_month():
        start_dt = (date.today() - timedelta(days=365)).replace(day=1)
        end_dt = date.today()
        dates = [(dt, next_month(dt))
                 for dt in rrule(MONTHLY, dtstart=start_dt, until=end_dt)]
        months = {}
        for i, d_range in enumerate(dates):
            start, end = d_range
            months[str(i)] = str(i)
            months[f'd_{i}_start'] = start.strftime('%Y-%m-%d')
            months[f'd_{i}_end'] = end.strftime('%Y-%m-%d')

        top_ten = top_evictions_between_dates(start_dt, end_dt)

        plaintiffs = {}
        top_evictors = []
        for plaintiff, plaintiff_total_evictions in top_ten:
            counts = evictions_by_month(plaintiff.id, months).fetchone()
            history = []
            for i in range(12):
                history.append({'date': millis_timestamp(
                    dates[i][0]), 'eviction_count': counts[i]
                })
            top_evictors.append({'name': plaintiff.name, 'history': history})

        return jsonify(top_evictors)

    @app.route('/api/v1/rollup/plaintiffs/amount_claimed_bands')
    def plaintiffs_by_amount_claimed():
        start_dt = (date.today() - relativedelta(years=1)).replace(day=1)
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

        return jsonify(top_plaintiffs)

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

        prs = {
            'warrant_count': between_dates(start_dt, end_dt, Attorney.query.filter_by(id=-1).join(DetainerWarrant)).count(),
            'plaintiff_attorney_name': Attorney.query.get(-1).name,
            'start_date': millis(start_dt),
            'end_date': millis(end_dt),
        }

        return jsonify(top_plaintiffs + [prs])

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

        return jsonify(top_judges)

    @app.route('/api/v1/rollup/detainer-warrants/pending')
    def pending_detainer_warrants():
        start_of_month = date.today().replace(day=1)
        end_of_month = (date.today().replace(day=1) +
                        timedelta(days=32)).replace(day=1)

        return jsonify({'pending_scheduled_case_count': pending_scheduled_case_count(start_of_month, end_of_month)})

    @app.route('/api/v1/rollup/amount-awarded')
    def amount_awarded():
        start_of_month = date.today().replace(day=1)
        end_of_month = (date.today().replace(day=1) +
                        timedelta(days=32)).replace(day=1)
        return jsonify({'data': round_dec(amount_awarded_between(start_of_month, end_of_month))})

    @app.route('/api/v1/rollup/amount-awarded/history')
    def amount_awarded_history():
        start_dt = date(2021, 3, 1)
        end_dt = date.today()
        dates = [(dt, next_month(dt))
                 for dt in rrule(MONTHLY, dtstart=start_dt, until=end_dt)]
        awards = [{'time': millis_timestamp(start), 'total_amount': round_dec(amount_awarded_between(
            start, end))} for start, end in dates]
        return jsonify({'data': awards})

    @app.route('/api/v1/rollup/meta')
    def data_meta():
        last_warrant = db.session.query(DetainerWarrant).order_by(
            desc(DetainerWarrant.updated_at)).first()
        return jsonify({
            'last_detainer_warrant_update': last_warrant.updated_at if last_warrant else None
        })

    @app.route('/api/v1/rollup/year/<int:year_number>/month/<int:month_number>')
    def monthly_rollup(year_number, month_number):
        start_date, end_date = calendar.monthrange(year_number, month_number)
        start_of_month = date(year_number, month_number, start_date + 1)
        end_of_month = date(year_number, month_number, end_date)
        awards = db.session.query(func.sum(Judgment.awards_fees))\
            .filter(
                Judgment._file_date >= start_of_month,
                Judgment._file_date <= end_of_month,
                Judgment.awards_fees != None
        ).scalar()
        eviction_judgments = Judgment.query.filter(
            Judgment._file_date >= start_of_month,
            Judgment._file_date <= end_of_month,
            Judgment.awards_possession == True
        ).count()
        default_evictions = Judgment.query.filter(
            Judgment._file_date >= start_of_month,
            Judgment._file_date <= end_of_month,
            Judgment.entered_by_id == 0
        ).count()

        return jsonify({
            'detainer_warrants_filed': between_dates(start_of_month, end_of_month, DetainerWarrant.query).count(),
            'eviction_judgments': eviction_judgments,
            'plaintiff_awards': float(awards) if awards else 0.0,
            'evictions_entered_by_default': float(default_evictions)
        })

    @app.route('/api/v1/export')
    @auth_token_required
    def download_csv():
        task = tasks.Task(current_request_id(),
                          admin.serializers.user_schema.dump(current_user))
        thread = Thread(target=tasks.export_zip, args=(app, task))
        thread.daemon = True
        thread.start()
        return jsonify(task.to_json())

    @app.route('/api/v1/accounts/register', methods=['POST'])
    def register():
        data = request.get_json()
        email = data['email']
        user_exists = db.session.query(User).filter_by(email=email).first()
        if user_exists:
            return jsonify({
                'errors': [
                    {'code': 409,
                     'title': 'Email taken',
                     'details': email + ' is already associated with another user.'
                     }
                ]
            }), 409

        else:
            user = register_user(dict(
                email=email,
                password=data['password'],
                first_name=data['first_name'],
                last_name=data['last_name']))
            return jsonify(admin.serializers.user_schema.dump(user))

    @app.route('/api/v1/current-user')
    @auth_token_required
    def me():
        return admin.serializers.user_schema.dump(current_user)


def register_user(user_model_kwargs):
    user_model_kwargs["password"] = hash_password(
        user_model_kwargs["password"])
    user = user_datastore.create_user(**user_model_kwargs)
    db.session.commit()

    confirmation_link, token = generate_confirmation_link(user)

    from flask_security.signals import user_registered

    user_registered.send(
        current_app._get_current_object(),
        user=user,
        confirm_token=token,
        form_data=user_model_kwargs
    )

    if config_value("SEND_REGISTER_EMAIL"):
        send_mail(
            config_value("EMAIL_SUBJECT_REGISTER"),
            user.email,
            "welcome",
            user=user,
            confirmation_link=confirmation_link,
        )

    return user


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
    app.cli.add_command(commands.import_from_caselink)
    app.cli.add_command(commands.sync)
    app.cli.add_command(commands.sync_judgments)
    app.cli.add_command(commands.parse_docket)
    app.cli.add_command(commands.parse_mismatched_pleading_documents)
    app.cli.add_command(commands.parse_detainer_warrant_addresses)
    app.cli.add_command(commands.pick_best_addresses)
    app.cli.add_command(commands.scrape_docket)
    app.cli.add_command(commands.scrape_dockets)
    app.cli.add_command(commands.export)
    app.cli.add_command(commands.export_courtroom_dockets)
    app.cli.add_command(commands.verify_phone)
    app.cli.add_command(commands.verify_phones)
    app.cli.add_command(commands.extract_all_pleading_document_details)
    app.cli.add_command(commands.extract_no_kind_pleading_document_text)
    app.cli.add_command(commands.retry_detainer_warrant_extraction)
    app.cli.add_command(commands.try_ocr_detainer_warrants)
    app.cli.add_command(commands.try_ocr_extraction)
    app.cli.add_command(commands.classify_documents)
    app.cli.add_command(commands.bulk_extract_pleading_document_details)
    app.cli.add_command(commands.extract_pleading_document_text)
    app.cli.add_command(commands.update_judgment_from_document)
    app.cli.add_command(commands.update_judgments_from_documents)
    app.cli.add_command(commands.update_warrants_from_documents)
    app.cli.add_command(commands.gather_documents_for_missing_addresses)
    app.cli.add_command(commands.gather_pleading_documents)
    app.cli.add_command(commands.gather_pleading_documents_in_bulk)
    app.cli.add_command(commands.gather_warrants_csv)
    app.cli.add_command(commands.gather_warrants_csv_monthly)
    app.cli.add_command(commands.bootstrap)
