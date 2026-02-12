{
  flake.homeModules.video-player =
    {
      lib,
      osConfig,
      pkgs,
      ...
    }:
    let
      inherit (lib.lists) singleton;
    in
    {
      # TODO: xdg-mime

      packages = singleton (
        if osConfig.nixpkgs.hostPlatform.isLinux then
          pkgs.haruna
        else if osConfig.nixpkgs.hostPlatform.isDarwin then
          pkgs.iina
        else
          throw "Unsupported OS"
      );
    };
}
