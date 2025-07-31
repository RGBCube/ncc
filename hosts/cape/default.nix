lib: lib.darwinSystem' ({ config, lib, ... }: let
  inherit (lib) collectNix remove;
in {
  imports = collectNix ./.
    |> remove ./default.nix;

  type = "desktop";

  secrets.id.file = ./id.age;

  services.openssh.extraConfig = /* sshclientconfig */ ''
    HostKey ${config.secrets.id.path}
  '';

  networking.hostName = "cape";

  users.users.said = {
    name = "said";
    home = "/Users/said";
  };

  home-manager.users.said.home = {
    stateVersion  = "25.05";
    homeDirectory = config.users.users.said.home;
  };

  system.stateVersion = 6;
})
