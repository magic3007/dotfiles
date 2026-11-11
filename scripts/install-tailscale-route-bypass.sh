#!/usr/bin/env bash
# =============================================================================
# 安装 / 卸载 tailscale-route-bypass 的 root LaunchDaemon
# =============================================================================
# 为什么要单独一个安装器：
#   LaunchDaemon 的文件必须归 root 所有，否则任何本地进程都能改脚本来借 root
#   权限（等价于把 sudoers 写成 777）。所以仓库里只放模板，安装时才 sudo 落地。
#
# 幂等：重复执行等于升级——脚本和 plist 每次都覆盖成仓库版本，
#       但 /etc/tailscale-route-bypass.conf 只在缺失时创建（机器专属配置不能被覆盖）。
#
# 用法：
#   sudo scripts/install-tailscale-route-bypass.sh
#   sudo TAILSCALE_ROUTE_HOSTS="1.2.3.4 5.6.7.8" scripts/install-tailscale-route-bypass.sh
#   sudo scripts/install-tailscale-route-bypass.sh --uninstall
# =============================================================================
set -u

LABEL="com.minimax.tailscale-route-bypass"
DAEMON_DST="/usr/local/sbin/tailscale-route-bypass.sh"
CONF_DST="/etc/tailscale-route-bypass.conf"
PLIST_DST="/Library/LaunchDaemons/${LABEL}.plist"
LOG_PATH="/var/log/tailscale-route-bypass.log"

SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
DAEMON_SRC="${SRC_DIR}/tailscale-route-bypass.sh"

die() { printf 'error: %s\n' "$*" >&2; exit 1; }
info() { printf '[route-bypass] %s\n' "$*"; }

[ "$(id -u)" = 0 ] || die "run as root: sudo $0"

if [ "${1-}" = "--uninstall" ]; then
    launchctl bootout "system/${LABEL}" 2>/dev/null || true
    rm -f "$PLIST_DST" "$DAEMON_DST"
    info "uninstalled (config $CONF_DST kept; delete it manually if unwanted)"
    exit 0
fi

[ -f "$DAEMON_SRC" ] || die "missing $DAEMON_SRC"

# --- 1. 安装执行脚本（root:wheel 0755，禁止他人写） -------------------------
install -d -m 0755 -o root -g wheel /usr/local/sbin
install -m 0755 -o root -g wheel "$DAEMON_SRC" "$DAEMON_DST"

# --- 2. 机器专属配置：只在缺失时创建 ---------------------------------------
if [ ! -f "$CONF_DST" ]; then
    {
        printf '# tailscale-route-bypass: 每行一个 IPv4，主机路由会改走物理网关。\n'
        printf '# 这里放的通常是 DERP 服务器和 peer 的公网 IP（查看：tailscale netcheck / status --json）。\n'
        if [ -n "${TAILSCALE_ROUTE_HOSTS:-}" ]; then
            for h in $TAILSCALE_ROUTE_HOSTS; do printf '%s\n' "$h"; done
        fi
    } >"$CONF_DST"
    chmod 0644 "$CONF_DST"
    chown root:wheel "$CONF_DST"
    info "created $CONF_DST"
else
    info "kept existing $CONF_DST"
fi

# --- 3. 写 plist ------------------------------------------------------------
# StartInterval 60：VPN 重连/换网会冲掉 /32 路由，脚本幂等所以重跑很便宜。
# ProcessType Background：不参与前台 QoS 调度，省电。
cat >"$PLIST_DST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${LABEL}</string>
    <key>ProgramArguments</key>
    <array>
        <string>${DAEMON_DST}</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>StartInterval</key>
    <integer>60</integer>
    <key>ProcessType</key>
    <string>Background</string>
    <key>StandardOutPath</key>
    <string>${LOG_PATH}</string>
    <key>StandardErrorPath</key>
    <string>${LOG_PATH}</string>
</dict>
</plist>
PLIST
chmod 0644 "$PLIST_DST"
chown root:wheel "$PLIST_DST"

# --- 4. 重新加载并立刻跑一次 ------------------------------------------------
# bootout 对未加载的服务会报错，属正常，用 || true 吞掉。
launchctl bootout "system/${LABEL}" 2>/dev/null || true
launchctl bootstrap system "$PLIST_DST" || die "bootstrap failed"
launchctl kickstart -k "system/${LABEL}" || die "kickstart failed"

sleep 1
info "installed; current routes for configured hosts:"
"$DAEMON_DST" --verbose | sed 's/^/  /'
