{ config, pkgs, lib, ... }:

with builtins;

let
  cfg = config.services.rdc-website;

  serveApp = import ../serve_app.nix {
    listen = "${cfg.address}:${toString cfg.port}";
    tmpdir = "/tmp";
    inherit (config.nixpkgs.localSystem) system;
  };

  staticFiles = import ../static_files.nix { };

  evictionTrackerConfig = pkgs.writeScriptBin "rdc-website-config" ''
    systemctl cat rdc-website.service | grep X-ConfigFile | cut -d"=" -f2
  '';

  evictionTrackerShowConfig = pkgs.writeScriptBin "rdc-website-show-config" ''
    cat `${evictionTrackerConfig}/bin/rdc-website-config`
  '';

in
{
  options.services.rdc-website = with lib; {

    enable = mkEnableOption "Enable the eviction tracking website";

    user = mkOption {
      type = types.str;
      default = "rdc-website";
      description = "User to run rdc-website.";
    };

    group = mkOption {
      type = types.str;
      default = "rdc-website";
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

  };

  config = lib.mkIf cfg.enable {

    services.red-door-collective.rdc-website.app = serveApp;
    services.red-door-collective.rdc-website.staticFiles = staticFiles;

    environment.systemPackages = [ evictionTrackerConfig evictionTrackerShowConfig ];

    users.users.red-door-collective = {
      isSystemUser = true;
      group = cfg.group;
    };
    users.groups.${cfg} = { };

    systemd.services.red-door-collective.rdc-website = {

      description = "Eviction tracking in Davidson Co.";
      after = [ "network.target" "postgresql.service" ];
      wantedBy = [ "multi-user.target" ];
      stopIfChanged = false;

      serviceConfig = {
        User = cfg.user;
        Group = cfg.group;
        ExecStart = "${serveApp}/bin/serve";
        RuntimeDirectory = "/srv/red-door-collective/rdc-website";
        StateDirectory = "/srv/red-door-collective/rdc-website";
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
          "https://github.com/red-door-collective/rdc-website"
          "https://reddoorcollective.org"
        ];
      };
    };

  };
}
