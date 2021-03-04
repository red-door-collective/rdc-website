let
  pkgs = import ./nix/pkgs.nix;
  python = import ./nix/python.nix;
  
  frontendEnv = [
    pkgs.elmPackages.elm
    pkgs.elmPackages.elm-format
    pkgs.elmPackages.elm-live
    pkgs.elmPackages.elm-test
  ];

in pkgs.mkShell rec {
  EVICTION_TRACKER_SECRET_KEY = "development";
  ENVIRONMENT = "development";
  HOST = "127.0.0.1";
  PORT = "8080";

  buildInputs = [
    python.env
    frontendEnv
  ];
}
