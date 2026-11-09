---
name: git-rebuild-history
description: "把一个混着探索提交的分支重建成只含有用提交的干净历史，让探索从未进入历史。 Whenever a feature branch must be merged but its history carries exploration — dead-end commits, added-then-deleted files, tried-and-reverted APIs, 'wip'/'try'/'explore' commits, or a big uncommitted worktree sitting on top of them — use this skill. Covers both cases: the final state still uncommitted in the worktree, and the final state already at the branch tip. Also use it when the user says 不想在远程仓库保留这些探索, 只想每个 commit 都是有用的, 清理分支历史, 重建提交历史, 合并前整理 commit, squash 掉探索, clean up branch history before merge, or asks how to drop exploration commits before opening a merge request."
---

# 重建分支历史，让探索从不进入历史

分支要合并，但历史里混着探索。目标不是"把探索藏起来"，而是让探索**从未存在过**。

## 为什么是重建，不是 rebase

`rebase -i` 只能 drop / squash / reword **已存在的 commit**。探索的形状恰恰是它处理不了的：

- **加了又删的文件**（`approach_a.py` 提交过，后来删了）：drop 掉"加"那条，"删"那条就变成删除一个不存在的文件；两条都 drop 文件才干净，但你要手工找出所有这种配对。
- **同一路径的反复改写**（`thing.py` 提交成 v1、v2、final）：三条 commit 动同一个文件，drop 任何一条都会让后面的 patch 冲突或落空。实测里 `git cherry-pick` 这种"删掉旧内容再加新内容"的 commit 会直接变成**空 commit**。
- **squash 也不能免俗**：三条合成一条，diff 链里仍留着 v1 的痕迹，只是被压平了。

重建换了个思路：不问"这些 commit 哪些该留"，而是问"**最终状态相对 base 改了什么**"，然后按架构分层重新切一遍。探索根本不在输入里，所以不可能出现在输出里。

代价是 commit 边界由你重新决定。原来那些边界本来就不值得沿用——它们是探索的脚印。

## 0. 先确定两个变量

全文用 `$BASE` 和 `$CHECK`，现在就定下来。

**`$BASE`：从哪开始。** 是**合并目标分支**，不是当前分支的 upstream。

```bash
BASE_REF=""
for ref in origin/master master origin/main main; do
  git rev-parse --verify -q "$ref" >/dev/null 2>&1 && { BASE_REF=$ref; break; }
done
[ -n "$BASE_REF" ] || { echo "找不到合并目标分支，手动指定 BASE_REF" >&2; exit 1; }
BASE=$(git merge-base HEAD "$BASE_REF")
echo "BASE_REF=$BASE_REF  BASE=$BASE  $(git log -1 --format=%s "$BASE")"
```

两个坑：

- **不要用 `@{upstream}`。** 它是当前分支自己的远端（`origin/feat/x`），`git merge-base HEAD origin/feat/x` 得到 `HEAD`——整个重建从错误起点开始，而且不报错。
- **不要写 `A || B | sed || echo 默认值` 这种链。** 管道让 `sed` 即使输入为空也退出 0，`|| echo` 永远不触发，`BASE_REF` 静默变成空字符串。用上面的 for 循环逐个 `rev-parse --verify`。

`$BASE` 是"这个分支 fork 出去的那个点"，不是"master 现在在哪"。用后者会把别人合进 master 的改动也算进你的 diff。

stacked branch（这个分支基于另一个特性分支）要手动把 `BASE_REF` 设成那个特性分支。

**`$CHECK`：项目自己的检查命令。** 从仓库的 Makefile / package.json / CI 配置里读出来，写成一条能跑的字符串。后面每个 commit 都要用它，所以现在就要确定。

```bash
ls Makefile makefile GNUmakefile package.json pyproject.toml tox.ini noxfile.py 2>/dev/null
ls .github/workflows/ .gitlab-ci.yml 2>/dev/null | head
```

典型形态：

```bash
CHECK='make check'                       # 有 Makefile
CHECK='PYTHONPATH=$PWD/src pytest -q'    # Python，注意 $PWD 会在 worktree 里展开
CHECK='npm test --silent'                # Node
CHECK='cargo test --quiet'               # Rust
CHECK='go test ./...'                    # Go
```

