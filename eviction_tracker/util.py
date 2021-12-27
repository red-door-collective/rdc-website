from sqlalchemy.sql import ClauseElement
from datetime import datetime
import re

EFILE_DATE_REGEX = re.compile(r'EFILED\s*(\d+/\d+/\d+)\s*')


def file_date_guess(text):
    efile_date_match = EFILE_DATE_REGEX.search(text)
    if efile_date_match:
        return datetime.strptime(efile_date_match.group(1), '%m/%d/%y').date()
    else:
        return None


def get_or_create(session, model, defaults=None, **kwargs):
    instance = session.query(model).filter_by(**kwargs).one_or_none()
    if instance:
        return instance, False
    else:
        params = {k: v for k, v in kwargs.items(
        ) if not isinstance(v, ClauseElement)}
        params.update(defaults or {})
        instance = model(**params)
        try:
            session.add(instance)
            session.commit()
        except Exception:  # The actual exception depends on the specific database so we catch all exceptions. This is similar to the official documentation: https://docs.sqlalchemy.org/en/latest/orm/session_transaction.html
            session.rollback()
            instance = session.query(model).filter_by(**kwargs).one()
            return instance, False
        else:
            return instance, True
