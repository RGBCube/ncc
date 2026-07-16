{ config, self, ... }:
{
  commonModules.default = config.commonModules.documentation;
  commonModules.documentation = {
    documentation = {
      man.enable = true;

      doc.enable = false;
      info.enable = false;
    };
  };

  flake.nixosModules.default = self.nixosModules.documentation;
  flake.nixosModules.documentation = {
    documentation.nixos.enable = false;
  };
}
