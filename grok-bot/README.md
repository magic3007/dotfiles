# grok-bot — desktop autostart entry

Grok Bot (the xAI/Cursor desktop agent) starts at graphical login through XDG
autostart: `grok-bot/grok-bot.desktop` is linked to
`~/.config/autostart/grok-bot.desktop` from **both** `install.conf.yaml` and
`sync.conf.yaml` (a link missing from either one is caught by
`.repo-std/checks/link_parity.py`), guarded by
`if: '[ -x /home/magic/.local/bin/grok-bot ]'`.

The launcher itself is an install artifact written by the
`grok-bot-linux-install` skill, not part of this repository: it is the
user-level (no root) `~/.local/bin/grok-bot` wrapper, and it pins the three
Chromium flags this host needs (`--disable-gpu --in-process-gpu --no-sandbox`).

## Why the entry looks like this

- **Absolute `Exec`.** `.desktop` `Exec` neither runs through a shell nor expands
  `~`, and a GNOME session does not put `~/.local/bin` on `PATH`. The `if:`
  guard repeats the same absolute path, so a machine without that launcher
  (macOS included) gets no entry instead of a silently failing one.
- **The repository owns only the autostart entry.**
  `~/.local/share/applications/grok-bot.desktop` is an install artifact
  (versioned paths) written by the skill — do not add it here.
- **Not a systemd user unit.** An Electron GUI needs `DISPLAY`/`WAYLAND_DISPLAY`
  and the session D-Bus, which exist only inside the graphical session; a
  systemd user service starts before them and aborts.
- **`X-GNOME-Autostart-Delay=5`** avoids the login-time D-Bus / GPU init race.
  Other desktops ignore the key.

## After installing or upgrading Grok Bot

Re-run `./install` (or wait for the 15-minute sync) so the guard passes and the
link is created. Verify with `desktop-file-validate grok-bot/grok-bot.desktop`
and `ls -l ~/.config/autostart/grok-bot.desktop`.