**一个都没找到**（没有构建配置、没有 CI）就自己定一条最小的：跑测试目录、跑类型检查、或至少 `import` 一遍包。这条检查的作用是抓"某个中间 commit 根本跑不起来"，不需要覆盖完整 CI。

`$CHECK` 跑不起来也没关系——第 2 节有分叉处理，重建的正确性靠第 6 节的四项证明，不靠这个检查。

## 1. 先盘点，再动手

```bash
git branch --show-current
git rev-list --left-right --count "$BASE_REF"...HEAD       # ahead / behind
git log --format='%h %an %ad %s' --date=short "$BASE"..HEAD
git status --porcelain | cut -c1-2 | sort | uniq -c         # M / D / ?? 三桶
git diff --shortstat; git diff --cached --shortstat
git ls-files --others --exclude-standard | while read -r f; do
  printf '%8s %s\n' "$(du -h "$f" | cut -f1)" "$f"; done    # 大文件先看见
```

**未跟踪文件列表必须逐行读。** 里面混着构建产物的可能性很高，而第 3 节的 `git add -A` 会把它们一起冻进 final。这是本 skill 最容易造成实际损害的一步，见第 3 节。

**index 里的暂存内容要看清楚**（常见是工作区已经 `git rm` 过几个文件）：

```bash
git diff --cached --name-only
```

它们会在第 3 节被 `git add -A` 收进 `$FINAL_TREE`。这本身没问题——final 要的就是删除后的状态——但你要知道 final 里有什么。

**远程情况（没有 remote 就跳过整段）：**

```bash
git remote | grep -q . && {
  git rev-list --left-right --count "origin/$(git branch --show-current)"...HEAD 2>/dev/null
  git ls-remote origin 'refs/merge-requests/*/head' | grep -f <(git log --format=%H "$BASE"..HEAD)
}
```

`ls-remote` 那条非空 = 已经有 MR 钉住了那些 commit，见第 7 节。

## 2. 先在最终状态上跑一遍 $CHECK

最终状态是重建的真相来源。它是红的就**停下**——你是在把一个坏的状态提交进去，不是在修它。

```bash
eval "$CHECK"
```

红了要分清两种情况，别一律当成分支坏了：

```bash
# 在 base 上跑同一个检查
d=$(mktemp -d); git worktree add -q --detach "$d" "$BASE" && {
  ( cd "$d" && eval "$CHECK" ) && echo "BASE OK" || echo "BASE ALSO RED"
  git worktree remove --force "$d"
}
```

- **base 绿、final 红** → 分支真的坏了。停下报告，不要一边重建一边修。
- **base 也红** → 检查命令本身在这个环境跑不起来（缺依赖、配置文件是占位内容、工具版本不兼容）。**这不是分支的问题**。先修检查命令：换等价调用（`pytest -c /dev/null`、显式 `--rootdir`、指定配置文件），或直接告诉用户"检查跑不起来"，然后**继续重建**——重建的正确性靠第 6 节的四项证明，不靠这个检查。

这次绿的结果是后面每个 commit 的对照基线。最终状态还在工作区（情况 A）就直接跑；已经是 tip（情况 B）就先检出 tip 或用 worktree。

## 3. 冻结最终状态

重建需要两样东西：**base**（从哪开始）和 **final**（要到哪）。final 分两种情况。

**情况 A：最终状态还在工作区里**（最常见——探索了半天，最后一次改动没提交）

用**备用 index** 冻结，不在分支上留提交：

```bash
IDX=$(mktemp -u /tmp/freeze-index.XXXXXX)          # 必须在仓库外！
GIT_INDEX_FILE=$IDX git add -A
FINAL_TREE=$(GIT_INDEX_FILE=$IDX git write-tree)
rm -f "$IDX" "$IDX.lock"
echo "FINAL_TREE=$FINAL_TREE"
```

备用 index 的好处：不污染真实 index、不在探索分支上留一个 `wip: final state` 提交、重冻零成本。`git stash create` 不行——它漏掉未跟踪文件。

