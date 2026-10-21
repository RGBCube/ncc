{ self, ... }:
{
  flake.serviceModules.ssh-agent =
    {
      config,
      lib,
      name,
      options,
      ...
    }:
    let
      inherit (lib.attrsets)
        filterAttrs
        hasAttr
        mapAttrsToList
        optionalAttrs
        ;
      inherit (lib.lists)
        concatLists
        singleton
        toList
        ;
      inherit (lib.meta) getExe';
      inherit (lib.trivial) const;
      inherit (lib.strings) toJSON;
      inherit (lib.options) mkOption;
      inherit (lib.types)
        bool
        enum
        listOf
        nullOr
        package
        raw
        str
        ;

      cfg = config.ssh-agent;

      mkFlagOption =
        {
          flag,
          type,
          default,
          description,
        }:
        mkOption { inherit type default description; } // { inherit flag; };
    in
    {
      imports = singleton self.serviceModules.base;

      options.ssh-agent = {
        package = mkOption {
          type = package;
          description = "Package providing ssh-agent.";
        };

        writeNu = mkOption {
          type = raw;
          description = "Nushell script writer used to wrap ssh-agent.";
        };

        uutils-coreutils-noprefix = mkOption {
          type = raw;
          description = "Coreutils required for the Nushell script";
        };

        foreground = mkFlagOption {
          flag = "-D";
          type = bool;
          default = true;
          description = "Run ssh-agent in the foreground.";
        };

        debug = mkFlagOption {
          flag = "-d";
          type = bool;
          default = false;
          description = "Run ssh-agent in debug mode.";
        };

        fingerprintHash = mkFlagOption {
          flag = "-E";
          type = nullOr (enum [
            "md5"
            "sha256"
          ]);
          default = null;
          description = "Hash algorithm used for displayed key fingerprints.";
        };

        options = mkFlagOption {
          flag = "-O";
          type = listOf str;
          default = [ ];
          description = "Options passed to ssh-agent.";
        };

        allowedProviders = mkFlagOption {
          flag = "-P";
          type = nullOr str;
          default = null;
          description = "Pattern-list of allowed PKCS#11 and FIDO provider paths.";
        };

        lifetime = mkFlagOption {
          flag = "-t";
          type = nullOr str;
          default = null;
          description = "Maximum lifetime for identities added to the agent.";
        };
      };

      config = {
        assertions = singleton {
          assertion = !(cfg.debug && cfg.foreground);
          message = "ssh-agent.debug and ssh-agent.foreground cannot both be enabled.";
        };

        exec.argv =
          singleton
          <| cfg.writeNu "ssh-agent" /* nu */ ''
            def --wrapped main [...arguments] {
              let runtime_directory = r###'${name |> toJSON}'### | from json
              mkdir $runtime_directory
              ^${getExe' cfg.uutils-coreutils-noprefix "chgrp"} ${name} $runtime_directory
              ^${getExe' cfg.uutils-coreutils-noprefix "chmod"} 0770 $runtime_directory
              cd $runtime_directory

              exec ${getExe' cfg.package "ssh-agent"} ...$arguments
            }
          '';

        exec.flags =
          singleton { "-a" = "socket"; }
          ++ (
            options.ssh-agent
            |> filterAttrs (const <| hasAttr "flag")
            |> mapAttrsToList (
              optionName: option:
              toList cfg.${optionName}
              |> map (item: {
                ${option.flag} = item;
              })
            )
            |> concatLists
          );
      }
      // optionalAttrs (options ? systemd) {
        systemd.service.serviceConfig = {
          Group = name;
          RuntimeDirectory = name;
          RuntimeDirectoryMode = "0770";
          WorkingDirectory = "/run";
        };
      }
      // optionalAttrs (options ? launchd) {
        launchd.GroupName = name;

        processConfig.workingDirectory = "/var/run";
      };
    };
}
