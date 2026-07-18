{ self, inputs, ... }:
{
  commonModules.nix =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib.attrsets)
        filterAttrs
        mapAttrs
        mapAttrsToList
        optionalAttrs
        ;
      inherit (lib.lists) optional singleton;
      inherit (lib.trivial) const flip;
      inherit (lib.types) isType;
    in
    {
      environment.systemPackages = [
        pkgs.nh
        pkgs.nix-output-monitor
      ];

      system = optionalAttrs config.nixpkgs.hostPlatform.isLinux {
        disableInstallerTools = true;
      };

      nix.package = pkgs.nixVersions.latest;

      nix.settings =
        (import <| self + /flake.nix).nixConfig
        |> flip removeAttrs (optional config.nixpkgs.hostPlatform.isDarwin "use-cgroups");

      nix.channel.enable = false;

      nix.optimise.automatic = true;

      nix.gc.automatic = true;
      nix.gc.options = "--delete-older-than 3d";

      nix.registry =
        filterAttrs (const <| isType "flake") inputs // { default = inputs.nixpkgs; }
        |> mapAttrs (_: flake: { inherit flake; });

      nix.nixPath = config.nix.registry |> mapAttrsToList (name: const "${name}=flake:${name}");

      home.extraModules = singleton {
        programs.nushell.extraConfig = "source ${
          pkgs.writeText "nix-run-shortcuts.nu" /* nu */ ''
            def --wrapped * [program: string = "", ...arguments] {
              if ($program | str contains "#") or ($program | str contains ":") {
                nix run $program -- ...$arguments
              } else {
                nix run ("default#" + $program) -- ...$arguments
              }
            }

            def --wrapped > [...arguments: string] {
              nix shell ...($arguments | each {
                if ($in | str contains "#") or ($in | str contains ":") {
                  $in
                } else {
                  "default#" + $in
                }
              })
            }
          ''
        }";
      };
    };

  flake.nixosModules.default = self.nixosModules.nix;
  flake.nixosModules.nix =
    { lib, ... }:
    let
      inherit (lib.lists) singleton;
    in
    {
      persist.mountpoints = singleton "/nix";

      nix.gc = {
        dates = "weekly";
        persistent = true;
      };
    };

  flake.darwinModules.default = self.darwinModules.nix;
  flake.darwinModules.nix =
    { lib, ... }:
    let
      inherit (lib.lists) singleton;
    in
    {
      nix.gc.interval = singleton {
        Hour = 3;
        Minute = 15;
        Weekday = 7;
      };
    };
}
