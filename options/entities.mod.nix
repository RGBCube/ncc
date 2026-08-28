{ lib, ... }:
let
  inherit (lib.options) mkEnableOption mkOption;
  inherit (lib.types)
    lazyAttrsOf
    bool
    listOf
    port
    str
    submodule
    ;
in
{
  options.flake.people = mkOption {
    type =
      lazyAttrsOf
      <| submodule (
        { name, ... }:
        {
          options = {
            name = mkOption {
              type = str;
              default = name;
              description = "Display name.";
            };

            email = mkOption {
              type = str;
              description = "Primary email address.";
            };

            admin = mkOption {
              type = bool;
              default = false;
              description = "Whether this person is an administrator.";
            };

            ssh.key = mkOption {
              type = str;
              description = "SSH public key.";
            };

            fido2-credentials = mkOption {
              type = listOf str;
              default = [ ];
              description = "PAM U2F credentials.";
            };
          };
        }
      );
    default = { };
    description = "People?";
  };

  options.flake.machines = mkOption {
    type =
      lazyAttrsOf
      <| submodule (
        { name, ... }:
        {
          options = {
            ip = {
              addresses4 = mkOption {
                type = listOf str;
                default = [ ];
                description = "IPv4 addresses.";
              };

              addresses6 = mkOption {
                type = listOf str;
                default = [ ];
                description = "IPv6 addresses.";
              };
            };

            ssh = {
              key = mkOption {
                type = str;
                description = "SSH host public key.";
              };

              enable = mkEnableOption "an SSH client entry for this machine";

              user = mkOption {
                type = str;
                default = "root";
                description = "SSH login user.";
              };

              hostName = mkOption {
                type = str;
                default = name;
                description = "SSH destination hostname.";
              };

              port = mkOption {
                type = port;
                default = 2222;
                description = "SSH destination port.";
              };
            };
          };
        }
      );
    default = { };
    description = "Machines?";
  };
}
