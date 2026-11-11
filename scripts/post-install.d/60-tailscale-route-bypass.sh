#!/usr/bin/env bash
# =============================================================================
# post-install hook: 提醒安装 root LaunchDaemon（不自动安装）
# =============================================================================
# 为什么不在 ./install 里直接装：
#   ./install 可能无人值守跑（cron/CI），而 LaunchDaemon 必须交互式输入管理员
#   密码。这里只检测状态并打印一行命令，由人决定什么时候装。
#
# 检测逻辑：
#   1) 仓库脚本 → /usr/local/sbin 已安装且内容一致
#   2) plist 存在且被 launchd 加载
# 任一不满足就提示。
# =============================================================================
set -u

# 本文件位于 <repo>/scripts/post-install.d/，所以仓库根要往上两级。
# 类比 Python 的 pathlib: Path(__file__).parents[2]。
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
REPO_SCRIPT="${ROOT}/scripts/tailscale-route-bypass.sh"
DAEMON="/usr/local/sbin/tailscale-route-bypass.sh"
PLIST="/Library/LaunchDaemons/com.minimax.tailscale-route-bypass.plist"
LABEL="com.minimax.tailscale-route-bypass"

[ "$(uname)" = "Darwin" ] || exit 0

need_install=0
if [ ! -f "$DAEMON" ] || [ ! -f "$PLIST" ]; then
    need_install=1
elif ! cmp -s "$REPO_SCRIPT" "$DAEMON"; then
    need_install=1
fi

# launchctl print 返回非零 = 没加载（可能 plist 在但没 bootstrap）。
if [ "$need_install" = 0 ] && ! launchctl print "system/${LABEL}" >/dev/null 2>&1; then
    need_install=1
fi

if [ "$need_install" = 1 ]; then
    printf '[post-install] tailscale-route-bypass daemon 未安装或已过期，执行：\n'
    printf '    sudo %s/scripts/install-tailscale-route-bypass.sh\n' "$ROOT"
fi

exit 0
