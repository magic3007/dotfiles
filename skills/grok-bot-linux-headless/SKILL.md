---
name: grok-bot-linux-headless
description: |
  Keep the Grok Bot desktop client running headless on a Linux server (Ubuntu 22.04,
  no GPU, no display) so the remote machine shows "connected" and accepts commands.
  Use when: (1) the Linux machine keeps showing offline in the machine list, or a new
  duplicate registration with the same hostname appears after each restart, (2) the
  app window is blank (`#root` empty, no console errors) or stuck on
  "Setting up Grok Bot's computer", (3) `desktop.update.getStatus()` reports
  `unsupported-platform` so the app never self-updates, (4) Electron started with
  `--proxy-server` still can't reach the backend from behind the GFW.
author: Claude Code
version: 1.0.0
date: 2026-11-11
---

# Grok Bot headless on Linux

## Problem
A headless Grok Bot (Electron) on a Linux dev box looks logged in but never comes
online. Several different causes stack up and mask each other:
the client version is too old, the network path is half proxied, and something else
keeps restarting the app or wiping its config.

## Context / Trigger Conditions
- The machine list shows the host as `connected: false`, sometimes with 3 or 4 entries
  for the same hostname.
- The renderer is blank. `document.getElementById("root").childElementCount === 0`
  and there are no console errors.
- After a forced re-import of the bundle, the UI shows "Setting up Grok Bot's computer"
  and stays there.
- `desktop.cursorAccount.getStatus()` returns `kind: "logged-in"` anyway, so login
  is not the problem.

## Solution
1. **Check the version first. This was the real root cause.**
   Compare `dpkg -l grok-bot` with a client that works, such as the Mac's
   `~/Library/Application Support/Grok Bot/desktop-status.json` `appVersion`.
   The .deb build does not self-update (`unsupported-platform`). An old client
   (0.24.0 against 0.79.x) renders blank or sticks on "Setting up" forever.
   Upgrade from the official feed:
   ```sh
   curl -s https://api2.cursor.sh/updates/api/download/stable/linux-x64/sand \
     | python3 -c 'import json,sys;d=json.load(sys.stdin);print(d["version"],d["debUrl"])'
   curl -fLO "<debUrl>"
   systemctl --user stop grok-bot
   sudo apt-get install -y ./grok-bot_<ver>_amd64.deb
   systemctl --user start grok-bot
   ```
   The deb adds an apt source, so later upgrades are `sudo apt install --only-upgrade grok-bot`.
2. **Make sure only one instance owns the config dir.** Another SSH session or script
   that restarts the app or recreates `~/.config/Grok Bot` creates a new machine
   registration each time. Kill it and keep only the systemd unit.
3. **Run it as a user service** (with `loginctl enable-linger $USER`):
   ```ini
   [Unit]
   After=network-online.target mihomo.service
   Wants=network-online.target mihomo.service
   [Service]
   ExecStartPre=/bin/sh -c 'rm -f "$HOME/.config/Grok Bot"/Singleton*'
   ExecStart=/usr/bin/xvfb-run -a -s "-screen 0 1600x1000x24" %h/.local/bin/grok-bot-x11 \
     --password-store=basic --remote-debugging-port=9223
   Restart=always
   RestartSec=5
   [Install]
   WantedBy=default.target
   ```
   `grok-bot-x11` is `exec /usr/local/bin/grok-bot --disable-gpu "$@"`.
   On Ubuntu 22.04 the wrapper also has to add a newer libstdc++ to `LD_LIBRARY_PATH`
   (tree-sitter needs GLIBCXX_3.4.31).
4. **Proxy the whole process tree, not only Chromium.** `--proxy-server` only covers
   renderer and Chromium networking. The Node main process connected directly to
   `api2.cursor.sh` and the gateway. Env vars (`HTTPS_PROXY`, `NODE_USE_ENV_PROXY=1`)
   only partly helped. The reliable fix is a system-wide TUN proxy (see
   `mihomo-tun-user-systemd`).
5. **When restarting, kill leftovers first.** If the old Electron process still holds
   9223, the new one logs `bind() failed: Address already in use` and has no DevTools:
   `systemctl --user stop grok-bot; pkill -u $USER -f "^/opt/Grok B[o]t/grok-bot"`.
   Use the `[o]` bracket trick so `pkill -f` doesn't match and kill its own shell.

## Verification
- In the renderer over CDP on port 9223, `document.body.innerText` shows the agent
  list instead of "Setting up…".
- The machine list shows the host `connected: true`. Running `hostname && whoami`
  on that machineId returns the server's host and user.

## Debugging helpers (CDP)
A tiny Node script that gets `http://127.0.0.1:9223/json`, opens the page's
`webSocketDebuggerUrl` and sends `Runtime.evaluate` (with `awaitPromise: true`)
is enough to:
- read `document.body.innerText`;
- call preload APIs such as `desktop.cursorAccount.getStatus()`,
  `desktop.cursorAccount.getMachines()` (the `isCurrent` flag shows which registration
  is this box), `desktop.update.getStatus()` and `desktop.forceGatewayReconnect()`;
- force a bundle re-evaluation with
  `import(document.scripts[0].src + "?x=" + Date.now())`, which shows whether the UI
  can render at all.
Never print tokens from `sand-secrets.json` or `getStatus()`.

## Notes
- The preload API surface changes between versions. Don't depend on it in scripts,
  only use it for diagnosis.
- Stale duplicate registrations stay offline in the machine list. Remove them in the app.
- See also: `mihomo-tun-user-systemd`.

## References
- Release feed and Linux packages: https://docs.x.ai/grok-bot/deployment
