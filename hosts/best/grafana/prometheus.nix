{ self, config, lib, ... }: let
  inherit (lib) enabled filterAttrs flatten mapAttrsToList;
in {
  services.grafana.provision.datasources.settings = {
    datasources = [{
      name = "Prometheus";
      type = "prometheus";
      url  = "http://[::1]:${toString config.services.prometheus.port}";

      orgId = 1;
    }];

    deleteDatasources = [{
      name  = "Prometheus";
      orgId = 1;
    }];
  };

  services.prometheus = enabled {
    listenAddress = "[::]";
    retentionTime = "1w";

    scrapeConfigs = let
      configToScrapeConfig = hostName: { config, ... }: let
        hostConfig = config;
      in hostConfig.services.prometheus.exporters
        |> filterAttrs (exporterName: exporterConfig:
          exporterName != "minio" &&
          exporterName != "unifi-poller" &&
          exporterName != "tor" &&
          exporterName != "rspamd" &&
          exporterConfig.enable or false)
        |> mapAttrsToList (exporterName: exporterConfig: {
          job_name = "${exporterName}-${hostName}";

          static_configs = [{
            targets = [ "${hostName}:${toString exporterConfig.port}" ];
          }];
        });

    in self.nixosConfigurations
      |> mapAttrsToList configToScrapeConfig
      |> flatten;
  };
}
