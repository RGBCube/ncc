{
  flake.nixosModules.metrics-exporter = {
    services.prometheus.exporters.node = {
      enable = true;
      enabledCollectors = [
        "processes"
        "systemd"
      ];
      listenAddress = "[::]";
    };
  };

  # TODO: nixosModules.metrics-server (prometheus + grafana)
}
