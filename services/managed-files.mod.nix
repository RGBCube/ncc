{ self, ... }:
{
  flake.serviceModules.managed-files =
    {
      config,
      lib,
      name,
      options,
      ...
    }:
    let
      inherit (lib) baseNameOf dirOf toFile;
      inherit (lib.attrsets) filterAttrs mapAttrsToList;
      inherit (lib.lists) optionals singleton;
      inherit (lib.meta) getExe;
      inherit (lib.modules) mkDerivedConfig mkIf;
      inherit (lib.options) mkOption;
      inherit (lib.strings) toJSON;
      inherit (lib.types)
        attrsOf
        enum
        ints
        lines
        nullOr
        package
        path
        str
        submodule
        ;

      cfg = config.managed-files;

      manifestCurrent = config.configData."manifest.json".path;
      manifestNew = toFile "managed-files-${name}.json" (
        {
          version = 3;
          clobber_by_default = true;

          files =
            cfg.files
            |> mapAttrsToList (
              target: file:
              filterAttrs (_: value: value != null) {
                inherit (file)
                  type
                  source
                  permissions
                  uid
                  gid
                  ;
                inherit target;
              }
            );
        }
        |> toJSON
      );

      smfh = getExe cfg.smfh;
    in
    {
      imports = singleton self.serviceModules.base;

      options.managed-files = {
        smfh = mkOption {
          type = package;
          description = "smfh package used to apply the manifest.";
        };

        nushell = mkOption {
          type = package;
          description = "Nushell package used to build the activation script.";
        };

        files = mkOption {
          default = { };
          description = "Managed files.";
          type =
            attrsOf
            <| submodule (
              {
                name,
                config,
                options,
                ...
              }:
              {
                options = {
                  type = mkOption {
                    type = enum [
                      "copy"
                      "symlink"
                      "directory"
                      "delete"
                      "modify"
                    ];
                    default = "copy";
                    description = "Type of path to create.";
                  };

                  text = mkOption {
                    type = nullOr lines;
                    default = null;
                    description = "Text of the file.";
                  };

                  source = mkOption {
                    type = nullOr path;
                    default = null;
                    description = "Path of the source file or directory.";
                  };

                  permissions = mkOption {
                    type = nullOr str;
                    default = null;
                    description = "Permissions (in octal) to set on the target path.";
                  };

                  uid = mkOption {
                    type = nullOr ints.u32;
                    default = null;
                    description = "User ID to set as owner on the target path.";
                  };

                  gid = mkOption {
                    type = nullOr ints.u32;
                    default = null;
                    description = "Group ID to set as owner on the target path.";
                  };
                };

                config.source = mkIf (config.text != null) (
                  mkDerivedConfig options.text (toFile (baseNameOf name))
                );
              }
            );
        };
      };

      config = {
        # We write the "last applied manifest" ourselves, so it cannot be generated declaratively.
        configData."manifest.json".enable = false;

        limits.syscalls = singleton "@system-service";
        limits.capabilities = [
          "CAP_DAC_OVERRIDE"
          "CAP_CHOWN"
          "CAP_FOWNER"
        ];

        files."/" = [
          "read"
          "write"
        ];

        exec.again = "no";
        exec.argv =
          singleton
          <| getExe
          <| cfg.nushell.stdenv.mkDerivation {
            name = "managed-files-${name}";
            meta.mainProgram = "managed-files";

            passAsFile = singleton "text";
            text = /* nu */ ''
              #!${getExe cfg.nushell}
              #

              mkdir ${dirOf manifestCurrent}

              ^${smfh} diff ${manifestNew} ${manifestCurrent} --fallback
              ^${smfh} activate ${manifestNew}

              cp --force ${manifestNew} ${manifestCurrent}
            '';

            phases = singleton "installPhase";
            installPhase = ''
              install -D --mode 755 "$textPath" "$out/bin/managed-files"
            '';
          };

        exec.post.argv = optionals (options ? launchd) [
          "/bin/sh"
          "-c"
          /* sh */ ''
            set -euo pipefail

            uid=$(/usr/bin/id -u $(/usr/bin/stat -f %Su /dev/console))

            # If console is owned by root, there can't be a user logged in, so can't start this.
            [ "$uid" != 0 ] && /bin/launchctl kickstart -k gui/$uid/com.apple.cfprefsd.xpc.agent

            /bin/launchctl kickstart -k system/com.apple.cfprefsd.xpc.daemon
          ''
        ];

        ${if options ? systemd then "systemd" else null}.service = {
          wantedBy = [
            "multi-user.target"
            "sysinit-reactivation.target"
          ];
          after = singleton "local-fs.target";
          serviceConfig.Type = "oneshot";
        };
      };
    };
}
