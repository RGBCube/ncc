{ self, lib, ... }:
let
  inherit (lib.lists) singleton;
in
{
  imports =
    singleton
    <| lib.rust.package {
      source = ./.;

      overrideAttrs = _: {
        postInstall = ''
          ln --symbolic sessiond "$out/bin/session-singleton"
          ln --symbolic sessiond "$out/bin/session-instanced"
        '';
      };
    };

  flake.nixosModules.sessiond =
    {
      config,
      options,
      lib,
      pkgs,
      utils,
      ...
    }:
    let
      inherit (lib.lists) map singleton;
      inherit (lib.meta) getExe getExe';
      inherit (lib.modules) mkIf mkMerge;
      inherit (lib.options) mkEnableOption mkOption;
      inherit (lib.types)
        either
        listOf
        nullOr
        package
        str
        ;
      inherit (lib.fixedPoints) fix;
      inherit (utils) escapeSystemdExecArgs;

      cfg = config.services.sessiond;

      userManagerUnit = "user@${toString config.users.users.${cfg.user}.uid}.service";
    in
    {
      options.services.sessiond = {
        enable = mkEnableOption "Session management.";

        package = mkOption {
          type = package;
          default = self.packages.${pkgs.stdenv.hostPlatform.system}.sessiond;
          description = "Package providing `sessiond`.";
        };

        user = mkOption {
          type = str;
          description = "User to manage the sessions of.";
        };

        seat = mkOption {
          type = str;
          default = "seat0";
          description = "Seat to run the sessions on.";
        };

        singletonCommand = mkOption {
          type = nullOr <| listOf <| either str package;
          default = null;
          description = ''
            Command that runs in the singleton session.

            The command is run as a notify service. It must import its
            variables into the user manager before signaling readiness.

            When null, an instanced session is started at boot instead.
          '';
        };

        instancedCommand = mkOption {
          type = listOf <| either str package;
          description = ''
            Command that runs in instanced sessions.

            The command is run with XDG_SESSION_ID set to the session it
            belongs to and must use it to select its logind session.
          '';
        };
      };

      config =
        mkIf cfg.enable
        <| mkMerge [
          {
            assertions =
              map
                (service: {
                  assertion = !config.services.${service}.enable;
                  message = "`services.${service}` conflicts with sessiond.";
                })
                [
                  "cage"
                  "displayManager"
                  "greetd"
                  "kmscon"
                  "seatd"
                ]
              ++ [
                {
                  assertion = !(options.services ? getty);
                  message = "`services.getty` conflicts with sessiond. Compile it out with `disabledModules = [ \"services/ttys/getty.nix\" ];`.";
                }
                {
                  assertion = config.users.users.${cfg.user}.uid or null != null;
                  message = "`services.sessiond.user` must be a user with a static UID.";
                }
              ];
          }

          # SESSIOND
          {
            systemd.defaultUnit = "graphical.target";
            systemd.targets.graphical.wants = singleton (
              if cfg.singletonCommand != null then "session-singleton.service" else "session-instanced@1.service"
            );

            systemd.services.sessiond = {
              description = "Session daemon.";

              after = singleton "systemd-logind.service";
              wantedBy = singleton "graphical.target";

              serviceConfig.Restart = "always";
              serviceConfig.ExecStart = escapeSystemdExecArgs [
                (getExe cfg.package)
                "--unit=session-instanced@.service"
                "--seat=${cfg.seat}"
              ];
            };
          }

          # SINGLETON
          (mkIf (cfg.singletonCommand != null) {
            security.pam.services.session-singleton.startSession = true;
            systemd.services.session-singleton = {
              description = "Singleton session.";

              after = [
                "systemd-user-sessions.service"
                userManagerUnit
              ];
              requires = singleton userManagerUnit;

              serviceConfig.User = cfg.user;
              serviceConfig.PAMName = "session-singleton";
              environment.XDG_SEAT = cfg.seat;

              serviceConfig.Restart = "on-failure";
              # Every restart is a full login session, so the default 10
              # second window would never catch a crash loop of them.
              unitConfig.StartLimitIntervalSec = "1min";

              serviceConfig.ExecStart = escapeSystemdExecArgs [
                (getExe' cfg.package "session-singleton")
                "--unit=singleton.service"
              ];

              # Ensure an instanced session exists if the singleton session fails.
              #
              # If this creates it, the instanced session attaching to a seat will make
              # logind automatically switch to it. If it already exists, sessiond will
              # raise it when it sees that the singleton session died.
              unitConfig.OnFailure = "session-instanced@1.service";
            };

            hjem.users.${cfg.user}.systemd.services.singleton = {
              description = "Unit of the singleton session.";

              bindsTo = singleton "graphical-session.target";
              before = singleton "graphical-session.target";

              wants = singleton "graphical-session-pre.target";
              after = singleton "graphical-session-pre.target";

              serviceConfig.Slice = "session.slice";
              serviceConfig.ExecStart = escapeSystemdExecArgs cfg.singletonCommand;
              serviceConfig.Type = "notify";

              unitConfig.OnSuccess = "singleton-defunct.target";
              unitConfig.OnSuccessJobMode = "replace-irreversibly";
              unitConfig.OnFailure = "singleton-defunct.target";
              unitConfig.OnFailureJobMode = "replace-irreversibly";
            };

            hjem.users.${cfg.user}.systemd.targets.singleton-defunct = fix (unit: {
              description = "Singleton unit is defunct, shut down other stuff.";

              after = unit.conflicts;
              conflicts = [
                "graphical-session.target"
                "graphical-session-pre.target"
              ];

              unitConfig.DefaultDependencies = false;
              unitConfig.StopWhenUnneeded = true;
            });
          })

          # INSTANCED
          {
            security.pam.services.session-instanced.startSession = true;
            systemd.services."session-instanced@" = {
              description = "Instanced session %i.";

              after = [
                "systemd-user-sessions.service"
                userManagerUnit
              ];
              requires = singleton userManagerUnit;

              serviceConfig.User = cfg.user;
              serviceConfig.PAMName = "session-instanced";
              environment.XDG_SEAT = cfg.seat;

              serviceConfig.ExecStart = escapeSystemdExecArgs [
                (getExe' cfg.package "session-instanced")
                "--unit=instanced@.service"
              ];
            };

            hjem.users.${cfg.user}.systemd.services."instanced@" = {
              description = "Unit of session %i.";

              # The session ID is the part after @ in instanced@<session-id>.
              # The unit uses this to get devices from logind.
              #
              # The reason we don't do this in singleton.service is because session-singleton
              # sets the XDG_SESSION_ID variable in the user manager globally.
              environment.XDG_SESSION_ID = "%i";

              serviceConfig.Slice = "session.slice";
              serviceConfig.ExecStart = escapeSystemdExecArgs cfg.instancedCommand;
            };
          }
        ];
    };
}
