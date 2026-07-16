{
  commonModules.nuke-default-packages = {
    environment.defaultPackages = [ ];
  };

  flake.darwinModules.nuke-default-packages = {
    system.tools.darwin-option.enable = false;
    system.tools.darwin-uninstaller.enable = false;
    system.tools.darwin-version.enable = false;
  };

  flake.nixosModules.nuke-default-packages = {
    environment.stub-ld.enable = false;

    programs.nano.enable = false;
  };
}
