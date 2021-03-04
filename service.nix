{ config, lib, pkgs, ... }:

with lib;

let
    pythonEnv = (import ./nix/python.nix).env.python3.buildEnv.override {
        extraLibs = [
            pkgs.python37Packages.gunicorn
            pkgs.python37Packages.gevent
        ];
    };
    eviction-tracker = pkgs.callPackage ./default.nix {};

    cfg = config.within.services.eviction-tracker;

in {
    options.within.services.eviction-tracker = {
        enable = mkEnableOption "Starts court data site";
        useACME = mkEnableOption "Enables ACME for cert stuff";

        port = mkOption {
            type = types.port;
            default = 32837;
            example = 9001;
            description = "The port number eviction-tracker should listen on for HTTP traffic";
        };

        domain = mkOption {
            type = types.str;
            default = "detainer-warrants.info";
            example = "detainer-warrants.info";
            description =
                "The domain name that nginx should check against for HTTP hostnames";
        };
    };

    config = lib.mkIf cfg.enable {

        users.users.eviction-tracker = {
            createHome = true;
            description = "github.com/thebritican/eviction-tracker";
            isSystemUser = true;
            group = "within";
            home = "/srv/within/eviction-tracker";
            extraGroups = [ "keys" ];
        };

        within.secrets.eviction-tracker = {
            source = ./secrets/eviction-tracker.env;
            dest = "/srv/within/eviction-tracker/.env";
            owner = "eviction-tracker";
            group = "within";
            permissions = "0400";
        };

        networking.firewall.allowedTCPPorts = [ cfg.port ];

        systemd.services.eviction-tracker = {
            description = "A webapp that presents and verifies court data";
            environment = {
                PYTHONUNBUFFERED = "1";
                ENVIRONMENT = "production";
            };

            after = [ "network.target" ];
            wantedBy = [ "network.target" ];

            serviceConfig = {
                User = "xesite";
                Group = "within";
                Restart = "on-failure";
                WorkingDirectory = "/srv/within/xesite";
                RestartSec = "30s";
                Type = "notify";

                 # Security
                CapabilityBoundingSet = "";
                DeviceAllow = [ ];
                NoNewPrivileges = "true";
                ProtectControlGroups = "true";
                ProtectClock = "true";
                PrivateDevices = "true";
                PrivateUsers = "true";
                ProtectHome = "true";
                ProtectHostname = "true";
                ProtectKernelLogs = "true";
                ProtectKernelModules = "true";
                ProtectKernelTunables = "true";
                ProtectSystem = "true";
                ProtectProc = "invisible";
                RemoveIPC = "true";
                RestrictSUIDSGID = "true";
                RestrictRealtime = "true";
                SystemCallArchitectures = "native";
                SystemCallFilter = [
                "~@reboot"
                "~@module"
                "~@mount"
                "~@swap"
                "~@resources"
                "~@cpu-emulation"
                "~@obsolete"
                "~@debug"
                "~@privileged"
                ];
                UMask = "077";
            };

            script = let site = pkgs.github.com.thebritican.eviction-tracker;
                in ''
                    export $(cat /srv/within/eviction-tracker/.env | xargs)
                    export PORT=${toString cfg.port}
                    export DOMAIN=${toString cfg.domain}
                    cd ${site}
                    exec ${site}/bin/eviction-tracker
                '';
        };

        # Enable nginx service
        services.nginx = {
        enable = true;
        virtualHosts.${dnsName} = {
            default = true;
            locations."/" = {
            proxyPass = "http://0.0.0.0:8080/";
            };
            addSSL = true;
            enableACME = true;
        };
        };
    };
}
