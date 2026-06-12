{ self }:
let
  inherit (self.meta) getExe;
  inherit (self.lists) singleton;
in
{
  shell.asShell = shell: filename: text: ''
    ${getExe shell} ${
      shell.stdenv.mkDerivation {
        name = filename;

        passAsFile = singleton "text";
        inherit text;

        phases = singleton "installPhase";
        installPhase = /* bash */ ''
          cp "$textPath" "$out"
        '';
      }
    }
  '';
}
