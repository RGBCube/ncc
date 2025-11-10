use std/clip
use std null_device

$env.config.history.file_format = "sqlite"
$env.config.history.isolation = false
$env.config.history.max_size = 10_000_000
$env.config.history.sync_on_enter = true

$env.config.show_banner = false

$env.config.rm.always_trash = false

$env.config.recursion_limit = 100

$env.config.edit_mode = "vi"

$env.config.cursor_shape.emacs = "line"
$env.config.cursor_shape.vi_insert = "line"
$env.config.cursor_shape.vi_normal = "block"

$env.CARAPACE_BRIDGES = "inshellisense,carapace,zsh,fish,bash"

$env.config.completions.algorithm = "substring"
$env.config.completions.sort = "smart"
$env.config.completions.case_sensitive = false
$env.config.completions.quick = true
$env.config.completions.partial = true
$env.config.completions.use_ls_colors = true

$env.config.use_kitty_protocol = true

$env.config.shell_integration.osc2 = true
$env.config.shell_integration.osc7 = true
$env.config.shell_integration.osc8 = true
$env.config.shell_integration.osc9_9 = true
$env.config.shell_integration.osc133 = true
$env.config.shell_integration.osc633 = true
$env.config.shell_integration.reset_application_mode = true

$env.config.bracketed_paste = true

$env.config.use_ansi_coloring = "auto"

$env.config.error_style = "fancy"

$env.config.highlight_resolved_externals = true

$env.config.display_errors.exit_code = false
$env.config.display_errors.termination_signal = true

$env.config.footer_mode = 25

$env.config.table.mode = "single"
$env.config.table.index_mode = "always"
$env.config.table.show_empty = true
$env.config.table.padding.left = 1
$env.config.table.padding.right = 1
$env.config.table.trim.methodology = "wrapping"
$env.config.table.trim.wrapping_try_keep_words = true
$env.config.table.trim.truncating_suffix =  "..."
$env.config.table.header_on_separator = true
$env.config.table.abbreviated_row_count = null
$env.config.table.footer_inheritance = true
$env.config.table.missing_value_symbol = $"(ansi magenta_bold)nope(ansi reset)"

$env.config.datetime_format.table = null
$env.config.datetime_format.normal = $"(ansi blue_bold)%Y(ansi reset)(ansi yellow)-(ansi blue_bold)%m(ansi reset)(ansi yellow)-(ansi blue_bold)%d(ansi reset)(ansi black)T(ansi magenta_bold)%H(ansi reset)(ansi yellow):(ansi magenta_bold)%M(ansi reset)(ansi yellow):(ansi magenta_bold)%S(ansi reset)"

$env.config.filesize.unit = "metric"
$env.config.filesize.show_unit = true
$env.config.filesize.precision = 1

$env.config.render_right_prompt_on_last_line = false

$env.config.float_precision = 2

$env.config.ls.use_ls_colors = true

$env.config.hooks.pre_prompt = []

$env.config.hooks.pre_execution = [
  {||
    commandline
    | str trim
    | if ($in | is-not-empty) { print $"(ansi title)($in) — nu(char bel)" }
  }
]

$env.config.hooks.env_change = {}

$env.config.hooks.display_output = {||
  tee { table --expand | print }
  # SQLiteDatabase doesn't support equality comparisions
  | try { if $in != null { $env.last = $in } }
}

$env.config.hooks.command_not_found = []

# `nu-highlight` with default colors
#
# Custom themes can produce a lot more ansi color codes and make the output
# exceed discord's character limits
def nu-highlight-default [] {
  let input = $in
  $env.config.color_config = {}
  $input | nu-highlight
}

# Copy the current commandline, add syntax highlighting, wrap it in a
# markdown code block, copy that to the system clipboard.
#
# Perfect for sharing code snippets on Discord.
def "nu-keybind commandline-copy" []: nothing -> nothing {
  commandline
  | nu-highlight-default
  | [
    "```ansi"
    $in
    "```"
  ]
  | str join (char nl)
  | clip copy --ansi
}

$env.config.keybindings ++= [
  {
    name: copy_color_commandline
    modifier: control_alt
    keycode: char_c
    mode: [ emacs vi_insert vi_normal ]
    event: {
      send: executehostcommand
      cmd: 'nu-keybind commandline-copy'
    }
  }
]

