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
These fixes keep startup and per-buffer rendering clean:

1. **Plugin revisions restored** — `scripts/post-install.d/20-neovim-runtime.sh`
   checks out
   `nvim-treesitter` and `nvim-lspconfig` at the pinned commits. `bash`,
   `python` and `cpp` also had never been compiled; `lua`, `markdown` and
   `markdown_inline` are built into Neovim.
2. **tree-sitter predicate conflict and capture shape** — the 2022
   `nvim-treesitter` registers a `has-ancestor?` predicate that 0.12 already
   ships; re-registering raises and aborts module load. 0.12 also hands
   predicate/directive handlers the captures as **a list of nodes per capture
   id**, while the 0.8 API passed the node itself, so `has-type?` called
   `node:type()` on a table and every `cpp` buffer raised
   `query_predicates.lua:115: attempt to call method 'type' (a nil value)` from
   indent-blankline's tree-sitter indent. `patches/nvim-treesitter-nvim0.12-predicates.patch`
   both tolerates a pre-existing name and normalises the capture shape
   (`captured_node`). Applied by the script above.
3. **Legacy node name in the lua injection query** — the pinned
   `queries/lua/injections.scm` matches the *anonymous* node `"string_content"`,
   which the lua grammar Neovim 0.12 bundles no longer has (it is a named node
   there). The query fails to compile, which fails parser creation for the whole
   buffer: opening any `.lua` file raised
   `Parser could not be created for buffer 1 and language "lua"` and the buffer
   had no highlighting. `patches/nvim-treesitter-lua-injection-node.patch`
   rewrites it as `(string content: (string_content) @query)`.
4. **Deprecated helpers used by the pinned plugins** — `init.lua` re-provides
   `vim.tbl_add_reverse_lookup`, `vim.tbl_islist` and `vim.tbl_flatten` with the
   same behaviour minus the deprecation notice (nvim-cmp, bufferline,
   nvim-treesitter call them). `lua/user/lsp/handlers.lua` no longer uses
   `vim.lsp.with()`, which 0.12 deprecated.
5. **bufferline nil segment** — the pinned bufferline.nvim measures a tab with
   `get_component_size({ duplicate_prefix, name, spacing(), icon, suffix })`.
   For a buffer that is not duplicated `duplicate_prefix` is nil, so the table
   has a hole, 0.12's **strict** `vim.tbl_islist` rejects it and every render
   raises `E5108: ... Segments must be a list` (the current buffer is replaced
   by a "Press ENTER" prompt). `patches/bufferline-nil-segments.patch` applies
   the `filter_invalid` that call site was missing. The upstream fix (`dd86c31`)
   cannot be taken as a version bump here: it defers to `vim.tbl_isarray`,
   which Neovim 0.12.2 does not provide, so it would fall back to the same
   strict check.
6. **Removed tree-sitter query aliases** — Neovim 0.12 dropped
   `vim.treesitter.query.get_query` / `parse_query` / `get_query_files`, which
   the pinned `nvim-treesitter` still calls (`query.lua` from its indent path,
   plus `health.lua` and `configs.lua`). With indent-blankline's
   `use_treesitter = true` (`lua/user/indentline.lua`), opening a `.py` file
   raised `query.lua:91: attempt to call field 'get_query' (a nil value)` on
   every redraw and the buffer lost its tree-sitter indents. `init.lua` maps the
   removed names onto `get` / `parse` / `get_files` before any plugin loads.
7. **Renamed health writers** — 0.12 turned `vim.health.report_start` /
   `report_ok` / `report_info` / `report_warn` / `report_error` into
   `vim.health.start` / `ok` / … . `:checkhealth nvim-treesitter` died with
   `health.lua:17: attempt to call field 'report_start' (a nil value)`; `init.lua`
   now aliases the old names before any plugin loads.
8. **Deprecation notices no longer block the UI** — the pinned plugins call
   about eight APIs 0.12 deprecates (`vim.lsp.for_each_buffer_client`,
   `client.supports_method`, `vim.lsp.start_client`, `vim.str_utfindex`,
   `vim.validate{…}`, …). `vim.deprecate()` echoes each one once per session,
   and that echo is what stopped file open at
   `Press ENTER or type command to continue`. `init.lua` wraps `vim.deprecate`
   so such calls are still recorded for `:checkhealth vim.deprecated` — the
   inventory stays complete — but are not echoed. A deprecation that names its
   owning plugin still notifies.
9. **mason stopped reinstalling on every start** — `lua/user/lsp/mason.lua` no
   longer sets `ensure_installed`, because the pinned mason-lspconfig reruns the
   installer for each listed server on every launch and this pinned mason fails
   at the link step (`bin/<server> is already linked`), which printed an
   `[mason] [ERROR]` line on every start. All servers are installed; use
   `:MasonInstall <server>` when adding one.

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
