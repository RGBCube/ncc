{
  flake.nixosModules.documentation = {
    documentation = {
      man.enable = true;

      doc.enable = false;
      info.enable = false;
      nixos.enable = false;
    };
  };
}
