import sqlalchemy


def clear_data(db):
    try:
        meta = db.metadata
        for table in reversed(meta.sorted_tables):
            print("Clear table {}".format(table))
            db.session.execute(table.delete())
        db.session.commit()
    except sqlalchemy.exc.ProgrammingError as e:
        print("No tables yet created")
