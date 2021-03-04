let
  pkgs = import ./nix/python.nix;
  pythonEnv = import ./nix/deps.nix;

in pkgs.python37Packages.buildPythonApplication {
  pname = "eviction-tracker";
  src = ./.;
  version = "0.1";
  propagatedBuildInputs = [ pythonEnv ];

  EVICTION_TRACKER_SECRET_KEY = "lk;jasdlkfjas;dfja;sldjfl;akjdsflasdfjdjsfajdf";
}
