{ pkgs, lib, config, inputs, ... }:

{
  # https://devenv.sh/basics/
  env.GREET = "devenv";

  # https://devenv.sh/packages/
  packages = [ pkgs.git pkgs.poetry ];

  # https://devenv.sh/scripts/
  scripts.hello.exec = "echo hello from $GREET";

  dotenv.enable = true;

  enterShell = ''
    hello
    git --version
    set -o allexport; source .env; set +o allexport
    set -o allexport; source .env.dev; set +o allexport
  '';

  # https://devenv.sh/tests/
  enterTest = ''
    set -o allexport; source .env; set +o allexport
    set -o allexport; source .env.dev; set +o allexport
    echo "Running tests"
    git --version | grep "2.42.0"
  '';

  # https://devenv.sh/services/
  # services.postgres.enable = true;

  # https://devenv.sh/languages/
  # languages.nix.enable = true;

  # https://devenv.sh/pre-commit-hooks/
  # pre-commit.hooks.shellcheck.enable = true;

  # https://devenv.sh/processes/
  # processes.ping.exec = "ping example.com";

  # See full reference at https://devenv.sh/reference/options/
}
