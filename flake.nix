# This Flake uses devenv and flake-parts.
# https://devenv.sh
# https://flake.parts
# https://devenv.sh/guides/using-with-flake-parts/
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";
    devenv = {
      url = "github:cachix/devenv?rev=40b567388381137a3c49acdff5f4b6946d645a5f";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    poetry2nix = {
      url = "github:nix-community/poetry2nix?rev=42262f382c68afab1113ebd1911d0c93822d756e";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs @ {
    flake-parts,
    self,
    ...
  }:
    flake-parts.lib.mkFlake {inherit inputs;} {
      imports = [
        inputs.devenv.flakeModule
        inputs.flake-parts.flakeModules.easyOverlay
      ];
      systems = ["x86_64-linux" "x86_64-darwin" "aarch64-darwin"];

      perSystem = {
        config,
        self',
        inputs',
        pkgs,
        system,
        ...
      }: let
        deps = import ./nix/deps.nix {
          poetry2nix = inputs.poetry2nix.lib.mkPoetry2Nix {inherit pkgs;};
          inherit pkgs;
        };

        app = pkgs.callPackage ./nix/app.nix deps;

        serveApp = pkgs.callPackage ./nix/serve_app.nix {
          inherit app;
          inherit (deps) gunicorn;
        };

        staticFiles = pkgs.callPackage ./nix/static_files.nix deps;

        venv = pkgs.buildEnv {
          name = "rdc-website-venv";
          ignoreCollisions = true;
          paths = with deps;
            [pythonDev]
            ++ linters;
        };
      in {
        # Per-system attributes can be defined here. The self' and inputs'
        # module parameters provide easy access to attributes of the same
        # system.
        # The Nix overlay is available as `overlays.default`.
        overlayAttrs = {
          inherit
            (config.packages)
            rdc-website
            rdc-website-static
            rdc-website-serve-app
            ;
        };

        checks = {
          inherit (config.packages) rdc-website-serve-app;
        };

        formatter = pkgs.alejandra;

        packages = {
          default = serveApp;

          inherit venv;
          rdc-website = app;
          rdc-website-static = staticFiles;
          rdc-website-serve-app = serveApp;
        };

        devenv.shells.default = {
          name = "rdc-website";

          dotenv.enable = true;

          env = {
            PYTHONPATH = ".";
            ENV = "development";
            VERSION = self.rev or self.dirtyRev or "dirty";
            ROLLBAR_CLIENT_TOKEN = "test";
            RDC_WEBSITE_CONFIG = "../config.json";
            FLASK_RUN_PORT = "5001";
          };

          packages = deps.shellInputs;

          scripts = {
            build_python_venv.exec = ''
              nix build .#venv -o venv
              echo "Created directory 'venv' which is similar to a Python virtualenv."
              echo "Provides linters and a Python interpreter with runtime dependencies and test tools."
              echo "The 'venv' should be picked up py IDE as a possible project interpreter (restart may be required)."
              echo "Tested with VSCode, Pycharm."
            '';
            run_dev.exec = ''
              flask run --no-debug | tee run_dev.log.json
            '';
            debug_dev.exec = ''
              flask run --debug | tee run_dev.log.json
            '';
            debug_ui.exec = ''
              cd pages && npm start
            '';
            create_dev_db.exec = ''
              python tests/create_test_db.py --config-file config.json
            '';
            create_test_db.exec = ''
              python tests/create_test_db.py
            '';
            help.exec = ''
              cat << END
              # Development Shell Commands
              (standard tools + commands defined in flake.nix)

              ## Basic
              create_test_db           Set up PostgreSQL database for testing, using config.json.
              pytest                   Run Python test suite.
              run_dev                  Run application in dev mode with formatted log output.

              ## Development
              debug_dev                Debug application in dev mode (use this with breakpoints).
              debug_ui                 Debug UI in dev mode
              build_python_venv        Build 'virtualenv' for IDE integration.
              console                  Run IPython REPL for interaction with application objects.

              END
            '';
          };
        };
      };

      flake = {
        # The usual flake attributes can be defined here, including system-
        # agnostic ones like nixosModule and system-enumerating ones, although
        # those are more easily expressed in perSystem.

        # Using this NixOS module requires the default overlay from here.
        # Example, when `rdcWebsite` is the Flake:
        # nixpkgs.overlays = [ rdcWebsite.overlays.default ];
        # imports = [ rdcWebsite.nixosModules.default ];
        nixosModules.default = import nix/modules/default.nix;
      };
    };
}
