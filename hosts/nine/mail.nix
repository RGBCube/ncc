{ config, self, ... }: let
  inherit (config.networking) domain;

  fqdn = "mail2.${domain}";
in {
  imports = [(self + /modules/mail)];

  mailserver = {
    inherit fqdn;

    # Not [ domain ] because this is a backup mailserver. contact@mail2.rgbcu.be.
    domains = [ fqdn ];

    stateVersion = 3;
  };
}
