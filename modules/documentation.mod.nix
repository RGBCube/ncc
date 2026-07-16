{
  commonModules.documentation = {
    documentation = {
      man.enable = true;

      doc.enable = false;
      info.enable = false;
    };
  };

  flake.nixosModules.documentation = {
    documentation.nixos.enable = false;
  };
}
