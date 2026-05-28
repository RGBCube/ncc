args:
{
  magic = import ./magic.nix args;
  generators = import ./generators.nix args;
  systems = import ./systems.nix args;
}
