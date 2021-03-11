from .models import db
from .models import Attorney, Courtroom, Defendant, DetainerWarrant, District, Judge, Plantiff, detainer_warrant_defendants
from .util import get_or_create
from sqlalchemy.exc import IntegrityError, InternalError
from sqlalchemy.dialects.postgresql import insert


def init_phone(warrant):
    # take first phone number for now
    return warrant[14].split(',')[0] if warrant[14] else None

def _from_spreadsheet_row(warrant, defaults):
    docket_id = warrant[0]
    file_date = warrant[2]
    status = warrant[3].upper()
    attorney, _ = get_or_create(
        db.session, Attorney, name=warrant[7], defaults=defaults)
    plantiff, _ = get_or_create(
        db.session, Plantiff, name=warrant[6], attorney=attorney, defaults=defaults)

    court_date = warrant[8].strip() if warrant[8].strip() else None

    courtroom = None
    if warrant[9].strip():
        courtroom, _ = get_or_create(
            db.session, Courtroom, name=warrant[9].strip(), defaults=defaults)

    presiding_judge = None
    if warrant[10].strip():
        presiding_judge, _ = get_or_create(
            db.session, Judge, name=warrant[10].strip(), defaults=defaults)

    amount_claimed = warrant[11].strip() if warrant[11].strip() else None
    amount_claimed_category = warrant[12].upper(
    ) if warrant[12].strip() else 'N/A'

    defendant, _ = get_or_create(
        db.session, Defendant, address=warrant[15], name=warrant[14], phone=warrant[16], defaults=defaults)

    insert_stmt = insert(DetainerWarrant).values(
        docket_id=docket_id,
        file_date=file_date,
        status_id=DetainerWarrant.statuses[status],
        plantiff_id=plantiff.id if plantiff else None,
        court_date=court_date,
        courtroom_id=courtroom.id if courtroom else None,
        presiding_judge_id=presiding_judge.id if presiding_judge else None,
        amount_claimed=amount_claimed,
        amount_claimed_category_id=DetainerWarrant.amount_claimed_categories[amount_claimed_category],
    )

    do_update_stmt = insert_stmt.on_conflict_do_update(
        constraint=DetainerWarrant.__table__.primary_key,
        set_= dict(
        file_date=file_date,
        status_id=DetainerWarrant.statuses[status],
        plantiff_id=plantiff.id if plantiff else None,
        court_date=court_date,
        courtroom_id=courtroom.id if courtroom else None,
        presiding_judge_id=presiding_judge.id if presiding_judge else None,
        amount_claimed=amount_claimed,
        amount_claimed_category_id=DetainerWarrant.amount_claimed_categories[amount_claimed_category],
        )
    )

    db.session.execute(do_update_stmt)
    db.session.commit()

    try:
        db.session.execute(insert(detainer_warrant_defendants)
            .values(detainer_warrant_docket_id=docket_id, defendant_id=defendant.id))
    except IntegrityError:
        pass

    db.session.commit()

def from_spreadsheet(warrants):
    district, _ = get_or_create(db.session, District, name="Davidson County")
    
    db.session.add(district)
    db.session.commit()

    defaults = {'district': district}

    for warrant in warrants:
        _from_spreadsheet_row(warrant, defaults)

