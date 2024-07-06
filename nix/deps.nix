{
  pkgs,
  poetry2nix,
}:
with builtins; let
  inherit (pkgs) stdenv lib;
  python = pkgs.python311;
  poetry = pkgs.poetry.override {python3 = python;};

  overrides = poetry2nix.defaultPoetryOverrides.extend (
    self: super: let
      pythonBuildDepNameValuePair = deps: pname: {
        name = pname;
        value = super.${pname}.overridePythonAttrs (old: {
          buildInputs = old.buildInputs ++ deps;
        });
      };

      addPythonBuildDeps = deps: pnames:
        lib.listToAttrs
        (map
          (pythonBuildDepNameValuePair deps)
          pnames);
    in
      {
        bcrypt = super.bcrypt.overridePythonAttrs (old: rec {
          pname = "bcrypt";
          version = "4.1.3";
          src = pkgs.fetchPypi {
            inherit pname version;
            hash = "sha256-LuFd10n1lS/j8EMND/a3QILhWcUDMqFBPVG1aJzwZiM=";
          };

          cargoDeps = pkgs.rustPlatform.fetchCargoTarball {
            inherit src;
            sourceRoot = "${old.pname}-${old.version}/${old.cargoRoot}";
            name = "${old.pname}-${old.version}";
            hash = "sha256-Uag1pUuis5lpnus2p5UrMLa4HP7VQLhKxR5TEMfpK0s=";
          };
        });

        cryptography = super.cryptography.overridePythonAttrs (old: rec {
          cargoDeps = pkgs.rustPlatform.fetchCargoTarball {
            inherit (old) src;
            name = "${old.pname}-${old.version}";
            sourceRoot = "${old.pname}-${old.version}/${cargoRoot}";
            sha256 = "sha256-wAup/0sI8gYVsxr/vtcA+tNkBT8wxmp68FPbOuro1E4=";
          };
          cargoRoot = "src/rust";
        });

        mimesis-factory = super.mimesis-factory.overridePythonAttrs (old: {
          buildInputs = old.buildInputs ++ [self.poetry-core];
          patchPhase = ''
            substituteInPlace pyproject.toml --replace poetry.masonry poetry.core.masonry
          '';
        });
      }
      // (addPythonBuildDeps [self.setuptools-scm self.setuptools self.greenlet] [
        "pdbpp"
      ])
      // (
        addPythonBuildDeps
        [self.setuptools]
        [
          "konch"
          "flask-resty"
          "flask-apscheduler"
          "probableparsing"
          "usaddress"
          "gspread-formatting"
          "webtest"
          "mimesis"
          "better-exceptions"
        ]
      )
      // (
        addPythonBuildDeps
        [self.flit-core] [
          "itsdangerous"
          "marshmallow"
          "flask-sqlalchemy"
          "marshmallow-sqlalchemy"
          "flask-marshmallow"
          "jinja2"
        ]
      )
      // (addPythonBuildDeps
        [self.poetry-core] [
          "iso8601"
        ])
      // (addPythonBuildDeps
        [self.poetry-core self.greenlet] [
          "alembic"
          "pytest-factoryboy"
          "sqlalchemy"
          "sqlalchemy-utils"
          "zope-sqlalchemy"
        ])
      // (addPythonBuildDeps
        [self.hatchling] [
          "dnspython"
        ])
      // (addPythonBuildDeps
        [self.hatchling self.babel] [
          "wtforms"
        ])
      // (addPythonBuildDeps
        [self.pdm-pep517 self.pdm-backend] [
          "typer"
        ])
  );

  mkPoetryApplication = args:
    poetry2nix.mkPoetryApplication (args
      // {
        inherit overrides;
        inherit python;
      });

  inherit
    (poetry2nix.mkPoetryPackages {
      projectDir = ../.;
      inherit python;
      inherit overrides;
    })
    poetryPackages
    pyProject
    ;

  poetryPackagesByName =
    lib.listToAttrs
    (map
      (p: {
        name = p.pname or "none";
        value = p;
      })
      poetryPackages);
in rec {
  inherit mkPoetryApplication pkgs poetryPackagesByName pyProject python;
  inherit (pkgs) glibcLocales;
  inherit (poetryPackagesByName) alembic deform babel gunicorn ipython;

  # Can be imported in Python code or run directly as debug tools
  debugLibsAndTools = with python.pkgs; [
    poetryPackagesByName.pdbpp
    poetryPackagesByName.ipython
  ];

  pythonDevTest = python.buildEnv.override {
    extraLibs =
      poetryPackages
      ++ debugLibsAndTools;
    ignoreCollisions = true;
  };

  pythonTest = pythonDevTest;
  pythonDev = pythonDevTest;

  # Code style and security tools
  linters = with python.pkgs; let
    # Pylint needs to import the modules of our dependencies
    # but we don't want to override its own PYTHONPATH.
    setSysPath = ''
      import sys
      sys.path.append("${pythonDev}/${pythonDev.sitePackages}")
    '';

    pylintWrapper = with python.pkgs;
      pkgs.writeScriptBin "pylint" ''
        ${pylint}/bin/pylint --init-hook='${setSysPath}' "$@"
      '';

    isortWrapper = with python.pkgs;
      pkgs.writeScriptBin "isort" ''
        ${isort}/bin/isort --virtual-env=${pythonDev} "$@"
      '';
  in [
    # bandit
    #isortWrapper
    pkgs.nixpkgs-fmt
    #pylintWrapper
    # pkgs.cypress
    pkgs.nodejs
  ];

  frontendTools = [
    pkgs.elmPackages.elm
    pkgs.elmPackages.elm-test
    pkgs.elmPackages.elm-format
    pkgs.elmPackages.elm-optimize-level-2
    pkgs.elmPackages.elm-review
  ];

  # Various tools for log files, deps management, running scripts and so on
  shellTools = let
    console = pkgs.writeScriptBin "console" ''
      export PYTHONPATH=$PYTHONPATH:${pythonDev}/${pythonDev.sitePackages}
      ${ipython}/bin/ipython -i consoleenv.py "$@"
    '';
  in [
    console
    pkgs.postgresql_16
    poetryPackagesByName.pdbpp
    poetry
    poetryPackagesByName.gunicorn
    poetryPackagesByName.eliot-tree
  ];

  # Needed for a development nix shell
  shellInputs =
    linters
    ++ shellTools
    ++ frontendTools
    ++ [
      pythonTest
    ];

  shellPath = lib.makeBinPath shellInputs;
}
