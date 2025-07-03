{ self, config, lib, pkgs, ... }: let
  inherit (config.networking) domain;
  inherit (lib) enabled merge;

  fqdnS3  = "s3.${domain}";
  fqdnWeb = "cdn.${domain}";
  portS3  = 8003;
  portWeb = 8004;
  portRpc = 8005;
in {
  imports = [(self + /modules/nginx.nix)];

  secrets.garageEnvironment.file  = ./environment.age;

  services.garage = enabled {
    package = pkgs.garage_1;

    environmentFile = config.secrets.garageEnvironment.path;

    settings = {
      data_dir = [{
        capacity = "2T";
        path     = "/var/lib/garage/data";
      }];

      replication_factor = 1; # TODO: Expand.
      consistency_mode   = "consistent";

      metadata_fsync = true;
      data_fsync     = true;

      rpc_bind_addr   = "[::]:${toString portRpc}";

      s3_api = {
        s3_region = "garage";

        api_bind_addr = "[::1]:${toString portS3}";
        root_domain   = fqdnS3;
      };

      s3_web = {
        bind_addr = "[::1]:${toString portWeb}";
        root_domain   = fqdnWeb;
      };
    };
  };

  services.nginx.virtualHosts.${fqdnS3} = merge config.services.nginx.sslTemplate {
    extraConfig = /* nginx */ ''
      client_max_body_size 5g;
    '';

    locations."/".proxyPass = "http://[::1]:${toString portS3}";
  };
}
