{ inputs, ... }:
{
  homeModules.home-modules = {
    imports = [ inputs.home-modules.hjemModules.hjem-rum ];
  };
}
