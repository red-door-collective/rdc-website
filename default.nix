# Build Python package.
# Can be installed in the current user profile with:
# nix-env -if .
{ sources ? null }:
let
  deps = import ./nix/deps.nix { inherit sources; };
  inherit (deps) babel pkgs mkPoetryApplication python pyProject;
  inherit (deps.pyProject) version;
  src = ./.;

in mkPoetryApplication {
  doCheck = false;
  projectDir = ./.;
  inherit python src version;

  passthru = {
    inherit src version;
  };

  postInstall = ''
    ${babel}/bin/pybabel compile -d $out/${python.sitePackages}/eviction_tracker/translations
  '';
}
