# proxy — local proxy environment without a fixed port

Clash-family clients move their `mixed-port` (clash-for-linux has gone
7892 → 7891 → 7890 after subscription rebuilds; Clash Verge on macOS defaults
to 7897). A port written into a file goes stale, and every process holding it
fails with `connection refused` while the remote host is reachable.

The only source of the port is what is listening on `127.0.0.1` now.
`proxy/proxy-env.sh` (linked to `~/.local/bin/proxy-env`) probes the candidate
ports (`PROXY_PORTS` overrides the list) and prints the eight proxy variables;
`NO_PROXY` is defined there and nowhere else.

|Consumer|How it gets the port|Platform|
|---|---|---|
|new shells|`proxy_on` in `shell/common.d/90-proxy.sh` runs at startup; no live port clears inherited values|Linux, macOS|
|one command|`pc <cmd>`|Linux, macOS|
|systemd user services|`proxy/proxy-env.service` runs `proxy-env --systemd` each time `clash-for-linux.service` starts and writes the user manager environment|Linux|

`scripts/proxy-env-unit.sh` (a provision step) enables the unit when
`clash-for-linux.service` exists. Do not add `HTTP_PROXY` and similar keys to
`~/.config/environment.d/`: that file is read only at login and pins a port.

## Limit

Environment is copied at process start. A process started before the port moved
(an omp session, `hermes-gateway`, the herdr server and its panes) keeps the
dead port until it restarts. Find them with
`grep -l "127.0.0.1:<old-port>" /proc/*/environ 2>/dev/null`.

## Verify

`proxy-env`, `systemctl --user show-environment | grep -i _proxy` and
`ss -ltn | grep 127.0.0.1:` (macOS: `lsof -nP -iTCP -sTCP:LISTEN`) must agree on
the port.
