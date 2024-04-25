{ sources ? null }:
let
  deps = import ./nix/deps.nix { inherit sources; };
  inherit (deps) pkgs;
  inherit (pkgs) lib stdenv;
  caBundle = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";

in
pkgs.mkShell {
  name = "rdc-website";
  buildInputs = deps.shellInputs ++ [
    pkgs.cypress
    # (with pkgs.dotnetCorePackages; combinePackages [ sdk_5_0 net_5_0 ])
    pkgs.nodejs
  ];
  shellHook = ''
    export CYPRESS_INSTALL_BINARY=0
    export CYPRESS_RUN_BINARY=${pkgs.cypress}/bin/Cypress
    export PATH=${deps.shellPath}:$PATH
    # A pure nix shell breaks SSL for git and nix tools which is fixed by setting
    # the path to the certificate bundle.
    export SSL_CERT_FILE=${caBundle}
    export NIX_SSL_CERT_FILE=${caBundle}
    # Make ZIP happy for wheels, doesn't support timestamps before 1980.
    export SOURCE_DATE_EPOCH=315532800
    set -o allexport; source .env; set +o allexport
    set -o allexport; source .env.dev; set +o allexport
  '' +
  lib.optionalString (pkgs.stdenv.hostPlatform.libc == "glibc") ''
    export LOCALE_ARCHIVE=${deps.glibcLocales}/lib/locale/locale-archive
  '';
}
