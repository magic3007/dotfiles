#!/usr/bin/env bash
# 安装 omp/plugins.txt 里声明、但本机还没装的 omp 插件。
#
# 为什么是 scripts/ 里的脚本，而不是 post-install.d/ 的钩子：
# post-install.d/ 的钩子由 install.conf 的 Phase 1 触发（纯本地、断网也必须成功），
# 而这一步要联网、还要有 bun。放在 Phase 1 会踩两个坑：
#   1. 新机器上 omp 还没装（omp 在网络阶段才装），钩子只打印 "omp not on PATH" 就跳过；
#   2. omp 已存在（比如发行版二进制装在 ~/.local/bin）但 bun 缺失时，omp 内部的
#      安装器 spawn `bun install` 失败，整次 ./install 报
#      `✘ Failed to install npm:...: Executable not found in $PATH: "bun"`。
# 所以改由 install.conf 的 Phase 2 在「装完 bun 和 omp」之后调用。
#
# 为什么只装缺失项：`omp plugin install` 对已装插件不是空操作 —— 它会重新解析包，
# 并把 feature 选择重置回 manifest 默认值（pi-fff 的 autocomplete 就靠种子文件关掉，
# 重装会把坑挖回来）。
#
# 插件本体不入库：~/.omp/plugins 是运行时状态 —— `bun install` 重写 package.json 与
# bun.lock，omp 就地重写 omp-plugins.lock.json，node_modules 还有上百个包。
# 仓库只跟踪清单。类似 Python 里只提交 requirements.txt、不提交 site-packages/。
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIST="$REPO/omp/plugins.txt"

[[ -f $LIST ]] || exit 0

if ! command -v omp >/dev/null 2>&1; then
  printf 'warn  omp not on PATH — skipping plugin install\n' >&2
  exit 0
fi

# 找一个可用的 bun。omp 是按名字 spawn 它的（相当于 C 里 execvp("bun")，只查 PATH），
# 所以「装在 ~/.bun/bin 但 PATH 里没有」等于没装。返回可执行文件路径。
resolve_bun() {
  local candidate
  if candidate="$(command -v bun 2>/dev/null)"; then
    printf '%s\n' "$candidate"
    return 0
  fi
  for candidate in \
    "${BUN_INSTALL:-$HOME/.bun}/bin/bun" \
    "$HOME/.bun/bin/bun" \
    /opt/homebrew/bin/bun \
    /usr/local/bin/bun; do
    if [[ -x $candidate ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

# 已装清单（npm + marketplace 两组）。omp 的 JSON 可能带别的字段，只取 name。
installed="$(
  omp plugin list --json 2>/dev/null | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)
for group in ("npm", "marketplace"):
    for entry in data.get(group) or []:
        if isinstance(entry, dict) and entry.get("name"):
            print(entry["name"])
' 2>/dev/null || true
)"

is_installed() {
  [[ -n $installed ]] && printf '%s\n' "$installed" | grep -qxF -- "$1"
}

# 先解析清单，再决定要不要找 bun：bun 只在真的有缺失项时才是硬需求，
# 全部已装时不该因为缺 bun 报警。
specs=()  # 传给 `omp plugin install` 的参数
names=()  # 包名 / 目录名，用来判重和打印

while IFS= read -r line || [[ -n $line ]]; do
  spec="$(printf '%s' "$line" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
  # 去掉整行注释和空白后的行内注释；ref 里的 `#`（如 github:user/repo#main）不算注释。
  spec="$(printf '%s' "$spec" | sed -E 's/^#.*$//; s/[[:space:]]+#.*$//')"
  [[ -n $spec ]] || continue

  # 文件系统路径 = 装本地 checkout（还没发版的 fork），包名取目录名。
  if [[ $spec == /* || $spec == "~/"* ]]; then
    path="${spec/#\~/$HOME}"
    if [[ ! -d $path ]]; then
      printf 'warn  %s: local plugin path does not exist\n' "$spec" >&2
      continue
    fi
    name="$(basename "$path")"
    target="$path"
  else
    # spec → 包名：去掉尾部 feature 括号、npm: 前缀和版本后缀
    # （`pi-fff@1.2.3` → pi-fff，`@scope/pkg@1.2.3` → @scope/pkg）。
    name="$(printf '%s' "$spec" | sed -E 's/\[[^]]*\]$//; s/^npm://; s/@[^@/]+$//')"

    if [[ ! $name =~ ^(@[a-z0-9][a-z0-9._-]*/)?[a-z0-9][a-z0-9._-]*$ ]]; then
      # git spec（`github:user/repo[#ref]`、`https://host/user/repo.git[#ref]`、
      # `git+ssh://…`）：omp 用 bun 把它装进 node_modules，装完的插件名来自仓库
      # package.json 的 `name`，实践中与仓库名一致，所以判重也用仓库名。
      # 类比 Python：这里只取 URL 的最后一段当 distribution 名，和 `pip install git+…`
      # 之后 `pip list` 显示的名字同源。
      name="$(printf '%s' "$spec" | sed -E 's/^git\+//; s/#.*$//; s#/$##; s#^.*[/:]##; s/\.git$//')"
    fi

    if [[ ! $name =~ ^[a-z0-9][a-z0-9._-]*$ ]]; then
      printf 'warn  %s: not an npm spec, git spec or an existing path\n' "$spec" >&2
      continue
    fi
    target="$spec"
  fi

  if is_installed "$name"; then
    printf 'ok    %s installed (left alone)\n' "$name"
    continue
  fi

  specs+=("$target")
  names+=("$name")
done < "$LIST"

(( ${#specs[@]} )) || exit 0

# bun 是外部依赖，缺失只跳过、不返回失败：repo 管不了这台机器装没装 bun，
# 把外部前置条件算成「安装失败」只会让 ./install 的收尾状态骗人。
if bun_path="$(resolve_bun)"; then
  PATH="$(dirname "$bun_path"):$PATH"
  export PATH
else
  printf 'warn  bun not found — skipping omp plugin install (%s)\n' "${names[*]}" >&2
  printf 'warn  install bun first: curl -fsSL https://bun.sh/install | bash\n' >&2
  exit 0
fi

status=0
for i in "${!specs[@]}"; do
  printf 'inst  %s <- %s\n' "${specs[$i]}" "$(basename "$LIST")"
  if ! omp plugin install "${specs[$i]}"; then
    printf 'warn  omp plugin install %s failed (%s)\n' "${names[$i]}" "offline, or this omp is too old for the package" >&2
    status=1
  fi
done

exit "$status"
