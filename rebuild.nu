#!/usr/bin/env nu

def --wrapped sync [...arguments] {
 (rsync
    --archive
    --compress

    --delete --recursive --force
    --delete-excluded
    --delete-missing-args

    --human-readable
    --delay-updates
    ...$arguments)
}

# Rebuild a NixOS / Darwin config.
def main --wrapped [
  host: string = "" # The host to build.
  --remote (-r)     # Whether if this is a remote host. The config will be built on this host if it is.
  ...arguments      # The arguments to pass to `nh {os,darwin} switch` and `nix` (separated by --).
]: nothing -> nothing {
  let host = if ($host | is-not-empty) {
    if $host != (hostname) and not $remote {
      print $"(ansi yellow_bold)warn:(ansi reset) building local configuration for hostname that does not match the local machine"
    }

    $host
  } else if $remote {
    print $"(ansi red_bold)error:(ansi reset) hostname not specified for remote build"
    exit 1
  } else {
    (hostname)
  }

  if $remote {
    git ls-files
    | sync --files-from - ./ $"root@($host):ncc"

    ssh -tt ("root@" + $host) $"
      cd ncc
      ./rebuild.nu ($host) ($arguments | str join ' ')
    "

    return
  }

  let args_split = $arguments | prepend "" | split list "--"
  let nh_flags = [
    "--hostname" $host
  ] | append ($args_split | get 0 | where { $in != "" })

  let nix_flags = [
    "--option" "accept-flake-config" "true"
    "--option" "eval-cache"          "false"
  ] | append ($args_split | get --ignore-errors 1 | default [])

  if (uname | get kernel-name) == "Darwin" {
    NH_BYPASS_ROOT_CHECK=true NH_NO_CHECKS=true nh darwin switch . ...$nh_flags -- ...$nix_flags

    if not (xcode-select --install e>| str contains "Command line tools are already installed") {
      darwin-shadow-xcode-popup
    }

    darwin-set-zshrc
  } else {
    NH_BYPASS_ROOT_CHECK=true NH_NO_CHECKS=true nh os switch . ...$nh_flags -- ...$nix_flags
  }
}

# Replace with the command that has been triggering
# the "install developer tools" popup.
#
# Set by default to "SplitForks" because who even uses that?
const original_trigger = "/usr/bin/SplitForks"

# Where the symbolic links to `/usr/bin/false` will
# be created in to shadow all popup-triggering binaries.
#
# Place this in your $env.PATH right before /usr/bin
# to never get the "install developer tools" popup ever again:
#
# ```nu
# let usr_bin_index = $env.PATH
# | enumerate
# | where item == /usr/bin
# | get 0.index
#
# $env.PATH = $env.PATH | insert $usr_bin_index $shadow_path
# ```
#
# Do NOT set this to a path that you use for other things,
# it will get deleted if it exists to only have the shadowers.
const shadow_path = "~/.local/shadow" | path expand # Did you read the comment?

def darwin-shadow-xcode-popup [] {
  print "shadowing xcode popup binaries..."

  let original_size = ls $original_trigger | get 0.size

  let shadoweds = ls /usr/bin
  | flatten
  | where {
    # All xcode-select binaries are the same size, so we can narrow down and not run weird stuff.
    $in.size == $original_size
  }
  | where {
    ^$in.name e>| str contains "xcode-select: note: No developer tools were found, requesting install."
  }
  | get name
  | each { path basename }

  rm -rf $shadow_path
  mkdir $shadow_path

  for shadowed in $shadoweds {
    let shadow_path = $shadow_path | path join $shadowed

    ln --symbolic /usr/bin/false $shadow_path
  }
}

def darwin-set-zshrc [] {
  print "setting zshrc..."

  let nu_command = $"
    let usr_bin_index = $env.PATH
    | enumerate
    | where item == /usr/bin
    | get 0.index

    $env.PATH = $env.PATH | insert $usr_bin_index ($shadow_path | path expand)

    $env.SHELL = which nu | get 0.path
  "

  let zshrc = $"
    exec nu --execute '
      ($nu_command)
    '
  "

  $zshrc | save --force ~/.zshrc
}
