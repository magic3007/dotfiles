#!/usr/bin/env bash
set -u

[ "$(uname)" = Linux ] || exit 0
command -v systemctl >/dev/null 2>&1 || exit 0
[ -L "$HOME/.config/systemd/user/proxy-env.service" ] || exit 0

systemctl --user daemon-reload
if systemctl --user cat clash-for-linux.service >/dev/null 2>&1; then
    systemctl --user enable proxy-env.service
fi
systemctl --user start --no-block proxy-env.service
