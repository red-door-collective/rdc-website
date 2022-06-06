{ sources ? null }:
with builtins;

let
  sources_ = if (sources == null) then import ./sources.nix else sources;
  pkgs = import sources_.nixpkgs { overlays = [ (import ./cypress_overlay.nix) ]; };
  inherit (pkgs) stdenv lib;
  niv = (import sources_.niv { }).niv;
  poetry2nix = pkgs.callPackage sources_.poetry2nix {};
  python = pkgs.python310;

  poetryWrapper = with python.pkgs; pkgs.writeScriptBin "poetry" ''
    export PYTHONPATH=
    unset SOURCE_DATE_EPOCH
    ${poetry}/bin/poetry "$@"
  '';

  overrides = poetry2nix.overrides.withDefaults (
    self: super:
    let
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
      cryptography = super.cryptography.overridePythonAttrs(old:{
        cargoDeps = pkgs.rustPlatform.fetchCargoTarball {
          inherit (old) src;
          name = "${old.pname}-${old.version}";
          sourceRoot = "${old.pname}-${old.version}/src/rust/";
          sha256 = "sha256-qvrxvneoBXjP96AnUPyrtfmCnZo+IriHR5HbtWQ5Gk8=";
        };
        cargoRoot = "src/rust";
        nativeBuildInputs = old.nativeBuildInputs ++ (with pkgs.rustPlatform; [
          rust.rustc
          rust.cargo
          cargoSetupHook
        ]);
      });
  }
  );

in rec {
  inherit pkgs bootstrap javascriptDeps python;
  inherit (pkgs) lib sassc glibcLocales;
  inherit (python.pkgs) buildPythonApplication gunicorn;

  mkPoetryApplication = { ... }@args:
    poetry2nix.mkPoetryApplication (args // {
      inherit overrides;
    });

  inherit (poetry2nix.mkPoetryPackages {
    projectDir = ../.;
    inherit python;
    inherit overrides;
  }) poetryPackages pyProject;

  poetryPackagesByName =
    lib.listToAttrs
      (map
        (p: { name = p.pname; value = p; })
        poetryPackages);

  inherit (poetryPackagesByName) flask deform babel;

  # Can be imported in Python code or run directly as debug tools
  debugLibsAndTools = with python.pkgs; [
    ipython
    poetryPackagesByName.pdbpp
  ];

  pythonDevTest = python.buildEnv.override {
    extraLibs = poetryPackages ++
                debugLibsAndTools;
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

    pylintWrapper = with python.pkgs; pkgs.writeScriptBin "pylint" ''
      ${pylint}/bin/pylint --init-hook='${setSysPath}' "$@"
    '';

    isortWrapper = with python.pkgs; pkgs.writeScriptBin "isort" ''
      ${isort}/bin/isort --virtual-env=${pythonDev} "$@"
    '';

  in [
    bandit
    isortWrapper
    mypy
    pylintWrapper
    yapf
  ];

  externalRuntimeDeps =
  [
    pkgs.chromedriver
    pkgs.chromium
  ];

  # Various tools for log files, deps management, running scripts and so on
  shellTools = 
  [
    niv
    pkgs.jq
    pkgs.postgresql_11
    poetryPackagesByName.pdbpp
    poetryWrapper
    python.pkgs.gunicorn
    pkgs.chromedriver
    pkgs.chromium
  ];

  frontendTools =
  [
    pkgs.elmPackages.elm
    pkgs.elmPackages.elm-test
    pkgs.elmPackages.elm-format
    pkgs.elmPackages.elm-optimize-level-2
    pkgs.elmPackages.elm-review
  ];

  # Needed for a development nix shell
  shellInputs =
    linters ++
    shellTools ++
    frontendTools ++ [
      pythonTest
    ];

  shellPath = lib.makeBinPath shellInputs;
}
