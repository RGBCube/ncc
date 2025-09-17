{
  nixpkgs.overlays = [(self: super: {
    fast-workspace-switch = self.stdenv.mkDerivation (finalAttrs: {
      pname = "fast-workspace-switch";
      version = "1.0.0";
      src = ./.;

      dontConfigure = true;

      buildPhase = ''
        $CC -O2 -Wall -Wextra \
          -framework CoreGraphics \
          -framework CoreFoundation \
          -o ${finalAttrs.pname} ${finalAttrs.pname}.c
      '';

      installPhase = ''
        mkdir -p $out/bin
        install -m755 ${finalAttrs.pname} $out/bin/
      '';

      meta = {
        description = "Fast workspace switcher for macOS";
        platforms = self.lib.platforms.darwin;
        mainProgram = finalAttrs.pname;
      };
    });
  })];
}
