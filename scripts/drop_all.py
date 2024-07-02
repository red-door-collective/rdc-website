import logging
import os

from rdc_website.app import create_app

logging.basicConfig(level=logging.INFO)


def clear_data(session):
    meta = db.metadata
    for table in reversed(meta.sorted_tables):
        logg.info("Clear table ${table}")
        session.execute(table.delete())
    session.commit()


if __name__ == "__main__":

    logg = logging.getLogger(__name__)

    app = create_app()

    with app.app_context():
        print(f"using config file ${os.environ['RDC_WEBSITE_CONFIG']}")
        print(f"using db url ${app.config['SQLALCHEMY_DATABASE_URI']}")

        from rdc_website.database import db

        print(80 * "=")
        input("press Enter to drop all tables...")

        clear_data(db.session)

        logg.info("committed")
