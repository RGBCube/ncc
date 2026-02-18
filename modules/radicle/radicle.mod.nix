{ lib, ... }:
let
  inherit (lib.generators) toJSON;
  inherit (lib.lists) singleton;

  commonModule =
    { config, ... }:
    {
      secrets.radicle = {
        file = ./radicle.age;
        owner = config.system.primaryUser;
        mode = "0600";
      };
    };
in
{
  flake.darwinModules.radicle = commonModule;

  flake.nixosModules.radicle = commonModule;

  flake.homeModules.radicle =
    {
      config,
      osConfig,
      pkgs,
      ...
    }:
    {
      environment.sessionVariables.RAD_HOME = "${config.xdg.data.directory}/radicle";

      packages = singleton pkgs.radicle-node;

      xdg.data.files."radicle/config.json".generator = toJSON { };
      xdg.data.files."radicle/config.json".value = {
        publicExplorer = "https://app.radicle.xyz/nodes/$host/$rid$path";
        preferredSeeds = [
          "z6MkrLMMsiPWUcNPHcRajuMi9mDfYckSoJyPwwnknocNYPm7@iris.radicle.xyz:8776"
          "z6Mkmqogy2qEM2ummccUthFEaaHvyYmYBYh3dbe9W4ebScxo@rosa.radicle.xyz:8776"
        ];

        node.alias = "RGBCube";
      };

      xdg.data.files."radicle/keys/radicle.pub".text = ''
        ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKl2Gn9hN40fRdk/l8rtPehYV5WfKjp1YaEUAzoWH9Wx radicle
      '';
    };
}
