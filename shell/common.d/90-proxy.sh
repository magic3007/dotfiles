# Local proxy: proxy-env (proxy/proxy-env.sh) probes the live port; when nothing
# listens it clears inherited stale values. pc runs one command with the proxy.
proxy_off() {
  unset HTTP_PROXY HTTPS_PROXY ALL_PROXY http_proxy https_proxy all_proxy NO_PROXY no_proxy
}
proxy_on() {
  local assignments
  if ! assignments="$("$HOME/.local/bin/proxy-env" 2>/dev/null)"; then
    proxy_off
    return 1
  fi
  set -a
  eval "$assignments"
  set +a
}
pc() {
  (
    proxy_on || { echo "pc: no local proxy port is listening" >&2; exit 1; }
    "$@"
  )
}
[ -x "$HOME/.local/bin/proxy-env" ] && proxy_on
