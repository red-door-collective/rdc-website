import csv
import requests
import io
from nameparser import HumanName
from sqlalchemy.orm.exc import MultipleResultsFound

from .models import db, Case, Plaintiff, Attorney, Defendant, DetainerWarrant
from .util import get_or_create, normalize


def create_defendant(docket_id, column):
    name = HumanName(column.replace("OR ALL OCCUPANTS", ""))

    exists_on_this_docket = DetainerWarrant.query.filter(
        DetainerWarrant.docket_id == docket_id,
        DetainerWarrant._defendants.any(first_name=name.first, last_name=name.last),
    ).first()

    if bool(exists_on_this_docket):
        return exists_on_this_docket.defendants

    defendant = None
    if bool(name.first):
        try:
            defendant, _ = get_or_create(
                db.session,
                Defendant,
                first_name=name.first,
                middle_name=name.middle,
                last_name=name.last,
                suffix=name.suffix,
            )
        except MultipleResultsFound:
            defendant = Defendant.query.filter_by(
                first_name=name.first,
                middle_name=name.middle,
                last_name=name.last,
                suffix=name.suffix,
            ).first()
    return [defendant]


def from_csv_row(row):
    warrant = {k: normalize(v) for k, v in row.items()}
    docket_id = warrant["Docket #"]

    if not ("DETAINER WARRANT" in warrant["Description"] and "GT" in docket_id):
        return

    dw = db.session.get(DetainerWarrant, docket_id)

    if not dw:
        dw = DetainerWarrant.create(docket_id=docket_id)
        db.session.add(dw)
        db.session.commit()

    plaintiff = None
    if warrant["Plaintiff"]:
        plaintiff, _ = get_or_create(db.session, Plaintiff, name=warrant["Plaintiff"])

    plaintiff_attorney = None
    if warrant["Pltf. Attorney"]:
        plaintiff_attorney, _ = get_or_create(
            db.session, Attorney, name=warrant["Pltf. Attorney"]
        )

    defendants = create_defendant(dw.docket_id, warrant["Defendant"])

    dw.update(
        status=warrant["Status"],
        _file_date=warrant["File Date"],
        _plaintiff=plaintiff,
        _plaintiff_attorney=plaintiff_attorney,
        defendants=[{"id": d.id} for d in defendants if d],
    )

    db.session.add(dw)
    db.session.commit()


def from_rows(rows):
    for row in rows:
        from_csv_row(row)


def from_caselink(csvpath):
    with open(csvpath) as csvfile:
        reader = csv.DictReader(csvfile)
        for row in reader:
            from_csv_row(row)
