{ self, config, lib, ... }: let
  inherit (config.networking) domain;
  inherit (lib) const enabled genAttrs head mkDefault;
in {
  imports = [(self + /modules/acme)];

  secrets.mailPassword.file = ./password.hash.age;
  secrets.mailSupercellPassword.file = ./password-supercell.hash.age;

  services.prometheus.exporters.postfix = enabled {
    listenAddress = "[::]";
  };

  services.restic.backups = genAttrs config.services.restic.hosts <| const {
    paths = [ config.mailserver.dkimKeyDirectory config.mailserver.mailDirectory ];
  };

  security.acme.users = [ "mail" ];

  mailserver = enabled {
    domains           = mkDefault [ domain ];
    x509.useACMEHost = head config.mailserver.domains;

    # We use systemd-resolved instead of Knot Resolver.
    localDnsResolver = false;

    hierarchySeparator = "/";
    useFsLayout        = true;

    dkimKeyDirectory = "/var/lib/dkim";
    mailDirectory    = "/var/lib/mail";
    sieveDirectory   = "/var/lib/sieve";

    vmailUserName  = "mail";
    vmailGroupName = "mail";

    # The mailserver at <turkiye.gov> malfunctions.
    # dmarcReporting = enabled {
    #   domain = head config.mailserver.domains;

    #   organizationName = "Doofemshmirtz Evil Inc.";
    # };

    fullTextSearch = enabled;

    loginAccounts."contact@${head config.mailserver.domains}" = {
      aliases = [ "@${head config.mailserver.domains}" ];

      hashedPasswordFile = config.secrets.mailPassword.path;
    };

    loginAccounts."supercell@${head config.mailserver.domains}" = {
      hashedPasswordFile = config.secrets.mailSupercellPassword.path;
    };
  };
}
