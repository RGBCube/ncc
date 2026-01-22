{ self, config, inputs, lib, pkgs, ... }: let
  inherit (lib) attrsToList concatStringsSep const disabled filter filterAttrs flip id isType mapAttrs mapAttrsToList merge mkAfter optionalAttrs optionals;

  registryMap = inputs
    |> filterAttrs (const <| isType "flake");
in {
  nix.distributedBuilds = true;
  nix.buildMachines     = self.nixosConfigurations
    |> attrsToList
    |> filter ({ name, value }:
      name != config.networking.hostName &&
      value.config.users.users ? build)
    |> map ({ name, value }: {
      hostName          = name;
      maxJobs           = 20;
      protocol          = "ssh-ng";
      sshUser           = "build";
      supportedFeatures = [ "benchmark" "big-parallel" "kvm" "nixos-test" ];
      system            = value.config.nixpkgs.hostPlatform.system;
    });

  nix.channel = disabled;

  nix.gc = merge {
    automatic  = true;
    options    = "--delete-older-than 3d";
  } <| optionalAttrs config.isLinux {
    dates      = "weekly";
    persistent = true;
  };

  nix.nixPath = registryMap
    |> mapAttrsToList (name: value: "${name}=${value}")
    |> (if config.isDarwin then concatStringsSep ":" else id);

  nix.registry = registryMap // { default = inputs.nixpkgs; }
    |> mapAttrs (_: flake: { inherit flake; });

  nix.settings = (import <| self + /flake.nix).nixConfig
    |> flip removeAttrs (optionals config.isDarwin [ "use-cgroups" ]);

  nix.optimise.automatic = true;

  environment.systemPackages = [
    pkgs.nh
    pkgs.nix-index
    pkgs.nix-output-monitor
  ];

  home-manager.sharedModules = [{
    programs.nushell.configFile.text = mkAfter /* nu */ ''
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
  }];
}
