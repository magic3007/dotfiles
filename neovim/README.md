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

Two of those pins had drifted; `fix-nvim-runtime.sh` puts them back.

## Neovim 0.12 compatibility work

The local Neovim is 0.12, which is newer than everything the config assumes.
Three kinds of fix keep startup silent:

1. **Plugin revisions restored** — `fix-nvim-runtime.sh` (this repo) checks out
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

`wakatime/vim-wakatime` was removed from `plugins.lua`: no API key is configured
anywhere, so it only printed a warning on every start. It is still used by the
shell via `zsh-wakatime`; only the Neovim plugin was dropped.

## Usage

```bash
./install                      # links the config (among everything else)
neovim/fix-nvim-runtime.sh     # once, after plugins exist; then after any :PackerUpdate
nvim --headless -c q           # should print nothing
```

`fix-nvim-runtime.sh` is idempotent. It needs the plugins to be installed
already, so start nvim at least once first (packer bootstraps itself on first
launch).

## When something breaks on upgrade

`git -C neovim/nvim-basic-ide log` shows the customizations on top of upstream.
A plugin that drifted from its pin is the usual suspect — compare with
`lua/user/plugins.lua`, then re-run `neovim/fix-nvim-runtime.sh`.
