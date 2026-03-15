{
  flake.darwinModules.krita =
    { lib, ... }:
    let
      inherit (lib.lists) singleton;
    in
    {
      homebrew.casks = singleton "krita";
    };

  flake.homeModules.krita =
    {
      lib,
      osConfig,
      pkgs,
      ...
    }:
    let
      inherit (lib.modules) mkIf;
      inherit (lib.trivial) const flip;
      inherit (lib.attrsets) genAttrs;
    in
    {
      xdg.mime-apps.default-applications =
        mkIf osConfig.nixpkgs.hostPlatform.isLinux
        <| flip genAttrs (const "org.kde.krita.desktop") [
          "application/x-krita"
          "image/openraster"
          "application/x-krita-paintoppreset"
        ];

      packages = mkIf osConfig.nixpkgs.hostPlatform.isLinux [
        pkgs.krita
      ];
    };
}
