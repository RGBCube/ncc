{ self, ... }:
{
  perSystem =
    { lib, pkgs, ... }:
    let
      inherit (lib.meta) getExe;
    in
    {
      packages.default = pkgs.writeScriptBin "nh" /* nu */ ''
        #!${getExe pkgs.nushell}
        #

        def --wrapped main [...arguments] {
          $env.NH_FLAKE = "${self}"
          exec ${getExe pkgs.nh} ...$arguments
        }
      '';
    };
}
