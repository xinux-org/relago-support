flake: {
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.relago-website;

  defaultPkg = flake.packages.${pkgs.stdenv.hostPlatform.system}.default;

  domain = cfg.proxy.domain;
  site = cfg.package;

  needDomain = cfg.enable && cfg.proxy.enable;
in {
  options.services.relago-website = with lib; {
    enable = mkEnableOption ''
      Relago website.
    '';

    proxy = {
      enable = mkEnableOption ''
        Proxy reversed method of deployment
      '';

      domain = mkOption {
        type = with types; nullOr str;
        default = null;
        example = "reports.xinux.uz";
        description = "Domain to use while adding configuration to web proxy server";
      };

      aliases = mkOption {
        type = with types; listOf str;
        default = [];
        example = ["reports.xinux.uz"];
        description = "Additional server names / aliaes.";
      };

      proxy = mkOption {
        type = with types;
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
      description = "Hostname for nextjs server to bind";
    };

    port = mkOption {
      type = types.int;
      default = 5173;
      description = "Port to use for passing overy proxy";
    };

    user = mkOption {
      type = types.str;
      default = "relago-www";
      description = "User for running system + accessing keys";
    };

    group = mkOption {
      type = types.str;
      default = "relago-www";
      description = "Group for running system + accessing keys";
    };

    dataDir = mkOption {
      type = types.str;
      default = "/var/lib/relago/www";
      description = ''
        The path where Relago Website server keeps data and possibly logs.
      '';
    };

    package = mkOption {
      type = types.package;
      default = server;
      description = ''
        Packaged reports.xinux.uz website contents for service.
      '';
    };
  };
}