`mktemp` 的路径**必须在仓库外**。放在仓库里，`git add -A` 会把 index 文件本身当成未跟踪文件收进 final（实测：freeze tree 里出现 `freeze.index.lock`）。

`$FINAL_TREE` 是个 **tree 对象，不是 commit**。不要试图 `git branch <name> $FINAL_TREE`——会报 `object is a tree, not a commit`。直接把这个变量传给后面所有命令：`git diff`、`git ls-tree`、`git apply` 全都接受裸 tree。

因为是 shell 变量，它在**当前 shell 会话**里有效。中间关了终端就得重冻一次（代价很低，就是重跑这三行）。

**情况 B：最终状态就是分支 tip**（工作区干净，但历史里有探索）

```bash
FINAL_TREE=$(git rev-parse HEAD^{tree})
echo "FINAL_TREE=$FINAL_TREE"
```

两种情况后面完全一样。`$FINAL_TREE` 是所有内容的唯一来源，**它不能丢**。

### 冻结后必须逐行审一遍 final 的内容

`git add -A` 会把未跟踪文件全收进来，包括**构建产物**。这是实测踩过的坑：一次 freeze 把 `src/pkg/__pycache__/*.pyc`、`tests/__pycache__/*.pyc` 一起冻了进去。

为什么危险：第 5 节会把 `$FINAL_TREE` 的内容复制进每个切片，第 6 节的 tree hash 检查**两边都带垃圾所以照样通过**。错的 final 比丢的 final 更糟，因为没有任何后续检查能发现它。

**注意顺序**：第 2 节跑 `$CHECK` 本身就会生成 `__pycache__` 之类的产物。所以要么先冻结再跑检查，要么跑完检查清理干净再冻结。冻结**之后**跑的检查不影响 final。

```bash
# 常见构建产物的快速扫描。命中就返回非 0，不要只打印
if git ls-tree -r --name-only "$FINAL_TREE" \
   | grep -nE '__pycache__|\.pyc$|\.pyo$|node_modules|\.egg-info|(^|/)(build|dist|target|out)/|\.o$|\.so$|\.class$|\.log$|\.tmp$'; then
  echo ">>> STOP: 构建产物进了 final，清理后重冻" >&2
  false     # 让调用方能 || exit 1
fi

# 无论如何都要肉眼过一遍全量列表
git ls-tree -r --name-only "$FINAL_TREE"
```

命中了就删掉产物（或补 `.gitignore`）后重冻——用备用 index 的话重冻就是重新跑一遍那三行，零代价。

写成 `grep … && echo STOP` 是不够的：`grep` 的退出码被 `&&` 吞掉，脚本不会真停，"STOP" 只是一行打印。

验证 freeze 正确：

```bash
git status --porcelain                        # 情况 A：freeze 不该改变工作区状态
git diff --stat "$FINAL_TREE" HEAD           # 情况 B：必须为空
```

## 4. 算出探索残渣

残渣检查必须做在 **blob 级**，不是路径级。

路径级检查（"这个路径在分支历史里有、final 里没有"）看起来合理，但**对最常见的探索形态零覆盖**：同一个文件被反复改写（`validator.py` 提交成 v1、改成 class、改成函数、最后加 `strict` 参数），路径一直存在，路径级检查返回空集，而三次 churn 全都躺在历史里。

blob 级检查问的是正确的问题：**哪些内容只存在于探索过程中？**

```bash
TOPIC=<topic>          # 探索分支名
blobs() { git log --format=%H "$BASE".."$1" | while read -r c; do
            git ls-tree -r "$c" | awk '{print $3"\t"$4}'; done | sort -u; }

blobs "$TOPIC" > /tmp/topic-blobs.txt
git ls-tree -r "$BASE" | awk '{print $3"\t"$4}' | sort -u > /tmp/base-blobs.txt

# 只在探索过程中存在过的内容（base 没有）
comm -23 /tmp/topic-blobs.txt /tmp/base-blobs.txt > /tmp/explore-blobs.txt
echo "探索中出现过的 blob: $(wc -l < /tmp/explore-blobs.txt)"
```

`/tmp/explore-blobs.txt` 里的每一条，在重建后的历史里都必须**一次都不出现**。这是本 skill 唯一的核心承诺，第 6 节验证它。

