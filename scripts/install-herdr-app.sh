#!/usr/bin/env bash
#
# 安装 Herdr 桌面 app（macOS）与其运行时 herdr-core。
#
# 背景：仓库里原本只装了 `herdr` TUI（herdr.dev/install.sh，见 install.conf.yaml），
# 那是终端多路复用器；桌面 app（Herdr.app）是另一个程序，驱动的是 herdr-core
# （`hc`）。两者配置各在一处：~/.config/herdr/ 与 ~/.config/herdr-app/。
#
# 设计取舍：
# - 不直接复用上游 https://releases.herdr.dev/app/install.sh。上游在 macOS 上
#   永远装到 ~/Applications，而本机已有 /Applications/Herdr.app（从 dmg 拖入），
#   直接跑上游脚本会多出一份 bundle，Launchpad 与 `herdr-app` 指向都会分叉。
#   这里改成：先认已存在的 bundle，找不到才下载到 ~/Applications。
# - 不覆盖已存在的 bundle。上游文档明确「app 自己会更新自己」，所以这里只在
#   缺失时安装，避免覆盖掉正在运行的、带签名的 bundle。
# - 签名必须原样保留。Developer ID 签名的 bundle 一旦被改（比如塞 LSEnvironment）
#   签名就失效，macOS 权限也随之失效；只有上游明确的无签名/adhoc 开发版才按
#   上游的做法补 LSEnvironment 并 adhoc 重签。
#
# 环境变量：
#   HERDR_APP_DIR          指定 bundle 目录（默认在 /Applications 与 ~/Applications
#                          里找已有的，都找不到才装到 ~/Applications）
#   HERDR_APP_BIN_DIR      指定垫片目录（默认 ~/.local/bin）
#   HERDR_RELEASES_URL     发布源（默认 https://releases.herdr.dev）

set -euo pipefail

RELEASES="${HERDR_RELEASES_URL:-https://releases.herdr.dev}"
BIN_DIR="${HERDR_APP_BIN_DIR:-$HOME/.local/bin}"

say() { printf '%s\n' "$*"; }
fail() { say "herdr-app: $*" >&2; exit 1; }

[ "$(uname -s)" = "Darwin" ] || { say "herdr-app: only macOS is supported here, skipped"; exit 0; }
command -v curl >/dev/null 2>&1 || fail "needs curl"
command -v tar >/dev/null 2>&1 || fail "needs tar"
command -v python3 >/dev/null 2>&1 || fail "needs python3 (parses the release manifest)"

# 目标架构：Rosetta 下 uname -m 会报 x86_64，用 sysctl 判断真实芯片。
case "$(uname -m)" in
  arm64 | aarch64) target="macos-aarch64" ;;
  x86_64 | amd64)
    if [ "$(sysctl -n hw.optional.arm64 2>/dev/null || true)" = "1" ]; then
      target="macos-aarch64"
    else
      fail "Intel Macs have no upstream build; build from source"
    fi
    ;;
  *) fail "no build for $(uname -m)" ;;
esac

sha256() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | cut -d' ' -f1
  else shasum -a 256 "$1" | cut -d' ' -f1; fi
}

# ---------------------------------------------------------------------------
# 1. 定位已有的 bundle
# ---------------------------------------------------------------------------
# 优先用已经装好的那份（含用户从 dmg 拖进 /Applications 的），只有在都找不到
# 时才下载。HERDR_APP_DIR 指定后是排他的：只看这一个目录，找不到就装进去，
# 这样测试时可以用它把安装目标隔离到临时目录里。
if [ -n "${HERDR_APP_DIR:-}" ]; then
  candidates=("$HERDR_APP_DIR")
else
  candidates=("/Applications" "$HOME/Applications")
fi

bundle=""
for dir in "${candidates[@]}"; do
  if [ -d "$dir/Herdr.app" ]; then bundle="$dir/Herdr.app"; break; fi
done

