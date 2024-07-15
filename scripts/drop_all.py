import os

from rdc_website.app import create_app
from tests.db_utils import clear_data

from loguru import logger

if __name__ == "__main__":

    app = create_app()

    with app.app_context():
        print(f"using config file ${os.environ['RDC_WEBSITE_CONFIG']}")
        print(f"using db url ${app.config['SQLALCHEMY_DATABASE_URI']}")

        from rdc_website.database import db

        print(80 * "=")
        input("press Enter to drop all tables...")

        clear_data(db)

        logger.info("committed")
