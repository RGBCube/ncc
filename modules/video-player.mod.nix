{
  homeModules.video-player =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib.modules) optionals;
    in
    {
      # TODO: xdg-mime

      packages = [
      ]
      ++ optionals config.nixpkgs.hostPlatform.isLinux [
        pkgs.haruna
      ]
      ++ optionals config.nixpkgs.hostPlatform.isDarwin [
        pkgs.iina
      ];
    };
}
