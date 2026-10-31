{ self, ... }:
{
  perSystem =
    { lib, pkgs, ... }:
    let
      inherit (lib.attrsets) mapAttrs getAttr unionOfDisjoint;
      inherit (lib.trivial) const;
      inherit (lib.meta) getExe;
      inherit (lib.strings) toJSON;
    in
    {
      packages.default = pkgs.writers.writeNuBin "default" /* nu */ ''
        def class-of [--host: string] {
          r###'${
            self.nixosConfigurations
            |> unionOfDisjoint self.darwinConfigurations
            |> mapAttrs (const <| getAttr "class")
            |> toJSON
          }'###
          | from json
          | get $host
        }

        def is-local [--host: string] {
          sys host | get hostname | $in == $host
        }

        def switch [--target: string, --toplevel: string, --copy] {
          let class = class-of --host $target
          let is_local = is-local --host $target

          let escalate = match $class {
            "nixos" => "run0"
            "darwin" => "sudo"
          }

          let activate = match $class {
            "nixos" => [$"($toplevel)/bin/switch-to-configuration" "switch"]
            "darwin" => [$"($toplevel)/activate"]
          }

          let prefix = if $is_local { [] } else { [ssh -tt $target] }

          try { run-external ...[...$prefix           dix /run/current-system $toplevel] }
                run-external ...[...$prefix $escalate nix build --no-link --profile /nix/var/nix/profiles/system $toplevel]
                run-external ...[...$prefix $escalate ...$activate]
        }

        def main [] {
          help main
        }

        def "main deploy" [
          target: string
        ] {
          let class = class-of --host $target
          let is_local = is-local --host $target

          let toplevel = (^${getExe pkgs.nix-output-monitor} build
            --keep-going
            --no-link
            --print-out-paths
            $"${self}#($class)Configurations.($target).config.system.build.toplevel"
            | str trim)

          if not $is_local {
            ^${getExe pkgs.nix-output-monitor} copy --substitute-on-destination --no-check-sigs --to $"ssh-ng://($target)" $toplevel
          }

          switch --target $target --toplevel $toplevel
        }

        def "main rollback" [
          target: string
        ] {
          let class = class-of --host $target
          let is_local = is-local --host $target

          let generations = if $is_local {
            ls /nix/var/nix/profiles
            | update name { path basename }
            | where { str starts-with "system-" }
            | select name modified
          } else {
            let names = ssh $target ls /nix/var/nix/profiles
            | lines
            | where { str starts-with "system-" }

            let modified = match $class {
              "nixos" => { ssh $target stat --format=%Y ...($names | each { $"/nix/var/nix/profiles/($in)" }) }
              "darwin" => { ssh $target stat -f %m ...($names | each { $"/nix/var/nix/profiles/($in)" }) }
            }

            $modified
            | lines
            | into int
            | wrap modified
            | merge ($names | wrap name)
          }

          let generation = $generations
          | sort-by modified --reverse
          | skip 1
          | each { $"($in.name)" }
          | input list
          | first

          switch --target $target --toplevel $"/nix/var/nix/profiles/($generation)"
        }
      '';
    };
}
