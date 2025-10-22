{
  nixosModules.emulated-systems =
    { config, lib, ... }:
    let
      inherit (lib.lists) remove;
    in
    {
      boot.binfmt.emulatedSystems = remove config.nixpkgs.hostPlatform.system [
        "aarch64-linux"
        "riscv64-linux"
        "x86_64-linux"
      ];
    };
}
