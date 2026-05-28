{ self, lib, ... }:
let
  inherit (lib.lists) singleton;
in
{
  flake.keys = {
    best = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBUsMV591/9VqzjBiMqdxJId0C7PlZTIXQByHEILWMwc the@best";
    disk = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIItpYQ3Pz6zFifKXvFX7xAC8aby9RW/m5PkW8T9SOee4 floppy@disk";
    nine = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILJDqnItmvXZMTSwzbalr+9jzS4kSJm5PWEpI8GOpebF seven@nine";

    pala = self.keys.rgbcube;
    rgbcube = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBVkWUQ6Z4OK539tore/R5wnueNPPaX532RUAld8UOCo rgbcube";

    istanbul = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMCykEkiotbnje7b7Gg7f+fg58zOxRjNKuJO0z1eVrmF istanbul";
    vienna = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIO89LpzcmPit5ZanIpRhevqoUWpeB9Ja/sLxyKivfjJ vienna";
  };

  flake.keys-admin = singleton self.keys.rgbcube;
}
