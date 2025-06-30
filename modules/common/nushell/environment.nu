$env.ENV_CONVERSIONS.PATH = {
  from_string: {|string|
    $string | split row (char esep) | path expand --no-symlink
  }
  to_string: {|value|
    $value | path expand --no-symlink | str join (char esep)
  }
}

$env.LS_COLORS = (open ~/.config/nushell/ls_colors.txt)

source ~/.config/nushell/zoxide.nu

source ~/.config/nushell/starship.nu

def copy []: string -> nothing {
	print --no-newline $"(ansi osc)52;c;($in | encode base64)(ansi st)"
}

def today []: nothing -> string {
  date now | format date "%Y-%m-%d"
}

# Create a directory and cd into it.
def --env mc [path: path]: nothing -> nothing {
  mkdir $path
  cd $path
}

# Create a directory, cd into it and initialize version control.
def --env mcg [path: path]: nothing -> nothing {
  mkdir $path
  cd $path
  jj git init --colocate
}

module dump {
  def site-path []: nothing -> path {
    $env.HOME | path join "Projects" "site"
  }

  def dump-path []: nothing -> path {
    site-path | path join "site" "dump"
  }

  # Convert a thought dump namespace to the filesystem path.
  export def to-path []: string -> path {
    let namespace = $in

    dump-path
    | path join ...($namespace | split row ".")
    | $in + ".md"
  }

  # Convert a filesystem path to a thought dump namespace.
  export def to-dump []: path -> string {
    let path = $in

    print $path (dump-path)

    $path
    | path relative-to (dump-path)
    | path split
    | str join "."
    | str substring 0..<-3
  }

  # List all thought dumps that start with the given namespace.
  export def list [
    namespace: string = ""
  ]: nothing -> table<namespace: string, path: path> {
    let dump_prefix = dump-path | path join ...($namespace | split row ".")

    let dump_parent_contents = glob ($dump_prefix | path parse | get parent | path join "**" "*.md")
    let dump_matches = $dump_parent_contents | where { str starts-with $dump_prefix }

    ls ...$dump_matches | each {
      merge { path: $in.name }
      | select path size modified
      | merge { namespace: ($in.path | to-dump) }
    }
  }

  # Deploy the thought dumps and thus the website.
  export def deploy []: nothing -> nothing {
    print $"(ansi green)deploying...(ansi reset)"

    cd (site-path)
    ./apply.nu
  }

  # Edit a thought dump.
  export def edit [
    namespace: string # The thought dump to edit. Namespaced using '.', does not include file extension.
  ]: nothing -> nothing {
    let dump_path = $namespace | to-path

    let old_dump_size = try { ls $dump_path }

    mkdir ($dump_path | path parse | get parent)
    touch $dump_path

    let old_dump_hash = open $dump_path | hash sha256

    ^$env.EDITOR $dump_path

    let dump_size = ls $dump_path | get 0.size
    if $dump_size == 0b {
      print $"(ansi red)thought dump was emptied(ansi reset)"
      delete $namespace --existed-before ($old_dump_size != null)
    } else if $old_dump_hash == (open $dump_path | hash sha256) {
      print $"(ansi yellow)thought dump was not modifier, doing nothing(ansi reset)"
    } else {
      print $"(ansi magenta)thought dump was edited(ansi reset)"

      let jj_arguments = [ "--repository", (site-path) ]

      jj ...$jj_arguments commit --message $"dump\(($namespace)\): update"
      jj ...$jj_arguments bookmark set master --revision @-

      [
        { jj ...$jj_arguments git push --remote origin }
        { jj ...$jj_arguments git push --remote rad }
        { deploy }
      ] | par-each { do $in } | last
    }
  }

  # Delete a thought dump.
  export def delete [
    namespace: string # The thought dump to edit. Namespaced using '.', does not include file extension.
    --existed-before = true
  ]: nothing -> nothing {
    let dump_path = $namespace | to-path
    let parent_path = $dump_path | path parse | get parent

    print $"(ansi red)deleting thought dump...(ansi reset)"
    print --no-newline (ansi red)
    rm --verbose $dump_path
    print --no-newline (ansi reset)

    if (ls $parent_path | length) == 0 {
      print $"(ansi red)parent folder is empty, deleting that too...(ansi reset)"
      print $"(ansi yellow)other parents will not be deleted, if you want to delete those do it manually(ansi reset)"
      rm $parent_path
    }

    if $existed_before {
      deploy
    } else {
      print $"(ansi green)the thought dump didn't exist before, so skipping deployment(ansi reset)"
    }
  }
}

use dump
