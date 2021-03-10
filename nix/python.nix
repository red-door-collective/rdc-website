let
  pkgs = import ./pkgs.nix;
in
{ env = pkgs.python37.withPackages (ps: with ps; [
    ipykernel
    python-language-server pyls-isort
    matplotlib numpy
    autopep8
    click
    gspread
    sqlalchemy
    flask
    flask_sqlalchemy
    flask_assets
    flask-restful
    flask_marshmallow
    flask_testing
    flask_migrate
    marshmallow-sqlalchemy
    psycopg2
    pytest
    gunicorn
    gevent
  ]);
}
