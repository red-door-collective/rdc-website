#!/usr/bin/env -S nix-build -o serve_app
{ sources ? null,
  listen ? "127.0.0.1:8080",
  tmpdir ? null
}:
let
  eviction_tracker = import ../. { inherit sources; };
  inherit (eviction_tracker) dependencyEnv src;
  deps = import ./deps.nix { inherit sources; };
  inherit (deps) pkgs gunicorn lib externalRuntimeDeps;
  pythonpath = "${dependencyEnv}/${dependencyEnv.sitePackages}";

  gunicornConf = pkgs.writeText
                "gunicorn_config.py"
                (import ./gunicorn_config.py.nix {
                   inherit listen pythonpath;
                });

  runGunicorn = pkgs.writeShellScriptBin "run" ''
    ${pkgs.lib.optionalString (tmpdir != null) "export TMPDIR=${tmpdir}"}
    export PYTHONPATH=${pythonpath}
    PATH="${pkgs.chromedriver}/bin:${pkgs.chromium}/bin"

    ${gunicorn}/bin/gunicorn -c ${gunicornConf} \
      "eviction_tracker.app:create_app()"
  '';

  runMigrations = pkgs.writeShellScriptBin "migrate" ''
    export PYTHONPATH=${pythonpath}
    cd ${src}
    ${dependencyEnv}/bin/flask db upgrade
  '';

  console = pkgs.writeShellScriptBin "console" ''
    export PYTHONPATH=${pythonpath}
    cd ${src}
    ${dependencyEnv}/bin/flask shell
  '';

  runFlask = pkgs.writeShellScriptBin "flask" ''
    export PYTHONPATH=${pythonpath}
    cd ${src}
    ${dependencyEnv}/bin/flask "$@"
  '';

  serve = pkgs.writeShellScriptBin "serve" ''
      export $(cat /srv/within/eviction_tracker/.env | xargs)
      export FLASK_APP="eviction_tracker.app"
      ${runMigrations}
      export FLASK_APP="eviction_tracker"
      ${runGunicorn}
    '';

in pkgs.buildEnv {
  name = "eviction-tracker-serve-app";
  paths = [
    runGunicorn
    runMigrations
    runFlask
    console
    serve
  ] ++ externalRuntimeDeps;
}