$env.config.color_config.bool = {||
  if $in {
    "light_green_bold"
  } else {
    "light_red_bold"
  }
}

$env.config.color_config.string = {||
  if $in =~ "^(#|0x)[a-fA-F0-9]+$" {
    $in | str replace "0x" "#"
  } else {
    "white"
  }
}

$env.config.color_config.row_index = "light_yellow_bold"
$env.config.color_config.header = "light_yellow_bold"

do --env {
  def prompt-header [
    --left-char: string
  ]: nothing -> string {
    let code = $env.LAST_EXIT_CODE

    let body = do {
      mut body = []

      # SSH INDICATOR `@hostname`
      if ($env.SSH_CONNECTION? | is-not-empty) {
        let hostname = try {
          hostname
        } catch {
          "remote"
        }

        $body ++= [ $"(ansi light_green_bold)@($hostname)" ]
      }

      # PATH OR JJ PROJECT `~/Downloads` or `ncc -> modules`
      # Case insensitive filesystems strike again!
      # https://github.com/nushell/nushell/issues/16205
      let pwd = pwd | path expand

      let jj_workspace_root = try {
        jj workspace root err> $null_device
      }

      $body ++= [ (if $jj_workspace_root != null {
        let subpath = $pwd | path relative-to $jj_workspace_root
        let subpath = if ($subpath | is-not-empty) {
          $" (ansi magenta_bold)→(ansi reset) (ansi blue)($subpath)"
        }

        $"(ansi light_yellow_bold)($jj_workspace_root | path basename)($subpath)"
      } else {
        let pwd = if ($pwd | str starts-with $env.HOME) {
          "~" | path join ($pwd | path relative-to $env.HOME)
        } else {
          $pwd
        }

        $"(ansi cyan)($pwd)"
      }) ]

      $body | str join $"(ansi reset) "
    }

    let prefix = do {
      mut prefix = []

      # EXIT CODE
      if $code != 0 {
        $prefix ++= [ $"(ansi light_red_bold)($code)" ]
      }

      # COMMAND DURATION
      let command_duration = ($env.CMD_DURATION_MS | into int) * 1ms
      if $command_duration > 2sec {
        $prefix ++= [ $"(ansi light_magenta_bold)($command_duration)" ]
      }

      $"(ansi light_yellow_bold)($left_char)($prefix | each { $'┫($in)(ansi light_yellow_bold)┣' } | str join '━')━(ansi reset)"
    }

    let suffix = do {
      mut suffix = []

      # NIX SHELL
      if ($env.IN_NIX_SHELL? | is-not-empty) {
        $suffix ++= [ $"(ansi light_blue_bold)nix" ]
      }

      $suffix | each { $'(ansi light_yellow_bold)•(ansi reset) ($in)(ansi reset)' } | str join " "
    }

    ([ $prefix, $body, $suffix ] | str join " ") + (char newline)
  }

  $env.PROMPT_INDICATOR = $"(ansi light_yellow_bold)┃(ansi reset) "
  $env.PROMPT_INDICATOR_VI_NORMAL = $env.PROMPT_INDICATOR
  $env.PROMPT_INDICATOR_VI_INSERT = $env.PROMPT_INDICATOR
  $env.PROMPT_MULTILINE_INDICATOR = $env.PROMPT_INDICATOR
  $env.PROMPT_COMMAND = {||
    prompt-header --left-char "┏"
  }
  $env.PROMPT_COMMAND_RIGHT = {||
    let jj_status = try {
      jj --quiet --color always --ignore-working-copy log --no-graph --revisions @ --template '
        separate(
          " ",
          if(empty, label("empty", "(empty)")),
          coalesce(
            surround(
              "\"",
              "\"",
              if(
                description.first_line().substr(0, 24).starts_with(description.first_line()),
                description.first_line().substr(0, 24),
                description.first_line().substr(0, 23) ++ "…"
              )
            ),
            label(if(empty, "empty"), description_placeholder)
          ),
          bookmarks.join(", "),
          change_id.shortest(),
          commit_id.shortest(),
          if(conflict, label("conflict", "(conflict)")),
          if(divergent, label("divergent prefix", "(divergent)")),
          if(hidden, label("hidden prefix", "(hidden)")),
        )
      ' err> $null_device
    } catch {
      ""
    }

    $jj_status
  }

  $env.TRANSIENT_PROMPT_INDICATOR = "  "
  $env.TRANSIENT_PROMPT_INDICATOR_VI_INSERT = $env.TRANSIENT_PROMPT_INDICATOR
  $env.TRANSIENT_PROMPT_INDICATOR_VI_NORMAL = $env.TRANSIENT_PROMPT_INDICATOR
  $env.TRANSIENT_PROMPT_MULTILINE_INDICATOR = $env.TRANSIENT_PROMPT_INDICATOR
  $env.TRANSIENT_PROMPT_COMMAND = {||
    prompt-header --left-char "━"
  }
  $env.TRANSIENT_PROMPT_COMMAND_RIGHT = $env.PROMPT_COMMAND_RIGHT
}