# ---------------------------------------------------------------------------
# 2. 缺 bundle 时下载并安装
# ---------------------------------------------------------------------------
if [ -z "$bundle" ]; then
  target_dir="${HERDR_APP_DIR:-$HOME/Applications}"
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' EXIT

  say "fetching Herdr app manifest..."
  curl -fsSL --connect-timeout 10 --max-time 30 "$RELEASES/app/latest.json" -o "$tmp/latest.json" \
    || fail "cannot reach $RELEASES"

  # 用 python3 解析 manifest：上游用 sed 处理扁平 JSON，但 latest.json 里有
  # targets 子对象，sed 那套写法在这里并不成立。
  url=$(python3 -c 'import json,sys
d=json.load(open(sys.argv[1]))
print(d["targets"][sys.argv[2]]["url"])' "$tmp/latest.json" "$target")
  want=$(python3 -c 'import json,sys
d=json.load(open(sys.argv[1]))
print(d["targets"][sys.argv[2]]["sha256"])' "$tmp/latest.json" "$target")
  version=$(python3 -c 'import json,sys
print(json.load(open(sys.argv[1])).get("version",""))' "$tmp/latest.json")
  [ -n "$url" ] && [ -n "$want" ] || fail "no build for $target"

  say "downloading Herdr ${version} for $target..."
  curl -fsSL --connect-timeout 10 --max-time 300 "$url" -o "$tmp/app.tar.gz" \
    || fail "download failed: $url"
  [ "$(sha256 "$tmp/app.tar.gz")" = "$want" ] || fail "the download is damaged (checksum mismatch)"
  tar -xzf "$tmp/app.tar.gz" -C "$tmp"
  [ -d "$tmp/Herdr.app" ] || fail "the archive has no Herdr.app"

  # 签名处理，对齐上游：Developer ID 签名的 bundle 原样保留并校验；只有
  # adhoc / 完全无签名的开发版才允许改 Info.plist 再 adhoc 重签。
  signature=$(/usr/bin/codesign -dvv "$tmp/Herdr.app" 2>&1 || true)
  if printf '%s\n' "$signature" | grep -q '^Authority=Developer ID Application:'; then
    /usr/bin/codesign --verify --deep --strict "$tmp/Herdr.app" || fail "invalid app signature"
  elif printf '%s\n' "$signature" | grep -qx 'Signature=adhoc' \
    || printf '%s\n' "$signature" | grep -q ': code object is not signed at all$'; then
    # 开发版没有签名，app 就找不到 ~/.local/bin 里的 hc；补 PATH 后 adhoc 签一次，
    # 与上游 install.sh 行为一致。
    /usr/libexec/PlistBuddy -c "Add :LSEnvironment:PATH string $BIN_DIR:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin" \
      "$tmp/Herdr.app/Contents/Info.plist"
    /usr/bin/codesign --force --sign - "$tmp/Herdr.app" >/dev/null 2>&1
  else
    fail "cannot determine app signature"
  fi

  mkdir -p "$target_dir"
  # 先在临时目录里备好再落位，避免 Spotlight 索引到半成品 bundle。
  rm -rf "$target_dir/Herdr.app.new"
  mv "$tmp/Herdr.app" "$target_dir/Herdr.app.new"
  rm -rf "$target_dir/Herdr.app"
  mv "$target_dir/Herdr.app.new" "$target_dir/Herdr.app"
  bundle="$target_dir/Herdr.app"
  say "installed Herdr ${version} to $bundle"
fi

# 注册到 LaunchServices，让 Launchpad / `open -a Herdr` 能找到它。
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$bundle" 2>/dev/null || true

# ---------------------------------------------------------------------------
# 3. 垫片：~/.local/bin/herdr-app -> app 内的可执行文件
# ---------------------------------------------------------------------------
mkdir -p "$BIN_DIR"
ln -sfn "$bundle/Contents/MacOS/Herdr" "$BIN_DIR/herdr-app"

# ---------------------------------------------------------------------------
# 4. herdr-core（hc）：app 的运行时
# ---------------------------------------------------------------------------
# app 启动后会自己维护 core 的版本，所以这里只在 core 缺失时用上游安装脚本补一次。
if [ ! -e "$BIN_DIR/herdr-core" ] && ! command -v herdr-core >/dev/null 2>&1; then
  say "installing herdr-core..."
  curl -fsSL --connect-timeout 10 --max-time 60 "$RELEASES/core/install.sh" \
    | HC_INSTALL_DIR="$BIN_DIR" HERDR_RELEASES_URL="$RELEASES" sh \
    || say "herdr-core didn't install; the app will offer it on first launch."
fi

# 上游 core 安装脚本只在首次安装时创建 `hc` 垫片。如果 core 是别人装好的、
# `hc` 却缺失，这里补上——app 与 agent 都按 `hc` 这个名字找 core。
if [ -e "$BIN_DIR/herdr-core" ] && [ ! -e "$BIN_DIR/hc" ] && ! command -v hc >/dev/null 2>&1; then
  ln -s herdr-core "$BIN_DIR/hc"
fi

say "Herdr app ready: $bundle"
say "Run it with: herdr-app   (or open Herdr from Launchpad)"
