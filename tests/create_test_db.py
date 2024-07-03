from datetime import datetime
from pathlib import Path
from typing import Optional
import os

import mimesis
import typer
from rich import print
from typer import Option, confirm, Exit

from tests.db_utils import clear_data


def main(
    config_file: Optional[Path] = Option(
        "../tests/config.json",
        "--config-file",
        "-c",
        help="Path to config file in JSON format. Default: Built-in test config (DB test_rdc_website).",
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

    from rdc_website.app import create_app

    os.environ["RDC_WEBSITE_CONFIG"] = str(config_file)

    app = create_app(testing=True)

    from rdc_website.database import db

    # local import because we have to set up the database stuff before that
    from rdc_website.detainer_warrants.models import DetainerWarrant, PleadingDocument

    print(f"using config file {config_file}")
    print(f"using db url {app.config['SQLALCHEMY_DATABASE_URI']}")

    with app.app_context():
        if doit:
            confirmed = True
        else:
            print(80 * "=")
            confirmed = confirm("Drop and recreate the database now?", default=False)

        if not confirmed:
            print("Not confirmed, doing nothing.")
            raise Exit(3)

        clear_data(db)
        db.create_all()


if __name__ == "__main__":
    typer.run(main)
