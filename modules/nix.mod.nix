let
  commonModule =
    inputs:
    {
      self,
      config,
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
      inherit (lib.lists) filter optional singleton;
      inherit (lib.strings) concatStringsSep;
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

      # We install `nh` already.
      system = optionalAttrs config.nixpkgs.hostPlatform.isLinux {
        tools.nixos-rebuild.enable = false;
      };

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

      nix.gc = {
        automatic = true;
        options = "--delete-older-than 3d";
      };

      nix.nixPath =
        registryMap
        |> mapAttrsToList (name: value: "${name}=${value}")
        |> (if config.nixpkgs.hostPlatform.isDarwin then concatStringsSep ":" else id);

      nix.registry =
        registryMap // { default = inputs.nixpkgs; } |> mapAttrs (_: flake: { inherit flake; });

      nix.settings =
        (import <| self + /flake.nix).nixConfig
        |> flip removeAttrs (optional config.nixpkgs.hostPlatform.isDarwin "use-cgroups");

      nix.optimise.automatic = true;

      nix.package = pkgs.nixVersions.latest;

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
{ inputs, ... }:
{
  flake.nixosModules.nix =
    { lib, ... }:
    let
      inherit (lib.lists) singleton;
    in
    {
      imports = singleton <| commonModule inputs;

      # We have nh.
      system.switch.enable = false;

      nix.gc = {
        dates = "weekly";
        persistent = true;
      };
    };

  flake.darwinModules.nix =
    { lib, ... }:
    let
      inherit (lib.lists) singleton;
    in
    {
      imports = singleton <| commonModule inputs;

      nix.gc.interval = singleton {
        Hour = 3;
        Minute = 15;
        Weekday = 7;
      };
    };
}