顺带看一眼哪些路径被反复改写——它们是重建时最需要小心的：

```bash
cut -f2 /tmp/explore-blobs.txt | sort | uniq -c | sort -rn | head
```

路径级的删除清单仍然有用（它告诉你哪些文件是"加了又删"），但**不能**用它当验收标准：

```bash
comm -23 \
  <(comm -23 \
      <(git log --format= --name-only --diff-filter=AM "$BASE".."$TOPIC" | grep -v '^$' | sort -u) \
      <(git ls-tree -r --name-only "$BASE" | sort -u)) \
  <(git ls-tree -r --name-only "$FINAL_TREE" | sort -u) | tee /tmp/residue-paths.txt
```

三个条件缺一不可：少了"base 里没有"→ base 本来就有的文件会被误判（删除它是这个分支的真实工作）；少了"final 里没有"→ 分支新增并保留的文件会被误判；用 `[ -e "$p" ]` 测工作区不行——探索中 `git rm` 掉的文件既不在工作区也不在 HEAD，但仍在分支历史里。

## 5. 逐片重建

### 先把工作区腾空

情况 A 下工作区是脏的，`git checkout -B` 会直接拒绝：

```
error: Your local changes to the following files would be overwritten by checkout
```

`$FINAL_TREE` 已经把内容存下来了，工作区不再需要。 stash 起来当安全网：

```bash
[ -n "$FINAL_TREE" ] && git cat-file -e "$FINAL_TREE" 2>/dev/null \
  || { echo "FINAL_TREE 无效，先做第 3 节" >&2; exit 1; }
git stash push -u -q -m "rebuild: worktree, content already in FINAL_TREE"
git status --porcelain          # 必须为空
```

`-u` 不能省，否则未跟踪文件留在原地，`checkout` 照样拒绝。全部验证通过、第 10 节收尾时再 `git stash drop`。

情况 B（工作区本来就干净）跳过这一步。

### 再确认你站在对的分支上

下面的 `reset --hard` + `clean -fd` **在错误的分支上执行会毁掉最终状态**：

```bash
git checkout -q -B <topic>-clean "$BASE"
[ "$(git rev-parse --abbrev-ref HEAD)" = "<topic>-clean" ] || { echo "分支不对，停" >&2; exit 1; }
git reset -q --hard "$BASE" && git clean -qfd     # 重试时必须先回到干净 base
```

`$FINAL_TREE` 有效 + 工作区已腾空 + 当前在 `<topic>-clean` 上，三个条件都满足才动手。

### 核心原语

```bash
slice() {                                   # slice "<message>" <pathspec>...
  local msg=$1; shift
  local patch; patch=$(mktemp)
  git diff --binary "$BASE" "$FINAL_TREE" -- "$@" > "$patch"
  if [ ! -s "$patch" ]; then
    echo "slice '$msg': 这些路径没有改动: $*" >&2; rm -f "$patch"; return 1
  fi
  if ! git apply --index "$patch"; then
    echo "slice '$msg': apply 失败，历史停在这里" >&2; rm -f "$patch"; return 1
  fi
  rm -f "$patch"
  git commit -qm "$msg" || { echo "slice '$msg': commit 失败" >&2; return 1; }
}

# 每片都要 || exit 1：失败后继续跑会得到半成品历史，而且不报错
slice "build: pin the toolchain"        pyproject.toml uv.lock          || exit 1
slice "feat(core): the new backend"     src/core/                       || exit 1
slice "feat(app): drive the backend"    src/app/                        || exit 1
slice "test: cover the backend"         tests/                          || exit 1
slice "docs: two backends now"          docs/                           || exit 1
```

`|| exit 1` 不能省。少了它，`git apply` 失败后 `rm` 不执行（patch 文件泄漏）、`git commit` 产生空提交、循环继续跑下一片——最后得到一个半成品历史且没有任何报错。

**交互式 shell 里把 `exit 1` 换成 `return 1` 或 `false`。** `exit` 会关掉用户的终端。本 skill 的片段是粘进交互 shell 跑的；写成脚本文件时才用 `exit`。

### 为什么是 `diff | apply`，不是 `checkout <ref> -- <paths>`

