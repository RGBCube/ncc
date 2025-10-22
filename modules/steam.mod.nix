{
  nixosModules.steam = {
    nixpkgs.config.allowedUnfreePackageNames = [ "steam" ];

    programs.steam.enable = true;
  };
}
