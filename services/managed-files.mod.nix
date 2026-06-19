{
  flake.modularServices.managed-files =
    {
      config,
      lib,
      name,
      options,
      ...
    }:
    let
      inherit (lib) baseNameOf dirOf toFile;
      inherit (lib.attrsets) filterAttrs mapAttrsToList optionalAttrs;
      inherit (lib.lists) singleton;
      inherit (lib.meta) getExe;
      inherit (lib.modules) mkDerivedConfig mkIf;
      inherit (lib.options) mkOption;
      inherit (lib.strings) escapeShellArgs toJSON;
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
      _class = "service";

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

        process.argv =
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
      }
      // optionalAttrs (options ? launchd) {
        launchd = {
          RunAtLoad = true;
          ProgramArguments = [
            "/bin/sh"
            "-c"
            /* bash */ ''
              /bin/wait4path /nix/store && exec ${escapeShellArgs config.process.argv}
            ''
          ];
        };
      }
      // optionalAttrs (options ? systemd) {
        systemd.service = {
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
