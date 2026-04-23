{
  flake.commonModules.radicle =
    { config, lib, ... }:
    let
      inherit (lib.attrsets) optionalAttrs;
    in
    {
      secrets.radicle = {
        file = ./radicle.age;
      }
      // optionalAttrs config.nixpkgs.hostPlatform.isDarwin {
        owner = config.system.primaryUser;
      };
    };

  flake.homeModules.radicle =
    {
      config,
      osConfig,
      pkgs,
      lib,
      ...
    }:
    let
      inherit (lib.generators) toJSON;
      inherit (lib.lists) singleton;
    in
    {
      environment.sessionVariables.RAD_HOME = "${config.xdg.data.directory}/radicle";

      packages = singleton pkgs.radicle-node;

      xdg.data.files."radicle/config.json".generator = toJSON { };
      xdg.data.files."radicle/config.json".value = {
        publicExplorer = "https://radicle.network/nodes/$host/$rid$path";
        preferredSeeds = [
          "z6MkrLMMsiPWUcNPHcRajuMi9mDfYckSoJyPwwnknocNYPm7@iris.radicle.network:8776"
          "z6Mkmqogy2qEM2ummccUthFEaaHvyYmYBYh3dbe9W4ebScxo@rosa.radicle.network:8776"
        ];

        node.alias = "RGBCube";
      };

      xdg.data.files."radicle/keys/radicle.pub".text = ''
        ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKl2Gn9hN40fRdk/l8rtPehYV5WfKjp1YaEUAzoWH9Wx radicle
      '';

      xdg.data.files."radicle/keys/radicle".source = osConfig.secrets.radicle.path;
    };
}
