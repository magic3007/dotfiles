#!/usr/bin/env bash
set -uo pipefail

ports="${PROXY_PORTS:-7890 7891 7892 7893 7897}"
no_proxy="127.0.0.1,localhost,::1,feishu.cn,.feishu.cn,open.feishu.cn,accounts.feishu.cn,msg-frontier.feishu.cn,larksuite.com,weixin.qq.com,.weixin.qq.com,weixin.com,.weixin.com"
names=(HTTP_PROXY HTTPS_PROXY ALL_PROXY http_proxy https_proxy all_proxy NO_PROXY no_proxy)

live_port() {
    local p
    for p in $ports; do
        if (exec 3<>"/dev/tcp/127.0.0.1/$p") 2>/dev/null; then
            printf '%s\n' "$p"
            return 0
        fi
    done
    return 1
}

assignments() {
    local port="$1"
    printf '%s\n' \
        "HTTP_PROXY=http://127.0.0.1:$port" \
        "HTTPS_PROXY=http://127.0.0.1:$port" \
        "ALL_PROXY=socks5://127.0.0.1:$port" \
        "http_proxy=http://127.0.0.1:$port" \
        "https_proxy=http://127.0.0.1:$port" \
        "all_proxy=socks5://127.0.0.1:$port" \
        "NO_PROXY=$no_proxy" \
        "no_proxy=$no_proxy"
}

case "${1:-}" in
    "")
        port="$(live_port)" || exit 1
        assignments "$port"
        ;;
    --systemd)
        for _ in $(seq "${PROXY_WAIT_SECONDS:-30}"); do
            port="$(live_port)" && break
            sleep 1
        done
        if [ -n "${port:-}" ]; then
            mapfile -t vars < <(assignments "$port")
            systemctl --user set-environment "${vars[@]}"
            echo "systemd user environment -> 127.0.0.1:$port"
        else
            systemctl --user unset-environment "${names[@]}"
            echo "no local proxy port in [$ports]; proxy variables removed" >&2
        fi
        ;;
    *)
        echo "usage: proxy-env [--systemd]" >&2
        exit 2
        ;;
esac
