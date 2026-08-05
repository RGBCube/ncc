{ self }:
let
  inherit (self) importTOML;
  inherit (self.attrsets) genAttrs optionalAttrs;
  inherit (self.lists) singleton;
  inherit (self.meta) getExe getExe';
  inherit (self.trivial) const flip;

  mkPriority = priority: level: { inherit level priority; };

  clippy = {
    lints = {
      rust.warnings = mkPriority 1 "deny";

      clippy = {
        pedantic = mkPriority (-1) "warn";

        restriction = mkPriority (-1) "warn";
        blanket_clippy_restriction_lints = "allow";
      }
      // flip genAttrs (const "allow") [
        "alloc_instead_of_core"
        "allow_attributes_without_reason"
        "arbitrary_source_item_ordering"
        "arithmetic_side_effects"
        "as_conversions"
        "as_pointer_underscore"
        "as_underscore"
        "big_endian_bytes"
        "clone_on_ref_ptr"
        "dbg_macro"
        "disallowed_script_idents"
        "doc_include_without_cfg"
        "else_if_without_else"
        "error_impl_error"
        "exhaustive_enums"
        "exhaustive_structs"
        "expect_used"
        "field_scoped_visibility_modifiers"
        "float_arithmetic"
        "host_endian_bytes"
        "impl_trait_in_params"
        "implicit_return"
        "indexing_slicing"
        "inline_asm_x86_intel_syntax"
        "integer_division"
        "integer_division_remainder_used"
        "large_include_file"
        "let_underscore_must_use"
        "let_underscore_untyped"
        "little_endian_bytes"
        "map_err_ignore"
        "match_ref_pats"
        "match_same_arms"
        "missing_assert_message"
        "missing_docs_in_private_items"
        "missing_errors_doc"
        "missing_inline_in_public_items"
        "missing_panics_doc"
        "missing_trait_methods"
        "mod_module_files"
        "multiple_inherent_impl"
        "mutex_atomic"
        "mutex_integer"
        "needless_borrowed_reference"
        "new_ret_no_self"
        "new_without_default"
        "non_ascii_literal"
        "panic"
        "panic_in_result_fn"
        "partial_pub_fields"
        "print_stderr"
        "print_stdout"
        "pub_use"
        "pub_with_shorthand"
        "pub_without_shorthand"
        "question_mark_used"
        "ref_patterns"
        "renamed_function_params"
        "same_name_method"
        "semicolon_outside_block"
        "separated_literal_suffix"
        "shadow_reuse"
        "shadow_same"
        "shadow_unrelated"
        "single_call_fn"
        "single_char_lifetime_names"
        "single_match_else"
        "std_instead_of_alloc"
        "std_instead_of_core"
        "string_add"
        "string_slice"
        "todo"
        "too_many_lines"
        "try_err"
        "unimplemented"
        "unnecessary_safety_comment"
        "unnecessary_safety_doc"
        "unreachable"
        "unwrap_in_result"
        "unwrap_used"
        "use_debug"
        "wildcard_enum_match_arm"
      ];
    };
  };
