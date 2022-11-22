{ config, pkgs, lib, ... }:

with builtins;

let
  cfg = config.services.eviction_tracker;

  serveApp = import ../serve_app.nix {
    listen = "${cfg.address}:${toString cfg.port}";
    tmpdir = "/tmp";
    inherit (config.nixpkgs.localSystem) system;
  };

  staticFiles = import ../static_files.nix { };

  evictionTrackerConfig = pkgs.writeScriptBin "eviction_tracker-config" ''
    systemctl cat eviction_tracker.service | grep X-ConfigFile | cut -d"=" -f2
  '';

  evictionTrackerShowConfig = pkgs.writeScriptBin "eviction_tracker-show-config" ''
    cat `${evictionTrackerConfig}/bin/eviction_tracker-config`
  '';

in {
  options.services.eviction_tracker = with lib; {

    enable = mkEnableOption "Enable the eviction tracking website";

    user = mkOption {
      type = types.str;
      default = "eviction_tracker";
      description = "User to run eviction_tracker.";
    };

    group = mkOption {
      type = types.str;
      default = "eviction_tracker";
      description = "Group to run eviction_tracker.";
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

  };

  config = lib.mkIf cfg.enable {

    services.eviction_tracker.app = serveApp;
    services.eviction_tracker.staticFiles = staticFiles;

    environment.systemPackages = [ evictionTrackerConfig evictionTrackerShowConfig ];

    users.users.eviction_tracker = {
      isSystemUser = true;
      group = cfg.group;
    };
    users.groups.${cfg} = { };

    systemd.services.eviction_tracker = {

      description = "Eviction tracking in Davidson Co.";
      after = [ "network.target" "postgresql.service" ];
      wantedBy = [ "multi-user.target" ];
      stopIfChanged = false;

      serviceConfig = {
        User = cfg.user;
        Group = cfg.group;
        ExecStart = "${serveApp}/bin/serve";
        RuntimeDirectory = "/srv/within/eviction_tracker";
        StateDirectory = "srv/within/eviction_tracker";
        RestartSec = "5s";
        Restart = "always";
        X-ConfigFile = configInput;
        X-App = serveApp;
        X-StaticFiles = staticFiles;

        DeviceAllow = [
          "/dev/stderr"
          "/dev/stdout"
        ];

        AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ];
        CapabilityBoundingSet = [ "CAP_NET_BIND_SERVICE" ];
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
        RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" ];
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
          "https://github.com/red-door-collective/eviction-tracker"
          "https://reddoorcollective.org"
        ];
      };
    };

  };
}