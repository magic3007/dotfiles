#!/usr/bin/env bash
# =============================================================================
# 让指定公网 IP 的流量绕过企业 VPN / 代理 TUN 的默认路由
# =============================================================================
# 背景（为什么需要这个脚本）：
#   飞连 CorpLink 这类企业 VPN 会把自己挂成默认路由（utun8），于是 Tailscale
#   的 DERP 中继和 peer 公网端点全部绕到境外出口，延迟从 ~30ms 涨到 250ms+。
#   给这些 IP 加 /32 主机路由（最长前缀匹配优先于 VPN 的 0.0.0.0/1、128.0.0.0/1）
#   就能把它们拉回物理网卡。
#
#   类比：C++ 里的函数重载按最具体匹配；路由表同理，/32 永远赢过 /1，
#   所以不用动 VPN 自己的配置。
#
# 为什么用 LaunchDaemon 而不是 LaunchAgent：
#   `route add` 需要 root。Agent 跑在用户会话里，拿不到权限；Daemon 以 root
#   运行，且开机即生效（不依赖有人登录）。
#
# 为什么每 60 秒重跑一次（StartInterval）：
#   VPN 重连、换网络、DHCP 续租都可能把我们的 /32 冲掉或让网关变化。
#   脚本是幂等的：状态已经正确时立即退出、不写日志，所以定时重跑几乎零成本。
#
# 依赖文件：
#   /etc/tailscale-route-bypass.conf   每行一个 IPv4，可带 # 注释
#
# 用法：
#   tailscale-route-bypass.sh           静默应用（状态不变时不输出）
#   tailscale-route-bypass.sh --verbose 打印每个目标当前走哪个接口
#   tailscale-route-bypass.sh --dry-run 只报告将做什么，不改路由
# =============================================================================
set -u

CONF="${TAILSCALE_ROUTE_CONF:-/etc/tailscale-route-bypass.conf}"

DRY_RUN=0
VERBOSE=0
case "${1-}" in
    --dry-run) DRY_RUN=1 ;;
    --verbose) VERBOSE=1 ;;
    "") ;;
    *) printf 'usage: %s [--dry-run|--verbose]\n' "${0##*/}" >&2; exit 2 ;;
esac

log() { printf '%s %s\n' "$(date '+%Y-%m-%dT%H:%M:%S')" "$*"; }
say() { [ "$VERBOSE" = 1 ] && log "$*"; return 0; }

[ -r "$CONF" ] || { say "config $CONF absent, nothing to do"; exit 0; }

# 物理网关自动探测：取第一条「默认路由且接口不是隧道」的记录。
# 隧道接口一律跳过，因为它们正是我们要绕开的对象（utun*/gif*/ipsec*）。
# awk 里 $NF 是接口名列，$2 是网关列——netstat 的固定列序不稳，所以按名字匹配。
find_gateway() {
    netstat -rn -f inet 2>/dev/null |
        awk '$1=="default" && $NF !~ /^(utun|lo|gif|ipsec|ppp)/ {print $2, $NF; exit}'
}

read -r GW IFACE <<<"$(find_gateway)"
if [ -z "${GW-}" ] || [ -z "${IFACE-}" ]; then
    say "no physical default route found (offline?), skipping"
    exit 0
fi

say "physical default: gw=$GW iface=$IFACE"

changed=0
while IFS= read -r raw || [ -n "$raw" ]; do
    # 去掉行尾注释和空白；空行跳过。
    ip="${raw%%#*}"
    ip="$(printf '%s' "$ip" | tr -d '[:space:]')"
    [ -n "$ip" ] || continue

    # 只接受 IPv4 字面量，避免配置文件被污染后把 root 权限用来做别的事。
    case "$ip" in
        *[!0-9.]*|'') log "skip invalid entry: $raw"; continue ;;
    esac
    printf '%s' "$ip" | awk -F. 'NF==4 && $1<=255 && $2<=255 && $3<=255 && $4<=255 {ok=1} END {exit ok?0:1}' || {
        log "skip invalid ip: $ip"
        continue
    }

    # 当前状态：route -n get 会打印 gateway/interface 两行。
    cur_if="$(route -n get "$ip" 2>/dev/null | awk '/interface:/{print $2; exit}')"
    cur_gw="$(route -n get "$ip" 2>/dev/null | awk '/gateway:/{print $2; exit}')"

    if [ "$cur_if" = "$IFACE" ] && [ "$cur_gw" = "$GW" ]; then
        say "$ip already direct via $IFACE ($GW)"
        continue
    fi

    say "$ip currently iface=${cur_if:-none} gw=${cur_gw:-none} -> want $IFACE/$GW"
    [ "$DRY_RUN" = 1 ] && { log "would route $ip via $GW ($IFACE)"; continue; }

    # route change 在已有路由上原地改属性；没有时 change 会失败，于是退回 add。
    # （对应 Python 的 dict.update：存在就改，不存在就新增，但这里要两步。）
    if route -n get "$ip" >/dev/null 2>&1; then
        route change -host "$ip" -gateway "$GW" >/dev/null 2>&1 && changed=1
    else
        route add -host "$ip" -gateway "$GW" >/dev/null 2>&1 && changed=1
    fi

    # 复查一次，只有真的生效才算成功。
    if [ "$(route -n get "$ip" 2>/dev/null | awk '/interface:/{print $2; exit}')" = "$IFACE" ]; then
        log "routed $ip via $GW ($IFACE)"
    else
        log "FAILED to route $ip via $GW ($IFACE)"
    fi
done <"$CONF"

[ "$changed" = 0 ] && say "no changes"
exit 0