`git checkout <final> -- .` **不会删除** base 里有、`<final>` 里没有的文件。实测：

```
$ git checkout -B clean $BASE && git checkout final -- .
$ git status --porcelain
A  feature.py
A  new.py
$ test -e gone.txt && echo survived
survived          # <-- base 里的文件被留下了，重建结果和 final 不一致
```

`git diff --binary $BASE <final> -- <paths> | git apply --index` 正确处理增、改、**删**：

```
$ git diff --binary $BASE final -- feature.py new.py gone.txt | git apply --index
$ git status --porcelain
A  feature.py
D  gone.txt
A  new.py
```

`--binary` 不能省，否则二进制文件会被当文本损坏。`--index` 让改动同时进工作区和暂存区，commit 不用再 `git add`。

### 切片怎么分

按仓库自己的分层自下而上（依赖在前）：

- 被两层共用的东西，放进第一个需要它的切片。
- 测试文件跟着它覆盖的代码同一个 commit。
- 一个切片里出现"加了又删"是切错了：这段改动横跨两个概念，合并或重新排序。
- **不属于任何层的文件**（配置、状态文件、脚本、CI 配置）跟着它服务的那个特性走；实在独立就单独一个 `chore:` 切片。它已经在 `$FINAL_TREE` 里，所以**默认提交**，在报告里点出来让用户复核——不要为这个卡住重建。
- 切片数按 review 可读性定，不按文件数。改动大到单个 commit 读不动就多切几片；团队风格是一个 MR 一个 commit 时，把选择权交回给用户并说明理由。

## 6. 证明重建结果正确

四件事，缺一不可。

**一、tip 和 final 逐字节一致：**

```bash
git diff --stat "$FINAL_TREE" HEAD                 # 必须为空（tree vs commit 可以直接比）
echo "final: $FINAL_TREE"
echo "clean: $(git rev-parse HEAD^{tree})"          # 两个 tree hash 必须相同
```

tree hash 相同 = 逐字节一致，比读 diff 更硬。

**二、每个改动的路径都被某个切片覆盖：**

tree hash 相同**不能**替代这一条。切片漏掉一个路径时，`git diff` 双向比较里它可能碰巧抵消，看起来仍然一致。实测踩过：`.gitignore` 的删除不在任何切片里，tree hash 检查没抓到，是这个覆盖检查抓到的。

```bash
git diff --name-only "$BASE" "$FINAL_TREE" | sort > /tmp/must.txt
git log --format= --name-only "$BASE"..HEAD | grep -v '^$' | sort -u > /tmp/did.txt
echo "=== 漏掉的路径（应为空）==="
comm -23 /tmp/must.txt /tmp/did.txt
```

非空就回去补切片。常见漏网之鱼：`.gitignore`、`uv.lock` / `package-lock.json`、CI 配置、顶层配置文件——它们不属于任何架构层，最容易在按层切分时被跳过。

**三、探索内容一次都没出现（blob 级）：**

这是本 skill 的核心承诺，也是唯一能证明"探索从未进入历史"的检查。

```bash
blobs() { git log --format=%H "$BASE".."$1" | while read -r c; do
            git ls-tree -r "$c" | awk '{print $3"\t"$4}'; done | sort -u; }
blobs HEAD > /tmp/clean-blobs.txt

# 探索独有的内容 = 不在 base、也不在 final
git ls-tree -r "$FINAL_TREE" | awk '{print $3"\t"$4}' | sort -u > /tmp/final-blobs.txt
comm -23 /tmp/explore-blobs.txt /tmp/final-blobs.txt > /tmp/explore-only.txt

echo "=== 泄漏的探索内容（应为空）==="
comm -12 /tmp/explore-only.txt /tmp/clean-blobs.txt | tee /tmp/leaked.txt
echo "leaked=$(wc -l < /tmp/leaked.txt)  explore-only=$(wc -l < /tmp/explore-only.txt)"
```

**用 `comm -12`（交集），不是 `comm -23`（差集）。** 断言要的是"两者都有"的行——那才是泄漏。`comm -23` 输出的是"只在探索里"的内容，恰好是**没**泄漏的那些；用它当断言会把干净结果报成 5 处泄漏。

