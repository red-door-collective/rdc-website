{ pkgs
, deform
, pyProject
, python
, ...
}:

with builtins;

let
  inherit (pyProject.tool.poetry) version;
in
pkgs.runCommand "rdc-website-static-${version}"
{
  buildInputs = [ ];
  src = ../rdc_website;
} ''
  #cp -r $src/static/img $out
  cp $src/static/favicon.ico $out
  mkdir $out/debug
''
