{
  nixosModules.clean-tmp = {
    boot.tmp.cleanOnBoot = true;
  };
}
