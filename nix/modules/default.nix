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
    (toJSON cfg.extraConfig);

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
      default = "rdc-website";
      description = "User to run rdc-website.";
    };

    group = mkOption {
      type = types.str;
      default = "red-door-collective";
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
    ];

    environment.sessionVariables = {
      LOG_FILE_PATH = "./capture.log";
    };

    users.users.rdc-website = {
      isSystemUser = true;
      group = "red-door-collective";
    };
    users.groups.red-door-collective = {};

    systemd.services.rdc-website = {
      description = "Eviction court data in Davidson county";
      after = ["network.target" "postgresql.service"];
      wantedBy = ["multi-user.target"];
      stopIfChanged = false;

      preStart = let
        replaceDebug = lib.optionalString cfg.debug "-vv";
        secrets = cfg.secretFiles;
        replaceSecret = file: var: secretFile: "${pkgs.replace}/bin/replace-literal -m 1 ${replaceDebug} -f -e @${var}@ $(< ${secretFile}) ${file}";
        replaceCfgSecret = var: secretFile: replaceSecret "$cfgdir/${configFilename}" var secretFile;
        secretReplacements = lib.mapAttrsToList (k: v: replaceCfgSecret k v) cfg.secretFiles;
      in ''
        echo "Prepare config file..."
        cfgdir=$RUNTIME_DIRECTORY
        chmod u+w -R $cfgdir
        cp ${configInput} $cfgdir/${configFilename}

        echo "$cfgdir/${configFilename}"
        echo "${configInput}"

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
