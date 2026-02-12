{
  flake.homeModules.packages-media =
    { pkgs, ... }:
    {
      packages = [
        pkgs.yt-dlp
      ];
    };
}
