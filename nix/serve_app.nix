#!/usr/bin/env -S nix-build -o serve_app
{
  pkgs,
  lib,
  app,
  gunicorn,
  appConfigFile ? null,
  listen ? "127.0.0.1:10080",
  tmpdir ? null,
  system ? builtins.currentSystem,
}: let
  inherit (app) dependencyEnv src;
  pythonpath = "${dependencyEnv}/${dependencyEnv.sitePackages}";

  exportConfigEnvVar =
    lib.optionalString
    (appConfigFile != null)
    "export RDC_WEBSITE_CONFIG=\${RDC_WEBSITE_CONFIG:-${appConfigFile}}";

  gunicornConf =
    pkgs.writeText
    "gunicorn_config.py"
    (import ./gunicorn_config.py.nix {
      inherit listen pythonpath;
    });

  runGunicorn = pkgs.writeShellScriptBin "rdc-website-serve-app" ''
    export PYTHONPATH=${pythonpath}
    ${exportConfigEnvVar}
    ${lib.optionalString (tmpdir != null) "export TMPDIR=${tmpdir}"}

    ${gunicorn}/bin/gunicorn -c ${gunicornConf} \
      "rdc_website.app:create_app()"
  '';

  runMigrate = pkgs.writeShellScriptBin "migrate" ''
    ${exportConfigEnvVar}
    cd ${src}
    ${dependencyEnv}/bin/flask db upgrade
  '';

  runPython = pkgs.writeShellScriptBin "python" ''
    ${exportConfigEnvVar}
    ${lib.optionalString (tmpdir != null) "export TMPDIR=${tmpdir}"}
    cd ${src}
    ${dependencyEnv}/bin/python "$@"
  '';

  runConsole = pkgs.writeShellScriptBin "console" ''
    ${exportConfigEnvVar}
    ${lib.optionalString (tmpdir != null) "export TMPDIR=${tmpdir}"}
    cd ${src}
    ${dependencyEnv}/bin/flask shell
  '';

  runConmmand = pkgs.writeShellScriptBin "command" ''
    ${exportConfigEnvVar}
    ${lib.optionalString (tmpdir != null) "export TMPDIR=${tmpdir}"}
    cd ${src}
    ${dependencyEnv}/bin/flask "$@"
  '';
in
  pkgs.buildEnv {
    ignoreCollisions = true;
    name = "rdc-website-serve-app";
    paths = [runGunicorn runMigrate runPython runConsole runConmmand];
  }