in
{
  rust.package =
    {
      source,
      overrideAttrs ? (_: { }),
    }:
    { inputs, lib, ... }:
    {
      perSystem =
        {
          self',
          pkgs,
          system,
          ...
        }:
        let
          inherit (lib.fixedPoints) fix;

          toml = pkgs.formats.toml { };

          inherit (importTOML <| source + "/Cargo.toml") package;

          toolchain = inputs.fenix.packages.${system}.complete.toolchain;

          clippyConfDir = pkgs.linkFarm "clippy-configuration" {
            "clippy.toml" = toml.generate "clippy.toml" {
              avoid-breaking-exported-api = false;

              allowed-idents-below-min-chars = [
                "x"
                "y"
                "z"
                "r"
                "g"
                "b"
                "c"
                "s"
                "n"
              ];

              allowed-wildcard-imports = singleton "super";
            };
          };

          rustfmtToml = toml.generate "rustfmt.toml" {
            inherit (package) edition;

            # float_literal_trailing_zero = "Always"; # TODO: Warning for some reason?
            condense_wildcard_suffixes = true;
            doc_comment_code_block_width = 100;
            enum_discrim_align_threshold = 60;
            force_multiline_blocks = true;
            format_code_in_doc_comments = true;
            format_macro_matchers = true;
            format_strings = true;
            group_imports = "StdExternalCrate";
            hex_literal_case = "Upper";
            imports_granularity = "Crate";
            imports_layout = "Vertical";
            inline_attribute_width = 60;
            match_block_trailing_comma = true;
            max_width = 100;
            newline_style = "Unix";
            normalize_comments = true;
            normalize_doc_attributes = true;
            overflow_delimited_expr = true;
            struct_field_align_threshold = 60;
            tab_spaces = 3;
            unstable_features = true;
            use_field_init_shorthand = true;
            use_try_shorthand = true;
            wrap_comments = true;
          };

          taploToml = toml.generate "taplo.toml" {
            formatting = {
              align_entries = true;
              column_width = 100;
              compact_arrays = false;
              reorder_inline_tables = true;
              reorder_keys = true;
            };

            rule = singleton {
              include = singleton "**/Cargo.toml";
              keys = singleton "package";

              formatting.reorder_keys = false;
            };
          };

          inherit
            (fix (self: {
              overrideRootCrate =
                mkOverrides:
                pkgs.callPackage
                  "${
                    (import "${inputs.crate2nix}/tools.nix" { inherit pkgs; }).generatedCargoNix {
                      inherit (package) name;
                      src = source;
                    }
                  }/default.nix"
                  {
                    buildRustCrateForPkgs =
                      pkgs: crate:
                      pkgs.buildRustCrate.override {
                        cargo = toolchain;
                        clippy = toolchain;
                        rustc = toolchain;
                      }
                      <| crate // optionalAttrs (crate.crateName == package.name) (mkOverrides pkgs);
                  };

              cargoNix = self.overrideRootCrate (_: { });

              cargoNixDebug = self.overrideRootCrate (_: {
                release = false;
              });

              cargoNixClippy = self.overrideRootCrate (_: {
                useClippy = true;
                inherit (clippy) lints;
                CLIPPY_CONF_DIR = clippyConfDir;
              });
            }))
            cargoNix
            cargoNixDebug
            cargoNixClippy
            ;
        in
        {
          packages.${package.name} = cargoNix.rootCrate.build.overrideAttrs overrideAttrs;
          packages."${package.name}-debug" = cargoNixDebug.rootCrate.build.overrideAttrs overrideAttrs;

          packages."${package.name}-rustfmt" = pkgs.writeShellScriptBin "rustfmt" ''
            exec ${getExe' toolchain "rustfmt"} --config-path ${rustfmtToml} "$@"
          '';

          devShells.${package.name} = pkgs.mkShell {
            packages = singleton toolchain;

            env.CLIPPY_CONF_DIR = clippyConfDir;
            env.RUSTFMT = getExe self'.packages."${package.name}-rustfmt";
            env.TAPLO_CONFIG = taploToml;
          };

          checks."${package.name}-package" = self'.packages.${package.name};
          checks."${package.name}-test" = cargoNix.rootCrate.build.override { runTests = true; };
          checks."${package.name}-clippy" = cargoNixClippy.rootCrate.build;

          checks."${package.name}-fmt" =
            pkgs.runCommand "${package.name}-fmt"
              {
                nativeBuildInputs = singleton toolchain;

                env.RUSTFMT = getExe self'.packages."${package.name}-rustfmt";
              }
              ''
                cd ${source}
                cargo fmt --check
                touch $out
              '';

          checks."${package.name}-toml-fmt" = pkgs.runCommand "${package.name}-toml-fmt" { } ''
            cd ${source}
            ${getExe pkgs.taplo} format --check --config ${taploToml}
            touch $out
          '';

          checks."${package.name}-audit" = pkgs.runCommand "${package.name}-audit" { } ''
            ${getExe pkgs.cargo-audit} audit --no-fetch --stale --db ${inputs.advisory-db} --file ${source + "/Cargo.lock"}
            touch $out
          '';
        };
    };
}
