{ self, lib, ... }:
let
  inherit (lib.attrsets) attrValues filterAttrs mapAttrs;
in
{
  flake.people = {
    self = self.people.rgbcube;

    rgbcube = {
      name = "RGBCube";
      email = "git@rgbcu.be";
      admin = true;
      key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBVkWUQ6Z4OK539tore/R5wnueNPPaX532RUAld8UOCo rgbcube";
    };
  };

  flake.machines = {
    istanbul.key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMCykEkiotbnje7b7Gg7f+fg58zOxRjNKuJO0z1eVrmF istanbul";
    vienna.key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIO89LpzcmPit5ZanIpRhevqoUWpeB9Ja/sLxyKivfjJ vienna";

    pala.key = self.people.self.key;

    # OLD INFRASTRUCTURE
    best.key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBUsMV591/9VqzjBiMqdxJId0C7PlZTIXQByHEILWMwc the@best";
    disk.key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIItpYQ3Pz6zFifKXvFX7xAC8aby9RW/m5PkW8T9SOee4 floppy@disk";
    nine.key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILJDqnItmvXZMTSwzbalr+9jzS4kSJm5PWEpI8GOpebF seven@nine";
  };

  flake.keys = mapAttrs (_: { key, ... }: key) (removeAttrs self.people [ "self" ] // self.machines);

  flake.keys-admin =
    removeAttrs self.people [ "self" ]
    |> filterAttrs (
      _:
      {
        admin ? false,
        ...
      }:
      admin
    )
    |> attrValues
    |> map ({ key, ... }: key);
}
