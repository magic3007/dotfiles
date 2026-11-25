# Global npm packages version check: warn when a node version switch (nvm) left
# globally installed packages missing. The manifest ~/.npm-global-packages is the
# expected list and is rebuilt when deleted.
NPM_MANIFEST="$HOME/.npm-global-packages"
NPM_VERCHECK="$HOME/.npm-global-version-check"

_npm_check_global_packages() {
  command -v npm >/dev/null 2>&1 || return 0

  local current_node_ver
  current_node_ver="$(node --version 2>/dev/null)"

  # Skip if already checked for this node version
  if [ -f "$NPM_VERCHECK" ]; then
    read -r saved_ver < "$NPM_VERCHECK"
    [ "$saved_ver" = "$current_node_ver" ] && return 0
  fi
  echo "$current_node_ver" > "$NPM_VERCHECK"

  # Auto-create manifest from current installs if missing
  if [ ! -f "$NPM_MANIFEST" ]; then
    npm list -g --depth=0 --parseable 2>/dev/null \
      | grep node_modules \
      | sed 's|.*/node_modules/||' \
      | sort > "$NPM_MANIFEST"
    return 0
  fi

  # Compare manifest against current global installs
  local missing=""
  while IFS= read -r pkg; do
    [ -z "$pkg" ] && continue
    if ! npm list -g --depth=0 "$pkg" >/dev/null 2>&1; then
      missing="${missing} ${pkg}"
    fi
  done < "$NPM_MANIFEST"

  if [ -n "$missing" ]; then
    echo ""
    echo "⚠️  Node.js 版本已切换 ($(node --version))，以下全局 npm 包缺失:${missing}"
    echo "   自动修复: npm install -g${missing}"
    echo "   更新清单: rm ~/.npm-global-packages  # 下次启动自动重建"
    echo ""
  fi
}

_npm_check_global_packages
