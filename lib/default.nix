args: {
  magic = import ./magic.nix args;
  generators = import ./generators.nix args;
  shell = import ./shell.nix args;
  systems = import ./systems.nix args;
}
