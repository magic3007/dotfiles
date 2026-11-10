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
| `themes/noir.json` | symlink (`link:` in `install.conf.yaml` and `sync.conf.yaml`) | the app never writes theme files back |
| `themes/dracula.json` | symlink, same as above | same |
| `settings.json` | seed (`scripts/post-install.d/10-seed-configs.sh`) | the app rewrites it via temp-file + rename, which replaces a symlink with a regular file |
| `keys.json` | seed, same as above | same |

## Themes

`noir` is the active one. It is not a port of an existing palette: the values
were measured off the screenshot in
<https://x.com/lexrus/status/2118356752412684788> (Lex Tang's "Herdr vs Tern"),
sampling flat regions of the window and taking the mode of each.

| Token | Value | Where it was read from |
|---|---|---|
| `background` | `#191920` | the gitui pane, i.e. the raw terminal background nothing paints over |
| `colors.chrome` | `#111116` | tab bar, sidebar, status bar, pane headers — identical in all four |
| `colors.canvas` | `#131217` | the gap between pane cards |
| `foreground` | `#f2f2f6` | sidebar labels |
| `ansi` | Tokyo Night | the accents gitui draws (`#f7768e` red, `#9ece6a` green, `#7dcfff` cyan, `#bb9af7` purple all matched it exactly) |

`chrome` and `canvas` are listed explicitly because herdr derives them from
`background` (roughly `×0.68`); the derivation lands close but not on the
measured values, and `colors` overrides win in both appearances.

The other two panes in that screenshot are **not** this theme: the `omp` pane
paints `#131217` and the GitHub mod paints `#15151e` itself. Only the gitui
pane shows the terminal background.

The theme is pinned per layout with

```sh
herdr-app do app.theme --name noir
```

because the app drops the `theme` / `appearance` keys from `settings.json`
whenever it rewrites that file. That lands in
`~/.config/herdr-app/layouts/.state/<layout>.json` — runtime state, untracked.

Everything else under `~/.config/herdr-app/` (the app's own `AGENTS.md`,
`*.d.ts`, `frame/`, `installed.json`, `data/`, `icons/`, `mods/`, `view.json`,
`shared.json`, `layouts/`) is written by the app and stays local.
