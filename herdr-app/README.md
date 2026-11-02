# Herdr app

The Herdr **desktop app** (https://herdr.dev/download): a native window that shows
terminals and coding agents. It is a separate program from `herdr` (the
agent-aware terminal multiplexer, config in `../herdr/`), and a third one from
`herdr-core` (`hc`), the runtime that actually owns the terminals.

## Install

`../scripts/install-herdr-app.sh`, wired into `install.conf.yaml` (network phase,
macOS only). It:

- reuses an existing `Herdr.app` — `/Applications/Herdr.app` (dragged from the
  dmg) or `~/Applications/Herdr.app` — and only downloads when there is none;
- never overwrites an existing bundle, because the app self-updates;
- keeps a Developer ID–signed bundle byte-identical (changing it invalidates the
  signature, and with it macOS' permission grants);
- installs `herdr-core` only when it is missing, since the app maintains it;
- creates the `~/.local/bin/herdr-app` shim, and `~/.local/bin/hc` when needed.

Upstream's own installer (`releases.herdr.dev/app/install.sh`) always installs
into `~/Applications`, so running it here would leave two bundles and split
Launchpad / `herdr-app` across both.

## Tracked files

| File | How it reaches `~/.config/herdr-app/` | Why |
|---|---|---|
| `themes/dracula.json` | symlink (`link:` in `install.conf.yaml` and `sync.conf.yaml`) | the app never writes theme files back |
| `settings.json` | seed (`scripts/post-install.d/10-seed-configs.sh`) | the app rewrites it via temp-file + rename, which replaces a symlink with a regular file |
| `keys.json` | seed, same as above | same |

The theme is additionally pinned per layout with

```sh
herdr-app do app.theme --name dracula
```

because the app drops the `theme` / `appearance` keys from `settings.json`
whenever it rewrites that file. That lands in
`~/.config/herdr-app/layouts/.state/<layout>.json` — runtime state, untracked.

Everything else under `~/.config/herdr-app/` (the app's own `AGENTS.md`,
`*.d.ts`, `frame/`, `installed.json`, `data/`, `icons/`, `mods/`, `view.json`,
`shared.json`, `layouts/`) is written by the app and stays local.
