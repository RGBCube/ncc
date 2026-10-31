{ inputs, lib, ... }:
let
  inherit (lib.attrsets) unionOfDisjoint removeAttrs;
  inherit (lib.lists) singleton;
  inherit (lib.options) mkEnableOption mkOption;
  inherit (lib.trivial) flip;
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
            ip.addresses4 = mkOption {
              type = listOf str;
              default = [ ];
              description = "IPv4 addresses.";
            };

            ip.addresses6 = mkOption {
              type = listOf str;
              default = [ ];
              description = "IPv6 addresses.";
            };

            ssh.enable = mkEnableOption "an SSH client entry for this machine";

            ssh.key = mkOption {
              type = str;
              description = "SSH host public key.";
            };

            ssh.user = mkOption {
              type = str;
              default = "root";
              description = "SSH login user.";
            };

            ssh.hostName = mkOption {
              type = str;
              default = name;
              description = "SSH destination hostname.";
            };

            ssh.port = mkOption {
              type = port;
              default = 2222;
              description = "SSH destination port.";
            };

            builder = mkOption {
              type = submodule {
                options =
                  (import "${inputs.nixpkgs}/nixos/modules/config/nix-remote-build.nix" {
                    config.nix.enable = false;
                    inherit lib;
                  }).options.nix.buildMachines.type.nestedTypes.elemType.getSubOptions
                    [ ]
                  |> flip removeAttrs (singleton "_module")
                  |> unionOfDisjoint {
                    enable = mkEnableOption "this machine as a remote Nix builder";
                  };
              };
              default = { };
              description = "Configuration for this machine as a remote Nix builder.";
            };

          };
        }
      );
    default = { };
    description = "Machines?";
  };
}
