{ self, config, lib, ... }: let
  inherit (config.networking) domain;
  inherit (lib) const enabled genAttrs merge;

  fqdn = "metrics.${domain}";
  port = 8000;
in {
  imports = [
    (self + /modules/nginx.nix)
    (self + /modules/postgresql.nix)
  ];

  secrets.grafanaPassword = {
    file  = ./password.age;
    owner = "grafana";
  };
  secrets.grafanaPasswordMail = {
    file  = self + /modules/mail/password.plain.age;
    owner = "grafana";
  };

  services.postgresql.ensure = [ "grafana" ];

  services.restic.backups = genAttrs config.services.restic.hosts <| const {
    paths = [ "/var/lib/grafana" ];
  };

  systemd.services.grafana = {
    after    = [ "postgresql.service" ];
    requires = [ "postgresql.service" ];
  };

  services.grafana = enabled {
    provision = enabled;

    settings = {
      analytics.reporting_enabled = false;

      database.host = "/run/postgresql";
      database.type = "postgres";
      database.user = "grafana";

      server.domain    = fqdn;
      server.http_addr = "::1";
      server.http_port = port;

      users.default_theme = "system";
    };

    settings.security = {
      admin_email    = "metrics@${domain}";
      admin_password = "$__file{${config.secrets.grafanaPassword.path}}";
      admin_user     = "admin";

      cookie_secure    = true;
      disable_gravatar = true;

      disable_initial_admin_creation = true; # Just in case.
    };

    settings.smtp = {
      enabled = true;

      password        = "$__file{${config.secrets.grafanaPasswordMail.path}}";
      startTLS_policy = "MandatoryStartTLS";

      ehlo_identity = "metrics@${domain}";
      from_address  = "metrics@${domain}";
      from_name     = "Metrics";
      # host          = "${self.disk.mailserver.fqdn}:${toString self.disk.services.postfix.relayPort}";
      host          = "${self.disk.mailserver.fqdn}:25"; # FIXME TODO
    };
  };

  services.nginx.virtualHosts.${fqdn} = merge config.services.nginx.sslTemplate {
    locations."/" = {
      extraConfig =  /* nginx */ ''
        # Grafana sets `nosniff` while not setting the content type properly,
        # so everything breaks with it. Unset the header.
        proxy_hide_header X-Content-Type-Options;

        ${config.services.plausible.extraNginxConfigFor fqdn}
      '';

      proxyPass       = "http://[::1]:${toString port}";
      proxyWebsockets = true;
    };
  };
}
