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

  service = mkIf cfg.enable {
    users.users.${cfg.user} = {
      description = "${packageName} user";
      isSystemUser = true;
      group = cfg.group;
      home = cfg.dataDir;
      useDefaultShell = true;
    };

    users.groups.${cfg.group} = { };

    systemd.services."${packageName}-config" = {
      wantedBy = [ "${packageName}.target" ];
      partOf = [ "${packageName}.target" ];

      serviceConfig = {
        Type = "oneshot";
        User = cfg.user;
        Group = cfg.group;
        TimeoutSec = "infinity";
        Restart = "on-failure";
        WorkingDirectory = "${cfg.dataDir}";
        RemainAfterExit = true;

        ExecStartPre =
          let
            preStartFullPrivileges = ''
              set -o errexit -o pipefail -o nounset
              shopt -s dotglob nullglob inherit_errexit

              chown -R --no-dereference '${cfg.user}':'${cfg.group}' '${cfg.dataDir}'
              chmod -R u+rwX,g+rX,o-rwx '${cfg.dataDir}'
            '';
          in
          "+${pkgs.writeShellScript "${packageName}-pre-start-full-privileges" preStartFullPrivileges}";

        ExecStart = pkgs.writeShellScript "${packageName}-config" ''
          set -o errexit -o pipefail -o nounset
          shopt -s inherit_errexit

          umask u=rwx,g=rx,o=

          # Write configuration file for server
          cp -f ${toml-config} ${cfg.dataDir}/config.toml
        '';
      };
    };

    systemd.services."${packageName}" = {
      description = "Welcome to ${packageName}";

      wantedBy = [ "multi-user.target" ];
      after = [
        "network.target"
        "${packageName}-config.service"
      ];
      wants = [ "network-online.target" ];
      path = [ cfg.package ];

      serviceConfig = {
        User = cfg.user;
        Group = cfg.group;
        Restart = "always";

        ExecStart = "${lib.getBin package}/bin/${packageName} -c ${toml-config}";
        ExecReload = "${pkgs.coreutils}/bin/kill -s HUP $MAINPID";

        StateDirectory = cfg.user;
        StateDirectoryMode = "0750";

        CapabilityBoundingSet = [
          "AF_NETLINK"
          "AF_INET"
          "AF_INET6"
        ];
        DeviceAllow = [ "/dev/stdin r" ];
        DevicePolicy = "strict";
        IPAddressAllow = "localhost";
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
        UMask = "0027";
      };
    };
  };

  toml = pkgs.formats.toml { };

  toml-config = toml.generate "config.toml" {
    dataDir = cfg.tmpDir;
    port = cfg.port;
  };
in
{
  options = with lib; {
    services.${packageName} = {
      enable = mkEnableOption ''
        ${packageName} running.
      '';

      # dataDir = mkOption {
      #   type = types.str;
      #   default = "/var/lib/${packageName}";
      #   description = lib.mdDoc ''
      #     The path where ${packageName} keeps its config, data, and logs.
      #   '';
      # };

      user = mkOption {
        type = types.str;
        default = "${packageName}";
        description = "User for running system + access keys";
      };

      group = mkOption {
        type = types.str;
        default = "${packageName}";
        description = "Group for running system + acess keys";
      };

      dataDir = mkOption {
        type = types.str;
        default = "/var/lib/${packageName}";
        description = lib.mdDoc ''
          The path where ${packageName} keeps its config, data, and logs.
        '';
      };

      tmpDir = mkOption {
        type = types.str;
        default = "/var/lib/${packageName}/tmp";
        description = lib.mdDoc ''
          The path where ${packageName} keeps its tmp files.
        '';
      };

      port = mkOption {
        type = types.int;
        default = 4242;
        description = lib.mdDoc ''
          The port ${packageName} listen.
        '';
      };

      package = mkOption {
        type = types.package;
        default = package;
        description = ''
          Compiled ${packageName} package to use with the service.
        '';
      };
    };
  };
  config = mkMerge [ service ];
}
