---
name: mihomo-tun-user-systemd
description: |
  Enable mihomo (Clash.Meta) TUN mode while running it as a systemd *user* service
  on a box where sudo works but `sudo systemctl` / `iptables` are forbidden. Use when:
  (1) mihomo logs "Start TUN listening error: start NetworkUpdateMonitor: address
  family not supported by protocol", (2) "configure tun interface: operation not
  permitted" even after `setcap cap_net_admin+ep`, (3) "Failed at step CAPABILITIES
  ... status=218/CAPABILITIES" after adding AmbientCapabilities to a user unit,
  (4) an app (Electron/Node main process, gRPC, websockets) ignores HTTP proxy
  settings and you need a transparent system-wide proxy without breaking SSH or the intranet.
author: Claude Code
version: 1.0.0
date: 2026-11-11
---

# mihomo TUN mode under a systemd user service

## Problem
A user-level mihomo service with the usual hardening can't create a TUN device.
File capabilities are silently dropped, and the obvious fixes either fail or need
`sudo systemctl`, which isn't allowed here.

## Context / Trigger Conditions
- The unit has hardening such as `NoNewPrivileges=true`, `RestrictAddressFamilies=AF_INET AF_INET6 AF_UNIX`,
  `RestrictSUIDSGID`, `PrivateTmp`, `ProtectSystem` or `ProtectHome`.
- `grep CapEff /proc/$(pgrep -x mihomo)/status` shows `0000000000000000` and
  `NoNewPrivs: 1` even though `getcap` shows caps on the binary.
- `sudo -l` excludes `/usr/bin/systemctl`, so a system unit can't be installed.

## Solution
1. Give the binary file capabilities. `setcap` itself is allowed under sudo:
   ```sh
   sudo setcap cap_net_admin,cap_net_bind_service,cap_net_raw+ep ~/.local/bin/mihomo
   ```
   Don't use `AmbientCapabilities=` in a user unit. The user manager has no caps
   to grant, so the unit fails with status 218/CAPABILITIES.
2. Add a drop-in that turns off every option that implies no-new-privileges or a user
   namespace. In a user manager, any seccomp-based option such as
   `RestrictAddressFamilies` silently forces NNP, and NNP disables file caps:
   ```ini
   # ~/.config/systemd/user/mihomo.service.d/tun.conf
   [Service]
   NoNewPrivileges=false
   PrivateTmp=false
   ProtectSystem=false
   ProtectHome=false
   RestrictSUIDSGID=false
   RestrictAddressFamilies=
   ```
   The empty `RestrictAddressFamilies=` resets the list. You need AF_NETLINK
   for mihomo's route monitor.
3. Write the TUN config, and keep the intranet and SSH out of the tunnel. If the config
   is regenerated from a subscription, put this in the normalizer, not in the file:
   ```yaml
   interface-name: eth0
   tun:
     enable: true
     stack: mixed
     device: mihomo0
     auto-route: true
     auto-detect-interface: false
     strict-route: false
     dns-hijack: []          # keep system DNS; sniffer recovers domains
     route-exclude-address: [10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16,
                             100.64.0.0/10, 127.0.0.0/8, 169.254.0.0/16]
   ```
   Keep `sniffer.enable: true` so domain rules still work without DNS hijack.
4. Restart and check: `systemctl --user daemon-reload && systemctl --user restart mihomo`.

## Verification
```sh
grep -E "CapEff|NoNewPrivs" /proc/$(pgrep -u $USER -x mihomo)/status  # CapEff 3400, NNP 0
ip -br addr | grep mihomo0                                               # 198.18.0.1/30
curl -s -o /dev/null -w "%{http_code}\n" https://www.google.com          # 302 without -x
curl -s -o /dev/null -w "%{http_code}\n" https://www.baidu.com           # 200 (DIRECT)
```
The SSH session from the intranet must stay alive throughout.

## Notes
- **Pitfall**: if the user unit is a symlink into a dotfiles repo,
  `systemctl --user disable --now mihomo` deletes the symlink
  (`Removed ~/.config/systemd/user/mihomo.service`). Re-create it with
  `ln -s ~/dotfiles/.../mihomo.service ~/.config/systemd/user/` and run `enable --now`.
  Don't test a system-unit migration on a live proxy.
- `setcap` is lost when the binary is replaced, for example by a mihomo upgrade. Re-run step 1.
- When a subscription expires, it returns a single dummy node (for example "您的服务已到期").
  If the normalizer pins a node name, update it to a node in the new subscription.
- See also: `grok-bot-linux-headless`.

## References
- systemd.exec(5): NoNewPrivileges is implied by RestrictAddressFamilies and other
  seccomp options in user managers. https://www.freedesktop.org/software/systemd/man/latest/systemd.exec.html
- mihomo TUN docs: https://wiki.metacubex.one/en/config/inbound/tun/
