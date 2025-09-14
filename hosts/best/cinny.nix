{ config, lib, pkgs, ... }: let
  inherit (lib) merge;
  inherit (lib.strings) toJSON;

  fqdn = "cinny.rgbcu.be";
  root = pkgs.cinny;

  cinnyConfig = {
    allowCustomHomeservers = false;
    homeserverList         = [ "rgbcu.be" ];
    defaultHomeserver      = 0;

    hashRouter = {
      enabled  = false;
      basename = "/";
    };

    featuredCommunities = {
      openAsDefault = false;

      servers = [
        "rgbcu.be"
        "matrix.org"
        "privatevoid.net"
        "notashelf.dev"
        "outfoxxed.me"
      ];

      spaces = [
        "#nixos-fallout:privatevoid.net"
        "#ferronweb:matrix.org"
      ];

      rooms = [
        "#ferronweb-general:matrix.org"
        "#ferronweb-development:matrix.org"
      ];
    };
  };
in {
  services.nginx.virtualHosts.${fqdn} = merge config.services.nginx.sslTemplate {
    inherit root;

    locations."= /config.json".extraConfig = /* nginx */ ''
      default_type application/json;
      return 200 '${toJSON cinnyConfig}';
    '';

    extraConfig = /* nginx */ ''
      rewrite ^/config.json$ /config.json break;
      rewrite ^/manifest.json$ /manifest.json break;

      rewrite ^/sw.js$ /sw.js break;
      rewrite ^/pdf.worker.min.js$ /pdf.worker.min.js break;

      rewrite ^/public/(.*)$ /public/$1 break;
      rewrite ^/assets/(.*)$ /assets/$1 break;

      rewrite ^(.+)$ /index.html break;
    '';
  };
}
