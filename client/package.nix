flake:
{ config, lib, pkgs, ... }:
let
  cfg = config.services.relago-website;

  defaultPkg = flake.packages.${pkgs.stdenv.hostPlatform.system}.default;

  site = cfg.package;
in
{
  options.services.relago-website = with lib; {
    enable = mkEnableOption "Relago website (static SPA served by nginx)";

    domain = mkOption {
      type = types.str;
      example = "relago.uz";
      description = "Primary domain name.";
    };

    aliases = mkOption {
      type = with types; listOf str;
      default = [ ];
      example = [ "www.relago.uz" ];
      description = "Additional server names.";
    };

    package = mkOption {
      type = types.package;
      default = defaultPkg;
      description = "Static site package to serve as nginx root ($out contains index.html).";
    };
  };

  config = lib.mkIf cfg.enable {
    services.nginx.enable = true;
    services.nginx.recommendedGzipSettings = true;
    services.nginx.recommendedOptimisation = true;

    services.nginx.virtualHosts."${cfg.domain}" = {
      serverAliases = cfg.aliases;
      root = site;

      locations."/" = {
        extraConfig = ''
          try_files $uri $uri/ /index.html;
        '';
      };

      locations."~* \\.(?:css|js|mjs|map|png|jpg|jpeg|gif|svg|ico|webp|avif|woff2?)$" = {
        extraConfig = ''
          expires 30d;
          add_header Cache-Control "public, max-age=2592000, immutable" always;
        '';
      };

      extraConfig = ''
        add_header X-Content-Type-Options "nosniff" always;
        add_header X-Frame-Options "DENY" always;
        add_header Referrer-Policy "strict-origin-when-cross-origin" always;
        add_header Permissions-Policy "geolocation=(), microphone=(), camera=()" always;
      '';
    };
  };
}
