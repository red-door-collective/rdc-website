{ pkgs ? import (fetchTarball https://git.io/Jf0cc) {} }:

let
  customPython = pkgs.python38.buildEnv.override {
    extraLibs = [ pkgs.python38Packages.ipython pkgs.python38Packages.gspread pkgs.python38Packages.mypy ];
  };
in

pkgs.mkShell {
  buildInputs = [ customPython ];
}
