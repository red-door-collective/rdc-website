from datetime import datetime
from pathlib import Path
from typing import Optional

import mimesis
import sqlalchemy.orm
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

    app = create_app()

    from rdc_website.database import session

    # local import because we have to set up the database stuff before that
    from rdc_website.detainer_warrants.models import DetainerWarrant, PleadingDocument

    print(f"using config file {config_file}")
    print(f"using db url {app.config['SQLALCHEMY_DATABASE_URI']}")

    engine = sqlalchemy.create_engine(
        app.config['SQLALCHEMY_DATABASE_URI'], poolclass=pool.NullPool
    )
    connection = engine.connect()
    sqlalchemy.orm.configure_mappers()

    print("Finished successfully.")


if __name__ == "__main__":
    typer.run(main)
