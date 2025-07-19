{ config, lib, ... }: let
  inherit (lib) attrsToList catAttrs mkConst mkIf mkValue sortOn toInt;
in {
  options.shells = mkValue {};

  options.shellsByPriority = mkConst (config.shells
    |> attrsToList
    |> sortOn ({ name, ... }: toInt name)
    |> catAttrs "value");

  config = mkIf config.isDarwin {
    environment.shells = config.shellsByPriority;
  };

  # More at modules/linux/shell/default.nix.
  #
  # Can't put that here with an optionalAttributes
  # becuase of an infinite recursion error, and can't
  # do that with a mkIf because the nix-darwin module
  # system doesn't have those attributes.
}
