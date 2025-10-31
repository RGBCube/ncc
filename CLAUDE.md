- Never use `enabled` or `disabled`, prefer the module option `enable` and set
  it to `true`/`false`.
- Prefer `lib.lists.singleton` over a single item list.
- Always `let inherit (lib.<...>) foo`; when you want to use foo. Prefer
  absolute paths such as `lib.lists.head` over `lib.head` when doing this.
  NEVER, EVER do `inherit (lib) foo`, unless `foo` does not exist elsewhere.
- Always use the Dendritic Pattern.
- Always prefer `${getExe pkgs.something}` over just `something` in shell
  aliases and other stuff. Don't depend on `PATH`.
- For the above, prefer doing `package = getExe pkgs.something` when there are
  multiple usages. A literal `package` identifier, and not `bat` for the `bat`
  package.
- Leave an empty line between unrelated options, such as `enable` and
  `something-else-that-does-not-explicitly-enable-anything`.
- Module key order is as follows:
  - Environment variables.
  - Aliases.
  - Packages.
  - XDG Config.
  - Program-specific configuration.
