{
  config,
  pkgs,
  lib,
  ...
}:
with builtins; let
  cfg = config.services.red-door-collective.rdc-website;

  configFilename = "config.json";

  configInput =
    pkgs.writeText configFilename
    (toJSON (cfg.staticConfig // cfg.extraConfig));

  environmentVariables =
    lib.concatStringsSep " "
    (lib.mapAttrsToList (name: value: "${name}=${toString value}") cfg.environmentVariables);

  serveApp = pkgs.rdc-website-serve-app.override {
    appConfigFile = "/run/rdc-website/${configFilename}";
    listen = "${cfg.address}:${toString cfg.port}";
    tmpdir = "/tmp";
    inherit (config.nixpkgs.localSystem) system;
  };

  rdcWebsiteConfig = pkgs.writeScriptBin "rdc-website-config" ''
    systemctl cat rdc-website.service | grep X-ConfigFile | cut -d"=" -f2
  '';

  rdcWebsiteShowConfig = pkgs.writeScriptBin "rdc-website-show-config" ''
    cat `${rdcWebsiteConfig}/bin/rdc-website-config`
  '';

  rdcWebsiteConsole = pkgs.writeScriptBin "rdc-website-console" ''
    export `${rdcShowEnvVars}`
    ${serveApp}/bin/console
  '';

  rdcShowEnvVars = pkgs.writeScriptBin "rdc-show-env-vars" ''
    pid=$(systemctl show --property MainPID --value rdc-website.service)
    strings "/proc/$pid/environ"
  '';
in {
  options.services.red-door-collective.rdc-website = with lib; {
    enable = mkEnableOption "Enable the website of Red Door Collective";

    debug = mkOption {
      type = types.bool;
      default = false;
      description = ''
        (UNSAFE) Activate debugging mode for this module.
        Currently shows how secrets are replaced in the pre-start script.
      '';
    };

    user = mkOption {
      type = types.str;
      default = "rdc_website";
      description = "User to run rdc-website.";
    };

    group = mkOption {
      type = types.str;
      default = "red_door_collective";
      description = "Group to run rdc-website.";
    };

    port = mkOption {
      type = types.int;
      default = 10000;
      description = "Port for gunicorn app server";
    };

    address = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "Address for gunicorn app server";
    };

    environmentVariables = mkOption {
      type = types.attrs;
      default = {
        VERSION = cfg.version;
        ROLLBAR_CLIENT_TOKEN = "dev";
        FLASK_RUN_PORT = cfg.flaskPort;
        PROMETHEUS_MULTIPROC_DIR = cfg.metricsDirectory;
        METRICS_PORT = cfg.metricsPort;
      };
      description = "Override the default environment variables";
    };

    metricsPort = mkOption {
      type = types.int;
      default = 9200;
      description = "Port for metrics collection";
    };

    version = mkOption {
      type = types.str;
      default = "dev";
      description = "Git revision";
    };

    flaskPort = mkOption {
      type = types.int;
      default = 5001;
      description = "Port for flask app";
    };

    metricsDirectory = mkOption {
      internal = true;
      type = types.str;
      default = "/run/rdc-website";
      description = "Where to store metrics for the prometheus-client";
    };

    configFile = mkOption {
      internal = true;
      type = with types; nullOr path;
      default = null;
    };

    staticFiles = mkOption {
      internal = true;
      type = with types; nullOr path;
      default = null;
    };

    app = mkOption {
      internal = true;
      type = with types; nullOr path;
      default = null;
    };

    secretFiles = mkOption {
      type = types.attrs;
      default = {};
      description = ''
        Arbitrary secrets that should be read from a file and
        inserted in the config on startup. Expects an attrset with
        the variable name to replace and a file path to the secret.
      '';
      example = {
        some_secret_api_key = "/var/lib/rdc-website/some-secret-api-key";
      };
    };

    staticConfig = mkOption {
      internal = true;
      type = types.attrs;
      default = {
        DATA_DIR = "./data";
        DEBUG = cfg.debug;
        ENV = "production";
        FLASK_APP = "rdc_website.app";
        FLASK_DEBUG = cfg.debug;
        MAIL_DEBUG = cfg.debug;
        MAIL_USE_SSL = false;
        MAIL_USE_TLS = true;
        SECURITY_AUTO_LOGIN_AFTER_CONFIRM = false;
        SECURITY_CHANGEABLE = true;
        SECURITY_CONFIRMABLE = true;
        SECURITY_CONFIRM_ERROR_VIEW = "/confirm-error";
        SECURITY_CSRF_COOKIE = {key = "XSRF-TOKEN";};
        # SECURITY_CSRF_COOKIE_NAME = "XSRF-TOKEN";
        SECURITY_CSRF_IGNORE_UNAUTH_ENDPOINTS = true;
        SECURITY_CSRF_PROTECT_MECHANISMS = ["session" "basic"];
        SECURITY_FLASH_MESSAGES = false;
        SECURITY_POST_CONFIRM_VIEW = "/confirmed";
        SECURITY_RECOVERABLE = true;
        SECURITY_REDIRECT_BEHAVIOR = "spa";
        SECURITY_REDIRECT_HOST = "reddoorcollective.org";
        SECURITY_RESET_ERROR_VIEW = "/reset-password";
        SECURITY_RESET_VIEW = "/reset-password";
        SECURITY_TRACKABLE = true;
        SECURITY_URL_PREFIX = "/api/v1/accounts";
        SQLALCHEMY_TRACK_MODIFICATIONS = false;
        SQLALCHEMY_ENGINE_OPTIONS = {
          pool_pre_ping = true;
        };
        WTF_CSRF_CHECK_DEFAULT = false;
        WTF_CSRF_TIME_LIMIT = null;
      };
      description = "Values in the config file that are not typically overridden";
    };

    extraConfig = mkOption {
      type = types.attrs;
      default = {};
      description = "Additional config options given as attribute set.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.red-door-collective.rdc-website.configFile = configInput;
    services.red-door-collective.rdc-website.app = serveApp;
    services.red-door-collective.rdc-website.staticFiles = pkgs.rdc-website-static;

    environment.systemPackages = [
      rdcWebsiteConfig
      rdcWebsiteShowConfig
      rdcWebsiteConsole
      rdcShowEnvVars
    ];

    users.users.rdc_website = {
      isSystemUser = true;
      group = "red_door_collective";
    };
    users.groups.red_door_collective = {};

    systemd.services.rdc-website = {
      description = "Eviction court data in Davidson county";
      after = ["network.target" "postgresql.service"];
      wantedBy = ["multi-user.target"];
      stopIfChanged = false;

      preStart = let
        replaceDebug = lib.optionalString cfg.debug "-vv";
        secrets = cfg.secretFiles;
        replaceSecret = file: var: secretFile: "${pkgs.replace}/bin/replace-literal -m 1 ${replaceDebug} -f -e @${var}@ \"$(< ${secretFile})\" ${file}";
        replaceCfgSecret = var: secretFile: replaceSecret "$cfgdir/${configFilename}" var secretFile;
        secretReplacements = lib.mapAttrsToList (k: v: replaceCfgSecret k v) cfg.secretFiles;
      in ''
        echo "Prepare config file..."
        cfgdir=$RUNTIME_DIRECTORY
        chmod u+w -R $cfgdir
        cp ${configInput} $cfgdir/${configFilename}

        ${lib.concatStringsSep "\n" secretReplacements}

        echo "Run database migrations if needed..."
        ${serveApp}/bin/migrate
        echo "Pre-start finished."
      '';

      serviceConfig = {
        User = cfg.user;
        Group = cfg.group;
        ExecStart = "${serveApp}/bin/rdc-website-serve-app";
        RuntimeDirectory = "rdc-website";
        StateDirectory = "rdc-website";
        RestartSec = "5s";
        Restart = "always";
        X-ConfigFile = configInput;
        X-App = serveApp;
        X-StaticFiles = cfg.staticFiles;
        Environment = environmentVariables;

        DeviceAllow = [
          "/dev/stderr"
          "/dev/stdout"
        ];

        AmbientCapabilities = ["CAP_NET_BIND_SERVICE"];
        CapabilityBoundingSet = ["CAP_NET_BIND_SERVICE"];
        DevicePolicy = "strict";
        LockPersonality = true;
        NoNewPrivileges = true;
        PrivateDevices = true;
        PrivateTmp = true;
        PrivateUsers = true;
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectHome = true;
        ProtectHostname = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectSystem = "strict";
        RemoveIPC = true;
        RestrictAddressFamilies = ["AF_INET" "AF_INET6" "AF_UNIX"];
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        SyslogIdentifier = "rdc-website";
        SystemCallArchitectures = "native";
        SystemCallFilter = [
          # deny the following syscall groups
          "~@clock"
          "~@debug"
          "~@module"
          "~@mount"
          "~@reboot"
          "~@cpu-emulation"
          "~@swap"
          "~@obsolete"
          "~@resources"
          "~@raw-io"
        ];
        UMask = "077";
      };

      unitConfig = {
        Documentation = [
          "https://github.com/red-door-collective/rdc-website"
        ];
      };
    };
  };
}
