{ config, self, ... }: let
  inherit (config.networking) domain;

  fqdn = "mail1.${domain}";
in {
  imports = [(self + /modules/mail)];

  mailserver = {
    inherit fqdn;

    stateVersion = 3;
  };
}
