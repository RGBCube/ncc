{ lib, ... }:
let
  inherit (lib.meta) getExe;
  inherit (lib.lists) singleton;
in
{
  asShell = shell: filename: text: ''
    ${getExe shell} ${
      shell.stdenv.mkDerivation {
        name = filename;

        inherit text;
        passAsFile = singleton "text";
        phases = singleton "installPhase";

        installPhase = /* bash */ ''
          cp "$textPath" "$out"
        '';
      }
    }
  '';
}
