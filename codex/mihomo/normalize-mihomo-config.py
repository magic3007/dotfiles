#!/usr/bin/env python3
"""把机场订阅规整为只给 Codex 用的本机 mihomo 配置。

针对本机实际情况做了以下适配（与通用教程的差异）：
  * 登录/运行主机无 IPv6 出网，故强制 ipv6=false，并把纯 IPv6 节点移出可用组。
  * 订阅自带 mixed-port 7890 / allow-lan true / bind-address '*' / external-controller，
    全部收敛为仅 127.0.0.1 的单一混合端口，不开控制面端口。
  * 订阅的「自动选择」是 url-test，会按 apple.com 测速在节点间频繁抖动；
    改为 fallback，并以 Codex 后端健康检查（未登录返回 401）作为判据。
"""
from pathlib import Path
import sys

import yaml


# Codex 后端健康检查：未登录访问返回 401，说明节点能连通 Codex 后端。
CODEX_HEALTH_CHECK_URL = "https://chatgpt.com/backend-api/codex/models"
CODEX_HEALTH_CHECK_EXPECTED_STATUS = 401
CODEX_HEALTH_CHECK_INTERVAL = 15
CODEX_HEALTH_CHECK_TIMEOUT_MS = 5000
CODEX_HEALTH_CHECK_MAX_FAILED_TIMES = 1
MIXED_PORT = 17891  # 与 proxy.env 中的端口保持一致

# 本机无 IPv6 出网，带 v6 的节点必然不可用。
V6_HOST_MARKERS = ("v6",)

# 订阅中的组名（按实际订阅修改）。
PINNED_GROUP = "\U0001f680 节点选择"
AUTO_GROUP = "♻️ 自动选择"
# 主选择组默认选中的固定节点。
PINNED_NODE = "🇺🇸美国-T(通用)"

# 进入自动故障转移组的协议及优先顺序（排在前面的优先）。
STABLE_PROXY_TYPES = ("vless", "hysteria2")

HEALTH_CHECK_KEYS = (
    "url",
    "interval",
    "lazy",
    "timeout",
    "max-failed-times",
    "expected-status",
    "tolerance",
)


def is_ipv6_literal(value: object) -> bool:
    return isinstance(value, str) and ":" in value and "." not in value


def host_looks_v6(name: object, server: object) -> bool:
    if is_ipv6_literal(server):
        return True
    if not isinstance(server, str):
        return True
    return any(marker in server.lower() for marker in V6_HOST_MARKERS)


def normalize_proxy_groups(data: dict, dropped: list) -> None:
    groups = data.get("proxy-groups")
    if not isinstance(groups, list):
        raise SystemExit("subscription has no proxy groups")

    proxies = data.get("proxies")
    if not isinstance(proxies, list):
        raise SystemExit("subscription has no proxies")

    pinned = [p for p in proxies if isinstance(p, dict) and p.get("name") == PINNED_NODE]
    if not pinned:
        available = "\n".join("  - %s" % p.get("name") for p in proxies[:50])
        raise SystemExit(
            "PINNED_NODE %r not found in subscription. Available:\n%s" % (PINNED_NODE, available)
        )

    stable_candidates = []
    for proxy_type in STABLE_PROXY_TYPES:
        for proxy in proxies:
            if not isinstance(proxy, dict):
                continue
            name = proxy.get("name")
            if not isinstance(name, str):
                continue
            if proxy.get("type") != proxy_type:
                continue
            if host_looks_v6(name, proxy.get("server")):
                dropped.append("     %s (%s -> %s)" % (name, proxy_type, proxy.get("server")))
                continue
            stable_candidates.append(name)

    if not stable_candidates:
        raise SystemExit("no usable candidate of the stable proxy types on this host")

    names = {g.get("name") for g in groups if isinstance(g, dict)}
    for required in (PINNED_GROUP, AUTO_GROUP):
        if required not in names:
            raise SystemExit("subscription must contain a %r group" % required)

    for group in groups:
        if not isinstance(group, dict):
            continue

        members = group.get("proxies")
        if isinstance(members, list):
            group["proxies"] = [
                m for m in members
                if not any(
                    isinstance(p, dict)
                    and p.get("name") == m
                    and host_looks_v6(p.get("name"), p.get("server"))
                    for p in proxies
                )
            ]

        if group.get("name") == AUTO_GROUP:
            # 固定节点优先，自动组只在手动切换时作为故障转移使用。
            group["type"] = "fallback"
            group["proxies"] = stable_candidates
            group["url"] = CODEX_HEALTH_CHECK_URL
            group["interval"] = CODEX_HEALTH_CHECK_INTERVAL
            group["lazy"] = False
            group["timeout"] = CODEX_HEALTH_CHECK_TIMEOUT_MS
            group["max-failed-times"] = CODEX_HEALTH_CHECK_MAX_FAILED_TIMES
            group["expected-status"] = CODEX_HEALTH_CHECK_EXPECTED_STATUS
            group.pop("tolerance", None)
            continue

        if group.get("name") == PINNED_GROUP:
            # 固定节点放第一位，mihomo 默认选中第一个成员。
            group["type"] = "select"
            # 去重后前置固定节点与自动组，避免同一成员出现两次。
            others = []
            for m in (group.get("proxies") or []):
                if m in (PINNED_NODE, AUTO_GROUP) or m in others:
                    continue
                others.append(m)
            group["proxies"] = [PINNED_NODE, AUTO_GROUP] + others
            for key in HEALTH_CHECK_KEYS:
                group.pop(key, None)
            continue

        if group.get("type") in {"url-test", "fallback"}:
            group["type"] = "select"
            for key in HEALTH_CHECK_KEYS:
                group.pop(key, None)


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("usage: normalize-mihomo-config.py INPUT OUTPUT")

    data = yaml.safe_load(Path(sys.argv[1]).read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise SystemExit("subscription did not return a Mihomo mapping")

    for key in (
        "port",
        "socks-port",
        "redir-port",
        "tproxy-port",
        "external-controller",
        "external-controller-tls",
        "external-controller-unix",
        "external-ui",
        "external-ui-url",
        "secret",
    ):
        data.pop(key, None)

    data["mixed-port"] = MIXED_PORT
    data["allow-lan"] = False
    data["bind-address"] = "127.0.0.1"
    data["mode"] = "rule"
    data["log-level"] = "warning"
    data["ipv6"] = False
    data["unified-delay"] = True
    data["tcp-concurrent"] = True
    data["disable-keep-alive"] = False
    data["keep-alive-idle"] = 15
    data["keep-alive-interval"] = 15

    dropped: list = []
    normalize_proxy_groups(data, dropped)

    dns = data.get("dns")
    if isinstance(dns, dict):
        dns.pop("listen", None)
        dns["ipv6"] = False

    tun = data.get("tun")
    if isinstance(tun, dict):
        tun["enable"] = False

    Path(sys.argv[2]).write_text(
        yaml.safe_dump(data, allow_unicode=True, sort_keys=False),
        encoding="utf-8",
    )

    print("normalized -> %s" % sys.argv[2])
    print("pinned node: %s" % PINNED_NODE)
    print("fallback candidates: %d" % len(
        next(g for g in data["proxy-groups"] if g.get("name") == AUTO_GROUP)["proxies"]
    ))
    if dropped:
        print("dropped IPv6-only nodes (host has no IPv6 egress):")
        for line in dropped:
            print(line)


if __name__ == "__main__":
    main()
