let
  sources = import ./sources.nix;
  pkgs = import sources.nixpkgs {};
  newpkgs = import pkgs.path { overlays = [ (pkgsself: pkgssuper: {
    python37 = let
      packageOverrides = self: super: {
        # numpy = super.numpy_1_10;
      };
    in pkgssuper.python37.override {inherit packageOverrides;};
  } ) ]; };
in newpkgs