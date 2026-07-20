{
  flake.modularServices.base =
    {
      config,
      lib,
      name,
      options,
      ...
    }:
    let
      inherit (lib.attrsets)
        attrNames
        filterAttrs
        getAttr
        ;
      inherit (lib.filesystem) dirOf;
      inherit (lib.fixedPoints) fix;
      inherit (lib.lists)
        any
        concatMap
        elem
        filter
        head
        optional
        optionals
        singleton
        ;
      inherit (lib.modules) mkIf mkMerge;
      inherit (lib.network) isAddressV4 isAddressV6;
      inherit (lib.options) mkOption;
      inherit (lib.strings)
        concatLines
        concatStringsSep
        escapeShellArgs
        hasPrefix
        match
        splitString
        toInt
        ;
      inherit (lib.trivial) const;
      inherit (lib.types)
        addCheck
        attrsOf
        bool
        enum
        ints
        listOf
        nullOr
        oneOf
        package
        path
        port
        str
        submodule
        ;

      timespan =
        addCheck str (
          value:
          match "infinity|( *[0-9]+(\\.[0-9]+)? *(usec|us|msec|ms|seconds|second|sec|s|minutes|minute|min|m|hours|hour|hr|h|days|day|d|weeks|week|w|months|month|M|years|year|y)? *)+" value
          != null
        )
        // {
          description = ''A time span: fractional values with optional concatenated units, or "infinity".'';
        };

      size =
        addCheck str (
          value: match "[0-9]+(\\.[0-9]+)?%|( *[0-9]+(\\.[0-9]+)? *[EPTGMKB]? *)+" value != null
        )
        // {
          description = "A size with an optional unit, or a percentage.";
        };

      portRange = addCheck str (value: match "[0-9]+-[0-9]+" value != null) // {
        description = "An inclusive `low-high` port range.";
      };

      bindPort =
        nullOr
        <| oneOf [
          port
          portRange
        ];

      family =
        nullOr
        <| submodule {
          options.tcp = mkOption {
            type = bindPort;
            default = null;
            description = "TCP port to bind, if any.";
          };

          options.udp = mkOption {
            type = bindPort;
            default = null;
            description = "UDP port to bind, if any.";
          };
        };

      syscall = addCheck str (value: match "@?[a-z][a-z0-9_-]*(:[A-Za-z0-9]+)?" value != null) // {
        description = ''A system call or "@"-prefixed group, with an optional ":errno" suffix.'';
      };

      arch = enum [
        "native"
        "x86"
        "x86-64"
        "x32"
        "arm"
        "arm64"
        "loongarch64"
        "mips"
        "mips64"
        "mips64-n32"
        "mips-le"
        "mips64-le"
        "mips64-le-n32"
        "parisc"
        "parisc64"
        "ppc"
        "ppc64"
        "ppc64-le"
        "riscv64"
        "s390"
        "s390x"
      ];

      # CAP_DAC_OVERRIDE (bypass all file permission checks) is only effective as
      # real host root, so requesting it runs the service rootfully.
      rootful = elem "CAP_DAC_OVERRIDE" config.limits.capabilities;

      portsOf =
        { v4, v6, ... }:
        optionals (v4 != null) [
          v4.tcp
          v4.udp
        ]
        ++ optionals (v6 != null) [
          v6.tcp
          v6.udp
        ]
        |> filter (port: port != null);
    in
    {
      options = {
        exec.allow = mkOption {
          type =
            listOf
            <| oneOf [
              package
              path
            ];
          default = [ ];
          description = ''
            Packages or paths (with their runtime closures) allowed to execute;
            the rest of the filesystem is non-executable.
          '';
        };

        exec.allowMemory = mkOption {
          type = bool;
          default = false;
          description = "Allow writable executable memory, for JITs and similar runtime code generation.";
        };

        exec.again = mkOption {
          type = enum [
            "no"
            "on-success"
            "on-failure"
            "on-abnormal"
            "on-watchdog"
            "on-abort"
            "always"
          ];
          default = "on-failure";
          description = "When the service should be restarted.";
        };

        exec.after = mkOption {
          type = timespan;
          default = "10s";
          description = "How long to wait before restarting.";
        };

        exec.argv = mkOption {
          type = listOf str;
          description = "The service's command line.";
        };

        exec.pre.argv = mkOption {
          type = listOf str;
          default = [ ];
          description = "Command run before the service starts.";
        };

        exec.post.argv = mkOption {
          type = listOf str;
          default = [ ];
          description = "Command run after the service exits, successfully or not.";
        };

        network.reach = mkOption {
          type = listOf str;
          default = [ ];
          description = ''
            Remote addresses the service may exchange traffic with, in either
            direction. Include `0.0.0.0/0` and `::/0` to reach anywhere; the
            empty list isolates the service from the network entirely.
          '';
        };

        network.bind = mkOption {
          type =
            listOf
            <| submodule {
              options.v4 = mkOption {
                type = family;
                default = null;
                description = "IPv4 binds. `{ }` permits the family; set `tcp`/`udp` to allow-list listen ports.";
              };

              options.v6 = mkOption {
                type = family;
                default = null;
                description = "IPv6 binds. `{ }` permits the family; set `tcp`/`udp` to allow-list listen ports.";
              };

              options.unix = mkOption {
                type = nullOr path;
                default = null;
                description = "Unix-domain socket path allowed for access.";
              };
            };
          default = [ ];
          description = ''
            Local sockets the service may bind; anything else is denied. A `unix`
            path also grants write access to its parent directory, in which the
            socket file is created. A `tcp`/`udp` port of `0` marks an ephemeral
            bind (as done by outbound UDP/QUIC clients) and disables bind
            filtering for the whole service, not just that entry. Only family,
            protocol and port are restricted, not the local bind address.
          '';
        };

        files = mkOption {
          type =
            attrsOf
            <| listOf
            <| enum [
              "read"
              "write"
            ];
          default = { };
          description = ''
            Filesystem paths exposed to the service, keyed by path. An empty
            capability list makes a path inaccessible.
          '';
        };

        limits.fd = mkOption {
          type = nullOr ints.unsigned;
          default = null;
          description = "Maximum number of open file descriptors.";
        };

        limits.capabilities = mkOption {
          type = listOf str;
          default = [ ];
          description = "Capabilities granted to the service. Empty drops all capabilities.";
        };

        limits.storage = mkOption {
          type = nullOr size;
          default = null;
          description = ''
            Disk quota for the persistent state directory, which is allocated
            and used as the working directory when set; null gives the service
            no persistent writable storage. Accepts an absolute size ("1G") or
            a percentage of the filesystem ("10%"), and requires quota support
            on the backing filesystem.
          '';
        };

        limits.syscalls = mkOption {
          type = listOf syscall;
          # execve keeps the list non-empty so it is not interpreted as a filter reset.
          default = [ "execve" ];
          description = "System calls or system call groups allowed; anything not listed is denied.";
        };

        limits.architectures = mkOption {
          type = listOf arch;
          default = [ "native" ];
          description = "System call architectures allowed.";
        };
      };

      config = {
        process.argv = config.exec.argv;

        # A null attribute name omits the attribute, for runners without the backend.
        ${if options ? launchd then "launchd" else null} = {
          RunAtLoad = true;
          KeepAlive = getAttr config.exec.again {
            no = false;
            always = true;
            on-success = {
              SuccessfulExit = true;
            };
            on-failure = {
              SuccessfulExit = false;
            };
            on-abnormal = {
              Crashed = true;
            };
            on-abort = {
              Crashed = true;
            };
            on-watchdog = {
              Crashed = true;
            };
          };
          ProgramArguments = [
            "/bin/sh"
            "-c"
            (
              singleton /* sh */ ''
                set -euo pipefail

                /bin/wait4path /nix/store
              ''
              ++ optional (config.exec.pre.argv != [ ]) (escapeShellArgs config.exec.pre.argv)
              ++ singleton (
                if config.exec.post.argv == [ ] then
                  "exec ${escapeShellArgs config.exec.argv}"
                else
                  # Run the post command even when the service fails, mirroring
                  # ExecStopPost, but still report the service's own exit code.
                  /* sh */ ''
                    code=0
                    ${escapeShellArgs config.exec.argv} || code=$?
                    ${escapeShellArgs config.exec.post.argv}
                    exit "$code"
                  ''
              )
              |> concatLines
            )
          ];
        };

        ${if options ? systemd then "systemd" else null}.service.serviceConfig = mkMerge [
          {
            # EXECUTION
            NoExecPaths = "/";
            ExecPaths = singleton "/nix/store" ++ config.exec.allow;
            # Allow the whole store for now, but ideally just the executables' closure:
            # ExecPaths =
            #   config.exec.allow
            #   |> concatMap (
            #     entry:
            #     if isDerivation entry then
            #       entry.stdenv.mkDerivation {
            #         name = "${entry.name}-exec-paths";
            #         exportReferencesGraph = [ "closure" entry ];
            #         phases = singleton "installPhase";
            #         installPhase = ''
            #           grep '^/nix/store/' closure | grep --invert-match '\.drv$' | sort --unique > $out
            #         '';
            #       }
            #       |> fileContents
            #       |> splitString "\n"
            #     else
            #       singleton entry
            #   );

            MemoryDenyWriteExecute = !config.exec.allowMemory;
            NoNewPrivileges = true;

            Restart = config.exec.again;
            RestartSec = config.exec.after;

            ExecStartPre = mkIf (config.exec.pre.argv != [ ]) <| escapeShellArgs config.exec.pre.argv;
            ExecStopPost = mkIf (config.exec.post.argv != [ ]) <| escapeShellArgs config.exec.post.argv;
          }

          (
            let
              allow =
                family: proto: port:
                optional (port != null && port != 0) "${family}:${proto}:${toString port}";
            in
            fix (self: {
              # NETWORKING
              PrivateNetwork = self.IPAddressAllow == [ ];
              IPAddressDeny = "any";
              IPAddressAllow = config.network.reach;

              SocketBindDeny = mkIf (config.network.bind |> concatMap portsOf |> (ports: !elem 0 ports)) "any";
              SocketBindAllow =
                config.network.bind
                |> concatMap (
                  { v4, v6, ... }:
                  optionals (v4 != null) (allow "ipv4" "tcp" v4.tcp ++ allow "ipv4" "udp" v4.udp)
                  ++ optionals (v6 != null) (allow "ipv6" "tcp" v6.tcp ++ allow "ipv6" "udp" v6.udp)
                );

              ReadWritePaths =
                config.network.bind |> concatMap ({ unix, ... }: optional (unix != null) (dirOf unix));
              RestrictAddressFamilies =
                [ ]
                ++ optional (
                  (config.network.reach |> any isAddressV4) || (config.network.bind |> any ({ v4, ... }: v4 != null))
                ) "AF_INET"
                ++ optional (
                  (config.network.reach |> any isAddressV6) || (config.network.bind |> any ({ v6, ... }: v6 != null))
                ) "AF_INET6"
                ++ optional (config.network.bind |> any ({ unix, ... }: unix != null)) "AF_UNIX"
                |> (families: families ++ optional (families == [ ]) "none");
            })
          )

          (
            let
              filesWith = predicate: config.files |> filterAttrs (const predicate) |> attrNames;
            in
            {
              # FILESYSTEM
              InaccessiblePaths = filesWith (capabilities: capabilities == [ ]);
              ReadOnlyPaths = filesWith (capabilities: elem "read" capabilities && !(elem "write" capabilities));
              ReadWritePaths = filesWith <| elem "write";

              PrivateMounts = true;
              PrivateTmp = "disconnected";
              # ProtectHome hides the home hierarchy as an unoverridable
              # InaccessiblePaths, so drop it when a file grant reaches into it.
              ProtectHome =
                !(
                  config.files
                  |> attrNames
                  |> any (
                    path:
                    [
                      "/"
                      "/home"
                      "/root"
                      "/run/user"
                    ]
                    |> any (home: hasPrefix "${home}/" "${path}/")
                  )
                );
              ProtectSystem = "strict";
            }
          )

          (mkIf (config.limits.storage != null) {
            # STATE
            StateDirectory = name;
            StateDirectoryMode = "0700";
            StateDirectoryQuota = config.limits.storage;
            WorkingDirectory = "%S/${name}";
          })

          {
            # DEVICES
            DevicePolicy = "closed";
            PrivateDevices = true;
          }

          {
            # KERNEL
            LockPersonality = true;
            ProtectClock = true;
            ProtectControlGroups = "strict";
            ProtectHostname = true;
            ProtectKernelLogs = true;
            ProtectKernelModules = true;
            ProtectKernelTunables = true;
            RestrictRealtime = true;
          }

          {
            # PROCESS AND IPC
            PrivateIPC = true;
            ProcSubset = "pid";
            ProtectProc = "invisible";
            RemoveIPC = true;
          }

          (fix (self: {
            # BUG(systemd): PrivateBPF with PrivatePIDs makes systemd SIGKILL
            # its own sd-bpffs helper (the private /sys/fs/bpf provider) during
            # PID-namespace setup; sd-pidns-child then dies reading the dead
            # helper's pipe (/sys/fs/bpf: Broken pipe, 226/NAMESPACE). Keep
            # PrivateBPF off whenever PIDs are private.
            PrivatePIDs = true;
            PrivateBPF = !self.PrivatePIDs;
          }))

          {
            # USER AND PRIVILEGES
            AmbientCapabilities = concatStringsSep " " config.limits.capabilities;
            CapabilityBoundingSet = concatStringsSep " " config.limits.capabilities;
            DynamicUser = !rootful;
            RestrictSUIDSGID = true;
            UMask = "0077";
          }

          (
            let
              privileged =
                port:
                toString port
                |> splitString "-"
                |> head
                |> toInt
                |> (port: port < 1024);
            in
            {
              # NAMESPACES
              # Capabilities (e.g. CAP_NET_BIND_SERVICE, CAP_DAC_OVERRIDE) granted
              # to a private user namespace are ineffective against the host, so a
              # service binding a privileged port or running rootfully must stay in
              # the host user namespace.
              PrivateUsers =
                !(
                  rootful || (config.network.bind |> concatMap portsOf |> any (port: port != 0 && privileged port))
                );
              RestrictNamespaces = true;
            }
          )

          {
            # RESOURCES
            LimitCORE = 0;
            LimitNOFILE = mkIf (config.limits.fd != null) config.limits.fd;
          }

          {
            # SYSCALLS
            SystemCallArchitectures = config.limits.architectures;
            SystemCallFilter = config.limits.syscalls;
          }
        ];
      };
    };
}
