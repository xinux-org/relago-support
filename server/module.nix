flake:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkOption
    mkIf
    mkMerge
    types
    ;

  package = flake.packages.${pkgs.stdenv.hostPlatform.system}.server;
  packageName = package.pname;
  cfg = config.services.${packageName};

  caddy = lib.mkIf (cfg.enable && cfg.proxy.enable && cfg.proxy.proxy == "caddy") {
    services.caddy.virtualHosts =
      lib.debug.traceIf (isNull cfg.proxy.domain)
        "proxy.domain can't be null, please specicy it properly!"
        {
          "${cfg.proxy.domain}" = {
            serverAliases = cfg.proxy.aliases;
            extraConfig = ''
              reverse_proxy 127.0.0.1:${toString cfg.port}
            '';
          };
        };
  };

  nginx = lib.mkIf (cfg.enable && cfg.proxy.enable && cfg.proxy.proxy == "nginx") {
    services.nginx.virtualHosts =
      lib.debug.traceIf (isNull cfg.proxy.domain)
        "proxy.domain can't be null, please specify it properly!"
        {
          "${cfg.proxy.domain}" = {
            addSSL = true;
            enableACME = true;
            serverAliases = cfg.proxy.aliases;
            locations."/" = {
              proxyPass = "http://127.0.0.1:${toString cfg.port}";
              proxyWebsockets = true;
            };
          };
        };
  };

  service = mkIf cfg.enable {
    users.users.${cfg.user} = {
      description = "relago-server user";
      isSystemUser = true;
      group = cfg.group;
      home = cfg.dataDir;
      useDefaultShell = true;
    };

    users.groups.${cfg.group} = { };

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0770 ${cfg.user} ${cfg.group} -"
      "d ${cfg.tmpDir}  0770 ${cfg.user} ${cfg.group} -"
    ];

    systemd.targets."relago-server" = { };

    systemd.services."relago-server-config" = {
      wantedBy = [ "relago-server.target" ];
      after = [ "systemd-tmpfiles-setup.service" ];
      requires = [ "systemd-tmpfiles-setup.service" ];

      serviceConfig = {
        Type = "oneshot";
        User = cfg.user;
        Group = cfg.group;
        Restart = "always";
        RestartSec = "2s";
        RemainAfterExit = true;

        ExecStartPre =
          let
            preStartFullPrivileges = ''
              set -o errexit -o pipefail -o nounset
              mkdir -p ${cfg.dataDir} ${cfg.tmpDir}
              ${pkgs.coreutils}/bin/install -d -m 0770 -o ${cfg.user} -g ${cfg.group} ${cfg.dataDir}
              ${pkgs.coreutils}/bin/install -d -m 0770 -o ${cfg.user} -g ${cfg.group} ${cfg.tmpDir}
            '';
          in
          "+${pkgs.writeShellScript "${packageName}-pre-start-full-privileges" preStartFullPrivileges}";

        ExecStart = pkgs.writeShellScript "${packageName}-config" ''
          set -o errexit -o pipefail -o nounset
          shopt -s inherit_errexit
          umask u=rwx,g=rx,o=
          ${pkgs.coreutils}/bin/install -m 0640 -o ${cfg.user} -g ${cfg.group} \
            ${toml-config} ${cfg.dataDir}/config.toml
        '';
      };
    };

    systemd.services.relago-server = {
      description = "Welcome to relago-server";

      # environment = {
      #   PORT = "${toString cfg.port}";
      #   HOSTNAME = cfg.host;
      # };

      after = [
        "network-online.target"
        "relago-server-config.service"
      ];
      requires = [
        "relago-server-config.service"
      ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      # path = [ cfg.package ];
      restartTriggers = [
        cfg.package
        toml-config
      ];

      serviceConfig = {
        User = cfg.user;
        Group = cfg.group;
        Restart = "always";

        ExecStart = "${lib.getBin package}/bin/${packageName} -c ${toml-config}";
        ExecReload = "${pkgs.coreutils}/bin/kill -s HUP $MAINPID";

        StateDirectory = cfg.user;
        StateDirectoryMode = "0770";

        CapabilityBoundingSet = [
          "AF_NETLINK"
          "AF_INET"
          "AF_INET6"
        ];
        DeviceAllow = [ "/dev/stdin r" ];
        DevicePolicy = "strict";
        # IPAddressAllow = "localhost";
        LockPersonality = true;
        PrivateDevices = true;
        PrivateTmp = true;
        PrivateUsers = false;
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectHome = true;
        ProtectHostname = true;
        ProtectKernelLogs = true;
        ProtectKernelTunables = true;
        ProtectSystem = "strict";
        ReadOnlyPaths = [ "/" ];
        RemoveIPC = true;
        RestrictAddressFamilies = [
          "AF_NETLINK"
          "AF_INET"
          "AF_INET6"
          "AF_UNIX"
        ];
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        SystemCallArchitectures = "native";
        SystemCallFilter = [
          "@system-service"
          "~@privileged"
          "~@resources"
          "@pkey"
        ];
        UMask = "0022";
      };
    };
  };

  toml = pkgs.formats.toml { };

  toml-config = toml.generate "config.toml" {
    dataDir = cfg.tmpDir;
    port = cfg.port;
  };

  asserts = lib.mkIf cfg.enable {
    warnings = [
      (lib.mkIf (
        cfg.proxy.enable && cfg.proxy.domain == null
      ) "services.relago-server.proxy.domain must be set in order to properly generate certificate!")
    ];
  };
in
{
  options = with lib; {
    services.relago-server = {
      enable = mkEnableOption ''
        ${packageName} running.
      '';

      proxy = {
        enable = mkEnableOption ''
          Proxy reversed method of deployment
        '';

        domain = mkOption {
          type = with types; nullOr str;
          default = null;
          example = "cocomelon.uz";
          description = "Domain to use while adding configurations to web proxy server";
        };

        aliases = mkOption {
          type = with types; listOf str;
          default = [ ];
          example = [ "www.cocomelon.uz" ];
          description = "List of domain aliases to add to domain";
        };

        proxy = mkOption {
          type =
            with types;
            nullOr (enum [
              "nginx"
              "caddy"
            ]);
          default = "caddy";
          description = "Proxy reverse software for hosting website";
        };
      };

      host = mkOption {
        type = types.str;
        default = "127.0.0.1";
        description = "Hostname for relago server to bind";
      };

      port = mkOption {
        type = types.int;
        default = 42424;
        description = "Port to use for passing over proxy";
      };

      user = mkOption {
        type = types.str;
        default = "relago-server";
        description = "User for running system + access keys";
      };

      group = mkOption {
        type = types.str;
        default = "relago-server";
        description = "Group for running system + acess keys";
      };

      dataDir = mkOption {
        type = types.str;
        default = "/var/lib/relago-server";
        description = lib.mdDoc ''
          The path where relago-server keeps its config, data, and logs.
        '';
      };

      tmpDir = mkOption {
        type = types.str;
        default = "/var/lib/relago-server/tmp";
        description = lib.mdDoc ''
          The path where relago-server keeps its tmp files.
        '';
      };

      package = mkOption {
        type = types.package;
        default = package;
        description = ''
          Compiled relago-server package to use with the service.
        '';
      };
    };
  };
  config = mkMerge [
    asserts
    service
    caddy
    nginx
  ];
}
