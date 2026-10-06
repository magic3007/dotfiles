# neovim

Two configs, both tracked as git submodules and symlinked from `~/.config/nvim`:

| Config | Submodule | Purpose |
|---|---|---|
| `nvim-basic-ide/` | [magic3007/nvim-basic-ide](https://github.com/magic3007/nvim-basic-ide) (`custom` branch) | the active config — lightweight IDE: LSP, cmp, treesitter |
| `NvChad/` | NvChad | full IDE setup, not currently linked |

`install.conf.yaml` links `~/.config/nvim` → `neovim/nvim-basic-ide`.

## Plugin revisions are pinned on purpose

`nvim-basic-ide/lua/user/plugins.lua` pins every plugin to a 2022 commit. The
config is written against the plugin APIs of that era; letting plugins float
forward breaks it (e.g. 2026 `nvim-lspconfig` no longer exposes
`lspconfig.server_configurations.*`, which 2022 `mason-lspconfig` requires, and
the newest `nvim-treesitter` dropped the `nvim-treesitter.configs` /
`nvim-treesitter.query` modules that `nvim-ts-context-commentstring`,
`vim-illuminate` and `indent-blankline` load).

Two of those pins had drifted; `scripts/post-install.d/20-neovim-runtime.sh` puts
them back, and also applies the local patches in `patches/` — see the 0.12
compatibility list below.

## Neovim 0.12 compatibility work

The local Neovim is 0.12, which is newer than everything the config assumes.
Four kinds of fix keep startup silent:

1. **Plugin revisions restored** — `scripts/post-install.d/20-neovim-runtime.sh`
   checks out
   `nvim-treesitter` and `nvim-lspconfig` at the pinned commits. `bash`,
   `python` and `cpp` also had never been compiled; `lua`, `markdown` and
   `markdown_inline` are built into Neovim.
2. **tree-sitter predicate conflict** — the 2022 `nvim-treesitter` registers a
   `has-ancestor?` predicate that 0.12 already ships; re-registering raises and
   aborts module load. `patches/nvim-treesitter-nvim0.12-predicates.patch` makes
   those registrations tolerate a pre-existing name while still raising on real
   errors. Applied by the script above.
3. **Deprecated helpers used by the pinned plugins** — `init.lua` re-provides
   `vim.tbl_add_reverse_lookup`, `vim.tbl_islist` and `vim.tbl_flatten` with the
   same behaviour minus the deprecation notice (nvim-cmp, bufferline,
   nvim-treesitter call them). `lua/user/lsp/handlers.lua` no longer uses
   `vim.lsp.with()`, which 0.12 deprecated.
4. **bufferline nil segment** — the pinned bufferline.nvim measures a tab with
   `get_component_size({ duplicate_prefix, name, spacing(), icon, suffix })`.
   For a buffer that is not duplicated `duplicate_prefix` is nil, so the table
   has a hole, 0.12's **strict** `vim.tbl_islist` rejects it and every render
   raises `E5108: ... Segments must be a list` (the current buffer is replaced
   by a "Press ENTER" prompt). `patches/bufferline-nil-segments.patch` applies
   the `filter_invalid` that call site was missing. The upstream fix (`dd86c31`)
   cannot be taken as a version bump here: it defers to `vim.tbl_isarray`,
   which Neovim 0.12.2 does not provide, so it would fall back to the same
   strict check.

`wakatime/vim-wakatime` was removed from `plugins.lua`: no API key is configured
anywhere, so it only printed a warning on every start. It is still used by the
shell via `zsh-wakatime`; only the Neovim plugin was dropped.

## Usage

```bash
./install                      # links the config and runs the post-install hooks
nvim --headless -c q           # should print nothing
```

The hooks live in `scripts/post-install.d/` and are idempotent; `./install` runs
all of them via `scripts/post-install.sh`. The Neovim hook needs the plugins to
be installed already, so start nvim at least once first (packer bootstraps
itself on first launch). After a `:PackerUpdate`, run
`scripts/post-install.d/20-neovim-runtime.sh` directly — packer honours the
pins on install, not on update.

## When something breaks on upgrade

`git -C neovim/nvim-basic-ide log` shows the customizations on top of upstream.
A plugin that drifted from its pin is the usual suspect — compare with
`lua/user/plugins.lua`, then re-run `scripts/post-install.d/20-neovim-runtime.sh`.
