from sqlalchemy.sql import ClauseElement
import gspread


def dw_rows(limit, workbook):
    ws = workbook.worksheet("2020-2021 detainer warrants")

    all_rows = ws.get_all_records()

    stop_index = int(limit) if limit else all_rows

    return all_rows[:stop_index] if limit else all_rows


def get_gc(service_account_key):
    connect_kwargs = dict()
    if service_account_key:
        connect_kwargs["filename"] = service_account_key

    return gspread.service_account(**connect_kwargs)


def open_workbook(workbook_name, service_account_key):
    return get_gc(service_account_key).open(workbook_name)


def get_or_create(session, model, defaults=None, **kwargs):
    instance = session.query(model).filter_by(**kwargs).one_or_none()
    if instance:
        return instance, False
    else:
        params = {k: v for k, v in kwargs.items() if not isinstance(v, ClauseElement)}
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


def normalize(value):
    if type(value) is int:
        return value
    elif type(value) is str:
        no_trailing = value.strip()
        return no_trailing if no_trailing not in ["", "NA"] else None
    else:
        return None
