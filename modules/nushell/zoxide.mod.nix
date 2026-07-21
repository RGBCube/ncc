{ self, ... }:
{
  flake.homeModules.shell = self.homeModules.zoxide;
  flake.homeModules.zoxide =
    { lib, pkgs, ... }:
    let
      inherit (lib.meta) getExe;
      inherit (lib.modules) mkAfter;
      inherit (lib.lists) singleton;
    in
    {
      packages = singleton pkgs.zoxide;

      programs.nushell.extraConfig = mkAfter "source ${
        pkgs.runCommand "zoxide.nu" { } /* bash */ ''
          ${getExe pkgs.zoxide} init nushell --cmd cd > $out
        ''
      }";
    };
}
