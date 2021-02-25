let
  pkgs = import ./pkgs.nix;
in
{ env = pkgs.python37.withPackages (ps: with ps; [
    ipykernel
    python-language-server pyls-isort
    matplotlib numpy
    autopep8
    gspread
    sqlalchemy
    flask
    flask_sqlalchemy
    flask_assets
    flask-restful
    flask_marshmallow
    marshmallow-sqlalchemy
  ]);
}
