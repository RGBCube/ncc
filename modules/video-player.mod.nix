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
      ++ optionals config.nixpkgs.system.isLinux [
        pkgs.haruna
      ]
      ++ optionals config.nixpkgs.system.isDarwin [
        pkgs.iina
      ];
    };
}
