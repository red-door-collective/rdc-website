from .models import db
from .models import Attorney, Courtroom, Defendant, DetainerWarrant, District, Judge, Plantiff, detainer_warrant_defendants
from .util import get_or_create
from sqlalchemy.exc import IntegrityError, InternalError
from sqlalchemy.dialects.postgresql import insert

def _init_status(warrant):
    statuses = {
        'CLOSED': 0,
        'PENDING': 1
    }
    return statuses[warrant[3].upper()]

def _init_amount_claimed_category(warrant):
    categories = {
        'POSS': 0,
        'FEES': 1,
        'BOTH': 2,
        'N/A': 3,
        '': 4
    }
    return categories[warrant[12].upper()]

def init_phone(warrant):
    # take first phone number for now
    return warrant[14].split(',')[0] if warrant[14] else None

def _from_spreadsheet_row(warrant, defaults):
    docket_id = warrant[0]
    file_date = warrant[2]
    status = _init_status(warrant)
    attorney, _ = get_or_create(db.session, Attorney, name=warrant[7], defaults=defaults)
    plantiff, _ = get_or_create(db.session, Plantiff, name=warrant[6], attorney=attorney, defaults=defaults)
    court_date = warrant[8]
    courtroom, _ = get_or_create(db.session, Courtroom, name=warrant[9], defaults=defaults)
    presiding_judge, _ = get_or_create(db.session, Judge, name=warrant[10], defaults=defaults)
    amount_claimed = warrant[11]
    amount_claimed_category = _init_amount_claimed_category(warrant)
    defendant, _ = get_or_create(db.session, Defendant, address=warrant[15], name=warrant[14], phone=warrant[16], defaults=defaults)

    insert_stmt = insert(DetainerWarrant).values(
        docket_id=docket_id,
        file_date=file_date,
        status=status,
        plantiff_id=plantiff.id,
        court_date=court_date,
        courtroom_id=courtroom.id,
        presiding_judge_id=presiding_judge.id,
        amount_claimed=amount_claimed,
        amount_claimed_category=amount_claimed_category,
    )

    do_update_stmt = insert_stmt.on_conflict_do_update(
        constraint=DetainerWarrant.__table__.primary_key,
        set_= dict(
        file_date=file_date,
        status=status,
        plantiff_id=plantiff.id,
        court_date=court_date,
        courtroom_id=courtroom.id,
        presiding_judge_id=presiding_judge.id,
        amount_claimed=amount_claimed,
        amount_claimed_category=amount_claimed_category,
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

