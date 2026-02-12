{
  flake.nixosModules.steam = {
    allowedUnfreePackageNames = [ "steam" ];

    programs.steam.enable = true;
  };
}
