# Mihomo proxy for Codex

Private, loopback-only mihomo instance so a Codex desktop / VS Code remote
project works on a development host that cannot reach `chatgpt.com`.

## Why this exists

A remote project is served by a resident `codex app-server` daemon on the
development host. That daemon only reads its environment **once, at startup**.
If it starts without proxy variables, every request to
`wss://chatgpt.com/backend-api/codex/responses` fails with `ENETUNREACH` —
even though the same `codex` works in a plain terminal.

The desktop client starts that daemon through a remote command that prepends
`~/.local/bin` to `PATH`, which bypasses the wrapper in
`~/.local/codex-proxy/bin`. So the wrapper alone is not enough; the hook in
`oh-my-zsh/zshenv` is what guarantees the variables reach the daemon.

## Layout

Tracked here, symlinked into place:

| Repo file | Symlink target |
|---|---|
| `normalize-mihomo-config.py` | `~/.local/libexec/` |
| `update-mihomo-subscription` | `~/.local/libexec/` |
| `mihomo.service` | `~/.config/systemd/user/` |
| `mihomo-subscription.service` | `~/.config/systemd/user/` |
| `mihomo-subscription.timer` | `~/.config/systemd/user/` |

Not tracked, because they are credentials or machine state:

| Path | Contents |
|---|---|
| `~/.config/mihomo/subscription.curl.conf` | subscription URL (0600) |
| `~/.config/mihomo/config.yaml` | generated config (0600) |
| `~/.config/mihomo/{geoip.metadb,geosite.dat,country.mmdb}` | geo data |
| `~/.config/codex/proxy.env` | proxy variables (0600) |
| `~/.local/bin/mihomo` | binary |

## What the normalizer changes

The subscription as delivered is not usable as-is:

- drops the subscription's own ports and control plane, keeping a single
  mixed port on `127.0.0.1` with `allow-lan: false`
- pins `PINNED_NODE` as the first member of the main select group, so mihomo
  selects it by default
- rewrites the `url-test` group into a `fallback` group health-checked against
  `https://chatgpt.com/backend-api/codex/models` expecting `401` — an
  unauthenticated response that still proves TLS and HTTP reached the Codex
  backend
- sets `ipv6: false` and moves IPv6-only nodes out of the selectable groups

`PINNED_NODE` must match the subscription exactly. If the provider renames or
removes the node, the script exits non-zero and keeps the previous config
rather than silently falling back to a different exit node.

## Geo data

The subscription's rules use `GEOIP,CN` and its DNS `fallback-filter` uses
`geosite: [gfw]`, so both geo files are mandatory. mihomo's own download goes
straight to GitHub and times out on hosts that need a mirror, so
`update-mihomo-subscription` pre-fetches them through a mirror and fails loudly
only if that also fails.

## Verify

```bash
ss -ltn | grep 127.0.0.1:17891
curl -sS -x http://127.0.0.1:17891 -o /dev/null -w '%{http_code}\n' \
  https://chatgpt.com/backend-api/codex/models      # expect 401
zsh -c 'command -v codex'                            # expect the wrapper
zsh -c 'env | grep -c 17891'                         # expect 0
```

After the desktop client connects, confirm the daemon itself carries the
variables:

```bash
for p in $(pgrep -u "$USER" -f '[a]pp-server --listen'); do
  printf '%s: ' "$p"
  tr '\0' '\n' < "/proc/$p/environ" \
    | grep -E '^(https?_proxy|HTTPS?_PROXY)=' | cut -d= -f1 | tr '\n' ' '
  echo
done
```

## Notes

- The remote-start signature strings in `oh-my-zsh/zshenv` come from a
  specific Codex release. If the remote project starts failing to reach the
  network after a Codex upgrade, check that command first.
- `codex app-server daemon` subcommands need the standalone package and fail
  on the `codex-native-provider` build. The relay path
  (`app-server proxy` → `app-server --listen unix://`) works and is what the
  desktop client uses.
- A control socket is enabled for manual node switching without opening a
  port: `curl --unix-socket ~/.config/mihomo/controller.sock
  http://localhost/proxies`.
