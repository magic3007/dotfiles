#!/usr/bin/env bash
# Restore the parts of the nvim-basic-ide runtime that live outside this repo
# (~/.local/share/nvim): plugin revisions, local patches and tree-sitter
# parsers. Runs as a post-install hook (scripts/post-install.sh); it used to be
# neovim/fix-nvim-runtime.sh, which had to be remembered by hand.
#
# Why this is needed
# ------------------
# lua/user/plugins.lua pins every plugin to a 2022 commit, because the config
# uses the plugin APIs of that era. Two plugins had drifted to 2026 revisions
# (nvim-lspconfig, nvim-treesitter), which broke the lspconfig/mason integration
# and every treesitter consumer (vim-illuminate, nvim-ts-context-commentstring,
# indent-blankline). On top of that, Neovim 0.12 ships tree-sitter predicates
# that the 2022 nvim-treesitter re-registers, which raises during setup, so
# neovim/patches/nvim-treesitter-nvim0.12-predicates.patch is applied to it.
#
# The pinned bufferline.nvim hands vim.tbl_islist() a table that its own code
# builds with a leading nil (`{ duplicate_prefix, name, ... }` when the buffer
# is not duplicated). Neovim 0.12 counts that as a non-list, so rendering any
# buffer raised "E5108: ... Segments must be a list" — after which the pinned
# upstream fix (dd86c31) does not help on 0.12 because it relies on
# vim.tbl_isarray, which 0.12 does not provide.
# neovim/patches/bufferline-nil-segments.patch adds the nil filter the call site
# was missing.
#
# Idempotent: safe to re-run, and re-run automatically on every ./install.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PATCH_DIR="$REPO/neovim/patches"
APPLY_PATCHES="$REPO/scripts/apply-patches.sh"
PACK_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/nvim/site/pack/packer/start"
# Neovim ships lua/markdown/markdown_inline as built-in parsers; bash/python/cpp
# have to be compiled. Only the missing ones are built, so a re-run is a no-op.
PARSERS=(lua markdown markdown_inline bash python cpp)

# Must match the `commit = "..."` values in lua/user/plugins.lua.
declare -A PINS=(
  [nvim-treesitter]=8e763332b7bf7b3a426fd8707b7f5aa85823a5ac
  [nvim-lspconfig]=f11fdff7e8b5b415e5ef1837bdcdd37ea6764dda
)

# Local patches, keyed by the plugin's directory name under PACK_DIR. The patch
# files themselves live next to the config they belong to (neovim/patches/);
# scripts/apply-patches.sh only needs a git checkout to be idempotent.
declare -A PATCHES=(
  [nvim-treesitter]="$PATCH_DIR/nvim-treesitter-nvim0.12-predicates.patch"
  [bufferline.nvim]="$PATCH_DIR/bufferline-nil-segments.patch"
)

if [[ ! -d $PACK_DIR ]]; then
  echo "no plugins at $PACK_DIR — start nvim once so packer installs them, then re-run." >&2
  exit 0
fi

for plugin in "${!PINS[@]}"; do
  dir="$PACK_DIR/$plugin"
  pin="${PINS[$plugin]}"

  if [[ ! -d $dir/.git ]]; then
    echo "skip  $plugin (not installed)"
    continue
  fi

  head="$(git -C "$dir" rev-parse HEAD)"
  if [[ $head == "$pin" ]]; then
    echo "ok    $plugin already at ${pin:0:8}"
    continue
  fi

  if ! git -C "$dir" cat-file -e "$pin^{commit}" 2>/dev/null; then
    echo "fetch $plugin $pin"
    git -C "$dir" fetch --quiet origin "$pin" || git -C "$dir" fetch --quiet origin || true
  fi

  echo "pin   $plugin ${head:0:8} -> ${pin:0:8}"
  git -C "$dir" checkout --quiet "$pin"
done

for plugin in "${!PATCHES[@]}"; do
  "$APPLY_PATCHES" "$PACK_DIR/$plugin" "${PATCHES[$plugin]}"
done

if command -v nvim >/dev/null 2>&1; then
  langs_lua=$(printf "'%s'," "${PARSERS[@]}")
  missing="$(nvim --headless \
    -c "lua local m = {} for _, l in ipairs({ $langs_lua }) do if #vim.api.nvim_get_runtime_file('parser/' .. l .. '.*', true) == 0 then m[#m + 1] = l end end io.write(table.concat(m, ' '))" \
    -c 'qa!' 2>/dev/null || true)"

  # A tree-sitter parser is only compiled once; afterwards this is a no-op.
  if [[ -n ${missing// /} ]]; then
    echo "compile tree-sitter parsers: $missing"
    # </dev/null: TSInstallSync asks "reinstall ? y/n" about parsers that already
    # exist, and a terminal hangs on that prompt forever.
    nvim --headless -c "TSInstallSync $missing" -c 'qa!' </dev/null || true
  else
    echo "ok    all tree-sitter parsers available"
  fi
fi

echo "done — verify with: nvim --headless -c q   (expect no output)"
