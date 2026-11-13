#!/usr/bin/env bash
# 校验 omp 的破坏性 git 命令防护是否真的开着。
#
# 为什么需要这个脚本：2026-11-13 在共享 checkout 里跑了 `git checkout -- .`，
# 把另一个会话 84 行未暂存改动连同自己的编辑一起抹掉，且不可恢复——未暂存的
# 内容从没进过对象库，`git fsck` 挖不出来。防护靠 `bash.gitGuard` 与
# `bash.patterns` 两个配置项，配置项的失效是静默的（改了没人报错），所以要有
# 一条命令能随时验。
#
# 它验的是配置状态，不是运行行为。运行行为由 harness 在执行 bash 工具前拦，
# 脚本内部调 git 不在它的视野里，因此无法在这里做真实的破坏性负控。
#
# 退出码：0 = 防护在位；1 = 有防护缺失。
set -uo pipefail

fail=0

guard=$(omp config get bash.gitGuard 2>/dev/null | tr -d '[:space:]')
if [[ "$guard" == "true" ]]; then
  echo "PASS  bash.gitGuard = true"
else
  echo "FAIL  bash.gitGuard = '${guard:-<empty>}'，整树丢弃类命令（checkout -- . / reset --hard / restore --worktree . / stash / switch）不会被拦"
  fail=1
fi

patterns=$(omp config get bash.patterns 2>/dev/null)
if [[ "$patterns" == *'"git clean*"'*'"deny"'* ]]; then
  echo "PASS  bash.patterns 拦截 git clean*"
else
  echo "FAIL  bash.patterns 缺 git clean* 的 deny 规则，git clean -fdx 会静默删掉未跟踪文件"
  fail=1
fi

exit "$fail"
