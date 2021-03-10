#!/usr/bin/env -S nix-build -o serve_app
{ sources ? null,
  listen ? "127.0.0.1:8080",
  tmpdir ? null
}:
let
  eviction-tracker = import ../. { inherit sources; };
  inherit (eviction-tracker) dependencyEnv deps src;
  inherit (deps) pkgs flask gunicorn lib;
  pythonpath = "${dependencyEnv}/${dependencyEnv.sitePackages}";

  gunicornConf = pkgs.writeText
                "gunicorn_config.py"
                (import ./gunicorn_config.py.nix {
                   inherit listen pythonpath;
                });

  runGunicorn = pkgs.writeShellScriptBin "run" ''
    ${lib.optionalString (tmpdir != null) "export TMPDIR=${tmpdir}"}
    ${gunicorn}/bin/gunicorn -c ${gunicornConf} \
      "eviction_tracker.app:create_app()"
  '';

  runMigrations = pkgs.writeShellScriptBin "migrate" ''
    export PYTHONPATH=${pythonpath}
    cd ${src}
    ${flask}/bin/flask db upgrade
  '';

  runSync = pkgs.writeShellScriptBin "sync" ''
    export PYTHONPATH=${pythonpath}
    cd ${src}
    ${flask}/bin/flask sync "$@"
  '';

in pkgs.buildEnv {
  name = "eviction-tracker-serve-app";
  paths = [
    runGunicorn
    runMigrations
    runSync
  ];
}