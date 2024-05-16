from datetime import datetime
from pathlib import Path
from typing import Optional

import mimesis
import sqlalchemy.orm
import transaction
import typer
from alembic import command
from alembic.config import Config
from rich import print
from sqlalchemy import pool
from typer import Option, confirm, Exit

from rdc_website.app import create_app, current_app, db, DetainerWarrant


def main(
    config_file: Optional[Path] = Option(
        None,
        "--config-file",
        "-c",
        help="Path to config file in YAML / JSON format. Default: Built-in test config (DB test_rdc_website).",
        readable=True,
    ),
    doit: bool = Option(
        False, "--doit", help="Don't ask, just drop and recreate the database"
    ),
):
    """
    Create an rdc-website database for testing.
    This is needed for pytest but can also be used for manual application testing.
    """

    from rdc_website.app import create_app, db, DetainerWarrant
    from fixtures import get_test_settings, get_db_uri

    if config_file:
        app = create_app(config_file)
    else:
        settings = get_test_settings(get_db_uri())
        app = create_app(testing=True)

    from rdc_website.database import session

    # local import because we have to set up the database stuff before that
    from rdc_website.detainer_warrants.models import DetainerWarrant, PleadingDocument

    print(f"using config file {config_file}")
    print(f"using db url {app.settings.database.uri}")

    engine = sqlalchemy.create_engine(
        app.settings.database.uri, poolclass=pool.NullPool
    )
    connection = engine.connect()
    connection.execute("select")

    sqlalchemy.orm.configure_mappers()

    if doit:
        confirmed = True
    else:
        print(80 * "=")
        confirmed = confirm("Drop and recreate the database now?", default=False)

    if not confirmed:
        print("Not confirmed, doing nothing.")
        raise Exit(3)

    db.drop_all()
    connection.execute("DROP TABLE IF EXISTS alembic_version")
    db.create_all()

    s = session

    transaction.commit()

    print("Committed database changes.")

    alembic_cfg = Config("./alembic.ini")
    alembic_cfg.attributes["connection"] = connection

    command.stamp(alembic_cfg, "head")

    # Fixes a strange error message when the connection isn't closed.
    # Didn't happen before.
    connection.close()

    print("Finished successfully.")


if __name__ == "__main__":
    typer.run(main)