`leaked=0` 才算过。非空就说明某个探索中间版本被切进了重建历史——回去看是哪个切片用了旧内容。

两个数字都要打印：`explore-only=0` 说明第 4 节的采集有问题（探索分支名写错、`$BASE` 不对），不是"真的没探索"。

路径级的删除清单只作参考，不当验收标准（它对同路径 churn 零覆盖）：

```bash
while read -r p; do
  [ -n "$p" ] || continue
  hits=$(git log --oneline "$BASE"..HEAD -- "$p")
  [ -z "$hits" ] && [ ! -e "$p" ] || { echo "LEAK: $p"; echo "$hits"; }
done < /tmp/residue-paths.txt
```

只查 `/tmp/residue.txt`。base 里就有、这个分支删掉的文件**应该**在历史里出现，把它算进残渣会得到假警报。

**四、每个 commit 都独立站得住**——下一节。

## 7. 证明每个 commit 都独立站得住

工作区永远只有最终状态，中间 commit 是看不见的。逐个 checkout 出来单独检查。

**先在 base 上跑一遍。** base 是红的就停下报告，别把它当成某个切片的问题：

```bash
d=$(mktemp -d)
git worktree add -q --detach "$d" "$BASE" || { echo "worktree add 失败"; exit 1; }
( cd "$d" && PATH="$d/.venv/bin:$PATH" eval "$CHECK" ) && echo "BASE OK" || echo "BASE IS RED — 停下报告"
git worktree remove --force "$d"
```

然后是每个重建 commit。把 `<pkg>` 换成仓库的**包根**模块名（不是叶子模块）：

```bash
PKG=<pkg>
for sha in $(git log --format=%h --reverse "$BASE"..HEAD); do
  d=$(mktemp -d)
  git worktree add -q --detach "$d" "$sha" || { echo "SKIP $sha: worktree add 失败"; continue; }

  # editable install 的陷阱：断言导入路径落在 worktree 里，不是主 checkout
  out=$( cd "$d" && PYTHONPATH="$d/src" python3 -c "import $PKG; print($PKG.__file__)" 2>&1 )
  case "$out" in
    "$d"/*) : ;;
    *) echo "  WARN $sha: import 解析到 $out（editable install 泄漏，检查跑的可能不是这个 commit）" ;;
  esac

  if ( cd "$d" && PATH="$d/.venv/bin:$PATH" eval "$CHECK" >/dev/null 2>&1 ); then
    echo "  OK   $sha $(git log -1 --format=%s "$sha")"
  else
    echo "  FAIL $sha $(git log -1 --format=%s "$sha")"
    ( cd "$d" && PATH="$d/.venv/bin:$PATH" eval "$CHECK" 2>&1 | tail -20 )   # 重跑拿输出
  fi
  git worktree remove --force "$d"
done
git worktree prune
git worktree list          # 确认没有残留
```

三个陷阱：

**editable install 会让检查跑错代码。** `pip install -e` 之后，不设 `PYTHONPATH=<worktree>/src` 时 `import` 解析到**主 checkout**，中间 commit 坏了也照样绿。上面的 `case` 断言 `__file__` 落在 worktree 里。

**断言包根，不要断言叶子模块。** 早期切片里后面的模块还不存在，断言 `pkg.thing` 会得到 `ModuleNotFoundError`——那是正确行为不是故障。包根（`pkg`）在整个系列里都存在。

**venv 的 `bin` 要进 PATH。** 调用 console script 的用例会假失败（`FileNotFoundError`）。仓库没有 venv 就去掉 `PATH=` 前缀。

**循环里不要 `set -e`。** `git worktree add` 或检查失败时 `set -e` 会当场退出，留下**未清理的 worktree**，下次跑同一个 sha 就撞上"already exists"。用 `|| { ...; continue; }` 显式处理，跑完 `git worktree prune && git worktree list` 确认干净。

不想写 worktree registry 的话用 `git archive`，不留痕迹也没有残留问题：

