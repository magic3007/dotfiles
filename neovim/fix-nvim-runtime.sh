#!/usr/bin/env bash
# Restore the parts of the nvim-basic-ide runtime that live outside this repo
# (~/.local/share/nvim): plugin revisions and tree-sitter parsers.
#
# Why this is needed
# ------------------
# lua/user/plugins.lua pins every plugin to a 2022 commit, because the config
# uses the plugin APIs of that era. Two plugins had drifted to 2026 revisions
# (nvim-lspconfig, nvim-treesitter), which broke the lspconfig/mason integration
# and every treesitter consumer (vim-illuminate, nvim-ts-context-commentstring,
# indent-blankline). On top of that, Neovim 0.12 ships tree-sitter predicates
# that the 2022 nvim-treesitter re-registers, which raises during setup, so
# patches/nvim-treesitter-nvim0.12-predicates.patch is applied to it.
#
# Idempotent: safe to re-run. Run after ./install, and again after any
# :PackerUpdate (packer honors the pins on install, not on update).
set -euo pipefail

PACK_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/nvim/site/pack/packer/start"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCH_FILE="$SCRIPT_DIR/patches/nvim-treesitter-nvim0.12-predicates.patch"
PARSERS=(lua markdown markdown_inline bash python cpp)

# Must match the `commit = "..."` values in lua/user/plugins.lua.
declare -A PINS=(
  [nvim-treesitter]=8e763332b7bf7b3a426fd8707b7f5aa85823a5ac
  [nvim-lspconfig]=f11fdff7e8b5b415e5ef1837bdcdd37ea6764dda
)

if [[ ! -d $PACK_DIR ]]; then
  echo "no plugins at $PACK_DIR — start nvim once so packer installs them, then re-run this script." >&2
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

# A tree-sitter parser is only compiled once; afterwards this is a no-op.
ts_dir="$PACK_DIR/nvim-treesitter"
if [[ -d $ts_dir/.git && -f $PATCH_FILE ]]; then
  if git -C "$ts_dir" apply --reverse --check "$PATCH_FILE" 2>/dev/null; then
    echo "ok    nvim-treesitter predicate patch already applied"
  elif git -C "$ts_dir" apply --check "$PATCH_FILE" 2>/dev/null; then
    git -C "$ts_dir" apply "$PATCH_FILE"
    echo "patch nvim-treesitter predicate tolerance"
  else
    echo "warn  nvim-treesitter patch does not apply cleanly — inspect $ts_dir" >&2
  fi
fi

if command -v nvim >/dev/null 2>&1; then
  echo "install tree-sitter parsers: ${PARSERS[*]}"
  nvim --headless -c "TSInstallSync ${PARSERS[*]}" -c 'qa!' || true
fi

echo "done — verify with: nvim --headless -c q   (expect no output)"
