let
  commonModule =
    {
      self,
      config,
      inputs,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib.attrsets)
        attrsToList
        filterAttrs
        mapAttrs
        mapAttrsToList
        optionalAttrs
        ;
      inherit (lib.lists) filter optionals singleton;
      inherit (lib.modules) mkMerge;
      inherit (lib.strings) concatStringsSep toJSON;
      inherit (lib.trivial) const flip id;
      inherit (lib.types) isType;

      registryMap = filterAttrs (const <| isType "flake") inputs;
    in
    {
      environment.systemPackages = [
        pkgs.nh
        pkgs.nix-index
        pkgs.nix-output-monitor
      ];

      # We don't want inputs to be garbage collected away because if
      # that happens rebuilds need to re-fetch everything.
      # TODO: Don't do this on servers.
      environment.etc.".system-inputs.json".text = toJSON registryMap;

      nix.distributedBuilds = true;
      nix.buildMachines =
        self.nixosConfigurations
        |> attrsToList
        |> filter ({ name, value }: name != config.networking.hostName && value.config.users.users ? build)
        |> map (
          { name, value }:
          {
            hostName = name;
            maxJobs = 20;
            protocol = "ssh-ng";
            sshUser = "build";
            supportedFeatures = [
              "benchmark"
              "big-parallel"
              "kvm"
              "nixos-test"
            ];
            system = value.config.nixpkgs.hostPlatform.system;
          }
        );

      nix.channel.enable = false;

      nix.gc = mkMerge [
        {
          automatic = true;
          options = "--delete-older-than 3d";
        }

        (optionalAttrs config.nixpkgs.system.isLinux {
          dates = "weekly";
          persistent = true;
        })
      ];

      nix.nixPath =
        registryMap
        |> mapAttrsToList (name: value: "${name}=${value}")
        |> (if config.nixpkgs.system.isDarwin then concatStringsSep ":" else id);

      nix.registry =
        registryMap // { default = inputs.nixpkgs; } |> mapAttrs (_: flake: { inherit flake; });

      nix.settings =
        (import <| self + /flake.nix).nixConfig
        |> flip removeAttrs (optionals config.nixpkgs.system.isDarwin [ "use-cgroups" ]);

      nix.optimise.automatic = true;

      home.extraModules = singleton {
        programs.nushell.extraConfig = # nu
          ''
            def --wrapped * [program: string = "", ...arguments] {
              if ($program | str contains "#") or ($program | str contains ":") {
                nix run $program -- ...$arguments
              } else {
                nix run ("default#" + $program) -- ...$arguments
              }
            }

            def --wrapped > [...programs] {
              nix shell ...($programs | each {
                if ($in | str contains "#") or ($in | str contains ":") {
                  $in
                } else {
                  "default#" + $in
                }
              })
            }
          '';
      };
    };
in
{
  nixosModules.nix = commonModule;
  darwinModules.nix = commonModule;
}
