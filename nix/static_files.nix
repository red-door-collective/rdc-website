with builtins;

{ sources ? null }:
let
  deps = import ./deps.nix { inherit sources; };
  inherit (deps) lib pkgs python pyProject;
  version = import ./git_version.nix { inherit pkgs; default = pyProject.tool.poetry.version; };

in
pkgs.runCommand "eviction-tracker-static-${version}" {
  buildInputs = [];
  src = ../eviction_tracker;
} ''
  mkdir -p $out
  cp -r $src/static/ $out
  ls -la $out
''