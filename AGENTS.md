# Version Control

Only use `git` to `git add` new files for Nix, otherwise always use `jj`.

# Development Rules

- Never `find /nix/store` or anything equivalent. Prefer using
  `nix flake archive --json`.

# Nix Style Rules

- Prefer `lib.lists.singleton` over a single item list.
- Always `let inherit (lib.<path>) foo;` with full paths like `lib.lists.head`,
  never `inherit (lib) foo` unless `foo` has no submodule path.
- Always use the Dendritic Pattern (flake-parts `*.mod.nix` auto-discovery).
- Always prefer `${getExe pkgs.something}` over bare command names in shell
  aliases. Use `package = getExe pkgs.something` when there are multiple usages.
- Leave an empty line between unrelated options.
- Module key order: environment variables, aliases, packages, XDG config,
  program-specific configuration.
- Never put values in `let` bindings that duplicate module system options. If a
  value is set through `config.*`, always reference it through `config.*`. `let`
  bindings for hardcoded values that could be overridden via the module system
  are forbidden. `let` is fine for computed derivations, helper functions, and
  `getExe` shortcuts.
- Prefer destructuring attrset arguments when it improves clarity. Use
  `{ home, ... }:` instead of `value: value.home` where it makes sense.
- On Linux, use KDE applications (except Plasma). Dolphin over Thunar, Ark over
  xfce archive tools, etc.
- Always put `/* lang */` before multiline code strings, e.g. `/* bash */ ''`.
- Category/section comments should be uppercase with no period, e.g. `# DOCK`,
  not `# Dock.`.
- Prefer setting individual options with `mkIf` over wrapping entire attrsets.
  Use `foo.bar = mkIf condition value;` not
  `foo = mkIf condition { bar = value; };` when possible.
- Never refer to the OS as "macOS" in file names or module names. Always use
  "darwin". E.g. `darwin-wm.mod.nix`, not `macos-wm.mod.nix`.
- Inline package definitions should use `pkgs.callPackage` with destructured
  args, e.g. `pkgs.callPackage ({ stdenv, writeText }: ...) { }`.
- For inline source code in packages, use `writeText` directly in the `src`
  attribute rather than a separate `let` binding.
- If a package is its own concern (e.g. a custom C tool), put the `perSystem`
  definition in its own `.mod.nix` file separate from the module that uses it.
- Prefer `<|` (pipe-last) over parentheses when the parenthesized expression is
  the final argument to a function. E.g. `mkIf condition <| toJSON { ... }`
  instead of `mkIf condition (toJSON { ... })`. Does not apply when the
  parenthesized expression is not the last argument (e.g.
  `callPackage (...) { }`). Does not work with `if`, `let`, or lambda
  expressions on the RHS — those still need parentheses.
- In modules that define both `darwinModules` and other module types, put
  `darwinModules` first.
- Do not use `builtins.` in modules.
- Never use `rec` ever. Worst case, define a custom `fix`.
