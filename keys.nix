let
  keys = {
    best = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBUsMV591/9VqzjBiMqdxJId0C7PlZTIXQByHEILWMwc the@best";
    disk = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIItpYQ3Pz6zFifKXvFX7xAC8aby9RW/m5PkW8T9SOee4 floppy@disk";
    pala = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBVkWUQ6Z4OK539tore/R5wnueNPPaX532RUAld8UOCo pala@pala";
    nine = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILJDqnItmvXZMTSwzbalr+9jzS4kSJm5PWEpI8GOpebF seven@nine";
  };
in keys // {
  admins = [ keys.pala ];
  all    = builtins.attrValues keys;
}
