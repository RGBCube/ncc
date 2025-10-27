{
  homeModules.video-player =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib.lists) singleton;
    in
    {
      # TODO: xdg-mime

      packages = singleton (
        if config.nixpkgs.hostPlatform.isLinux then
          pkgs.haruna
        else if config.nixpkgs.hostPlatform.isDarwin then
          pkgs.iina
        else
          throw "Unsupported OS"
      );
    };
}