```bash
for sha in $(git log --format=%h --reverse "$BASE"..HEAD); do
  d=$(mktemp -d)
  git archive "$sha" | tar -x -C "$d"
  ( cd "$d" && eval "$CHECK" >/dev/null 2>&1 ) \
    && echo "  OK   $sha" || echo "  FAIL $sha"
  rm -rf "$d"
done
```

## 8. 远程卫生：GitLab 会永久钉住 MR 的 commit

没有 remote 就跳过整节。

`git ls-remote origin 'refs/merge-requests/*/head'` 每个 MR 一条 ref。**这些 ref 让该 MR 的每个 commit 永远可 fetch，即使分支已删。** 后果：

- 绝不从探索分支开 MR。先建干净分支，推它，从它开 MR。
- `git push origin --delete <branch>` 只对从未被 MR 引用过的 commit 有效。
- 已经开过 MR 的分支，唯一彻底的办法是让那些 commit 不进入最终历史（本 skill 做的事），残留在 MR ref 里的只能等仓库 GC。

还要看 CI 是不是每次推分支都跑。`.gitlab-ci.yml` 里 `workflow: rules:` 有 `if: $CI_COMMIT_BRANCH` 就意味着每个中间态都烧一条 pipeline——这是"只推干净分支"的另一个理由。

## 9. 报告

一张表，`sha | subject | files | check`，base 那行放最前。**没跑过的 commit 不能声称是绿的**——`check` 列只能从第 7 节的实际输出里填，不能推断。

先把第 7 节的结果存下来，再生成表：

```bash
for sha in $(git log --format=%h --reverse "$BASE"..HEAD); do
  d=$(mktemp -d)
  git worktree add -q --detach "$d" "$sha" || continue
  ( cd "$d" && PATH="$d/.venv/bin:$PATH" eval "$CHECK" >/dev/null 2>&1 ) \
    && r=PASS || r=FAIL
  n=$(git show --stat --format= "$sha" | tail -1 | grep -oE '[0-9]+ files? changed' || echo '?')
  printf '%s | %s | %s | %s\n' "$sha" "$(git log -1 --format=%s "$sha")" "$n" "$r"
  git worktree remove --force "$d"
done | tee /tmp/report.txt
git worktree prune
```

base 那行手动加在最前面（用第 7 节 base 检查的结果）。

`sha | subject | files` 这三列可以纯 git 生成，但 `check` 列必须真的跑过：

```bash
git log --format='%h %s' --shortstat "$BASE"..HEAD    # 只给前三列
```

推送和删远程分支都要用户明确确认。

## 10. 收尾

重建验证通过后清理临时状态。**默认保留探索分支**——用户可能想对照、或 clean 分支出问题时需要退路：

```bash
git stash drop                       # 第 5 节 stash 的工作区；内容已在 clean 里
rm -f /tmp/*-blobs.txt /tmp/residue-paths.txt /tmp/must.txt /tmp/did.txt /tmp/leaked.txt
```

探索分支的删除**问用户**，不要自己决定。默认答案是不删：

```bash
git branch -D <topic>                # 只有用户明确要求时才执行
```

`$FINAL_TREE` 只是个变量，没有 ref 要清理。

**stash 不是 final 的完整副本**——`git stash push -u` 把未跟踪文件存在第三个父提交里，`stash@{0}^{tree}` 只含 tracked 改动。想从 stash 恢复完整工作区要用 `git stash pop`，不要去读 `stash@{0}` 的 tree。

真正的安全网是 `$FINAL_TREE` 本身：它是个 tree 对象，只要没被 gc 就一直有效（默认 `gc.pruneExpire` 两周）。重建是分钟级的事，两周绰绰有余。

要跨会话保留（重建中途要离开），给 tree 打个 tag——annotated tag 可以指向任意对象：

```bash
git tag -a <topic>-final-tree "$FINAL_TREE" -m "final state before rebuild"
```

确认 clean 分支的 tree hash 对上之后再 `git stash drop` 和删 tag。

## 往后

- 探索提交用 `git commit --fixup <sha>`，收尾 `git rebase -i --autosquash` 自动折叠。
- 探索只推 `wip/*`，干净了再推 `feat/*`。
- 删远程分支 `git push origin --delete <branch>`，本地 `git branch -D`。
- 探索期间别开 MR。这条是唯一无法事后补救的。
