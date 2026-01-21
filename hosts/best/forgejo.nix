{ self, config, lib, ... }: let
  inherit (config.networking) domain;
  inherit (lib) const enabled genAttrs head merge;

  fqdn = "git.${domain}";
  port = 8001;
in {
  imports = [
    (self + /modules/nginx.nix)
    (self + /modules/postgresql.nix)
  ];

  secrets.forgejoPasswordMail = {
    file  = self + /modules/mail/password.plain.age;
    owner = "forgejo";
  };

  services.postgresql.ensure = [ "forgejo" ];

  services.restic.backups = genAttrs config.services.restic.hosts <| const {
    paths   = [ "/var/lib/forgejo" ];
    exclude = [ "/var/lib/forgejo/data/repo-archive"];
  };

  services.openssh.settings.AcceptEnv = [ "GIT_PROTOCOL" ];

  services.forgejo = enabled {
    lfs = enabled;

    secrets.mailer.PASSWD = config.secrets.forgejoPasswordMail.path;

    database = {
      socket = "/run/postgresql";
      type   = "postgres";
    };

    settings = let
      description = "RGBCube's Forge of Shitty Software";
    in {
      default.APP_NAME = description;

      attachment.ALLOWED_TYPES = "*/*";

      cache.ENABLED = true;

      # AI scrapers can go to hell.
      "cron.archive_cleaup" = let
        interval = "4h";
      in {
        SCHEDULE   = "@every ${interval}";
        OLDER_THAN =           interval;
      };

      mailer = {
        ENABLED = true;

        PROTOCOL  = "smtps";
        SMTP_ADDR = self.disk.mailserver.fqdn;
        USER      = "git@${domain}";
      };

      other = {
        SHOW_FOOTER_TEMPLATE_LOAD_TIME = false;
        SHOW_FOOTER_VERSION            = false;
      };

      packages.ENABLED = false;

      repository = {
        DEFAULT_BRANCH      = "master";
        DEFAULT_MERGE_STYLE = "rebase-merge";
        DEFAULT_REPO_UNITS  = "repo.code, repo.issues, repo.pulls";

        DEFAULT_PUSH_CREATE_PRIVATE = false;
        ENABLE_PUSH_CREATE_ORG      = true;
        ENABLE_PUSH_CREATE_USER     = true;

        DISABLE_STARS = true;
      };

      "repository.upload" = {
        FILE_MAX_SIZE = 100;
        MAX_FILES     = 10;
      };

      server = {
        DOMAIN       = domain;
        ROOT_URL     = "https://${fqdn}/";
        LANDING_PAGE = "/explore";

        HTTP_ADDR = "::1";
        HTTP_PORT = port;

        SSH_PORT = head config.services.openssh.ports;

        DISABLE_ROUTER_LOG = true;
      };

      service.DISABLE_REGISTRATION = true;

      session = {
        COOKIE_SECURE = true;
        SAME_SITE     = "strict";
      };

      "ui.meta" = {
        AUTHOR      = description;
        DESCRIPTION = description;
      };
    };
  };

  services.nginx.virtualHosts.${fqdn} = merge config.services.nginx.sslTemplate {
    extraConfig = config.services.plausible.extraNginxConfigFor fqdn;

    locations."/".proxyPass = "http://[::1]:${toString port}";
  };
}