let menus = [
  {
    name: completion_menu
    only_buffer_difference: false
    marker: $env.PROMPT_INDICATOR
    type: {
      layout: ide
      min_completion_width: 0
      max_completion_width: 150
      max_completion_height: 25
      padding: 0
      border: false
      cursor_offset: 0
      description_mode: "prefer_right"
      min_description_width: 0
      max_description_width: 50
      max_description_height: 10
      description_offset: 1
      correct_cursor_pos: true
    }
    style: {
      text: white
      selected_text: white_reverse
      description_text: yellow
      match_text: { attr: u }
      selected_match_text: { attr: ur }
    }
  }
  {
    name: history_menu
    only_buffer_difference: true
    marker: $env.PROMPT_INDICATOR
    type: {
      layout: list
      page_size: 10
    }
    style: {
      text: white
      selected_text: white_reverse
    }
  }
]

$env.config.menus = $env.config.menus
| where name not-in ($menus | get name)
| append $menus

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
      print $"(ansi yellow)thought dump was not modified, doing nothing(ansi reset)"
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

# Retrieve the output of the last command.
def _ []: nothing -> any {
  $env.last?
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

def --env "nu-complete jc" [commandline: string] {
  let stor = stor open

  if $stor.jc_completions? == null {
    stor create --table-name jc_completions --columns { value: str, description: str, is_flag: bool }
  }

  if $stor.jc_completions_ran? == null {
    stor create --table-name jc_completions_ran --columns { _: bool }
  }

  if $stor.jc_completions_ran == [] { try {
    let about = ^jc --about
    | from json

    let magic = $about
    | get parsers
    | each { { value: $in.magic_commands?, description: $in.description } }
    | where value != null
    | flatten

    let options = $about
    | get parsers
    | select argument description
    | rename value description

    let inherent = ^jc --help
    | lines
    | split list "" # Group with empty lines as boundary.
    | where { $in.0? == "Options:" } | get 0 # Get the first section that starts with "Options:"
    | skip 1 # Remove header
    | each { str trim }
    | parse "{short},  {long} {description}"
    | update description { str trim }
    | each {|record|
      [[value, description];
        [$record.short, $record.description],
        [$record.long, $record.description],
      ]
    }
    | flatten

    for entry in $magic {
      stor insert --table-name jc_completions --data-record ($entry | insert is_flag false)
    }

    for entry in ($options ++ $inherent) {
      stor insert --table-name jc_completions --data-record ($entry | insert is_flag true)
    }

    stor insert --table-name jc_completions_ran --data-record { _: true }
  } }

  if ($commandline | str contains "-") {
    $stor.jc_completions
  } else {
    $stor.jc_completions
    | where is_flag == 0
  } | select value description
}

# Run `jc` (JSON Converter).
def --wrapped jc [...arguments: string@"nu-complete jc"]: [any -> table, any -> record, any -> string] {
  let run = ^jc ...$arguments | complete

  if $run.exit_code != 0 {
    error make {
      msg: "jc exection failed"
      label: {
        text: ($run.stderr | str replace "jc:" "" | str replace "Error -" "" | str trim)
        span: (metadata $arguments).span
      }
    }
  }

  if "--help" in $arguments or "-h" in $arguments {
    $run.stdout
  } else {
    $run.stdout | from json
  }
}
