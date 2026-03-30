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
      description = "Relago-support user";
      isSystemUser = true;
      group = cfg.group;
    };

    users.groups.${cfg.group} = { };

    systemd.services."${packageName}" = {
      description = "Welcome to ${packageName} ";
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        User = cfg.user;
        Group = cfg.group;
        ExecStart = "${lib.getBin package}/bin/${packageName}";

        Restart = "always";

        DevicePolicy = "closed";
        KeyringMode = "private";
        LockPersonality = "yes";
        MemoryDenyWriteExecute = "yes";
        NoNewPrivileges = "yes";
        PrivateDevices = "yes";
        PrivateTmp = "true";
        ProtectClock = "yes";
        ProtectControlGroups = "yes";
        ProtectHome = "read-only";
        ProtectHostname = "yes";
        ProtectKernelLogs = "yes";
        ProtectKernelModules = "yes";
        ProtectKernelTunables = "yes";
        ProtectProc = "invisible";
        ProtectSystem = "full";
        RestrictNamespaces = "yes";
        RestrictRealtime = "yes";
        RestrictSUIDSGID = "yes";
        SystemCallArchitectures = "native";
      };
    };
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

      port = mkOption {
        type = types.int;
        default = 4242;
        description = lib.mdDoc ''
          The port ${packageName} listen.
        '';
      };

      user = mkOption {
        type = types.str;
        default = "relago-support";
        description = "User for running system + access keys";
      };

      group = mkOption {
        type = types.str;
        default = "relago-support";
        description = "Group for running system + acess keys";
      };
    };
  };
  config = mkMerge [ service ];
}
