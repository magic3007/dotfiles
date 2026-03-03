---
name: commit-by-logic
description: 分析git更改并分次提交，支持从git diff或git staged分析，每次提交都是逻辑上独立的功能
disable-model-invocation: true
allowed-tools: Bash(git *), Read, Grep, Glob, AskUserQuestion
argument-hint: [--source diff|staged] [提交类型，如feat、fix等]
---

# 智能分次提交工具

这个工具帮助你分析git更改并将更改分成多个逻辑上独立的提交。支持从git diff（未暂存更改）或git staged（已暂存更改）分析。每个提交都遵循`<type>(<scope>): <description>`格式。

## 使用方式

运行 `/commit-by-logic` 或 `/commit-by-logic [--source diff|staged] [type]`

参数说明：
- `--source diff|staged`: 可选，指定分析来源。`diff`表示分析未暂存更改（默认），`staged`表示分析已暂存更改
- `type`: 可选的提交类型前缀，如`feat`、`fix`等。如果不提供，系统会为每个分组自动选择合适的类型。

示例：
- `/commit-by-logic` - 分析未暂存更改并分次提交
- `/commit-by-logic --source staged` - 分析已暂存更改并分次提交
- `/commit-by-logic --source diff feat` - 分析未暂存更改，使用feat作为默认类型
- `/commit-by-logic fix` - 分析未暂存更改，使用fix作为默认类型

## 工作流程

1. **解析参数**：确定分析来源（diff或staged）和默认提交类型
2. **检查当前状态**：根据分析来源检查git status和相应的diff
3. **识别逻辑分组**：根据文件类型、功能模块或更改类型将更改分组
4. **生成提交消息**：为每个分组生成符合`<type>(<scope>): <description>`格式的提交消息
5. **交互式确认**：向你展示每个分组并确认是否提交
6. **分次提交**：为每个逻辑分组创建独立的提交

## 提交消息格式规范

遵循Conventional Commits规范：`<type>(<scope>): <description>`

### 常用类型（type）：
- `feat`: 新功能
- `fix`: 修复bug
- `docs`: 文档更新
- `style`: 代码格式调整（不影响功能）
- `refactor`: 代码重构
- `test`: 测试相关
- `chore`: 构建过程或辅助工具的变动
- `perf`: 性能优化
- `ci`: CI配置变更

### 范围（scope）：
可选的模块或组件名称，如`auth`、`api`、`ui`、`config`等。

### 描述（description）：
简短描述，**使用英文**，使用现在时祈使句，首字母不大写，不加句号。

## 具体步骤

### 第一步：解析参数
解析用户提供的参数：
- 如果包含 `--source staged`，设置 `SOURCE="staged"`
- 如果包含 `--source diff`，设置 `SOURCE="diff"`
- 默认 `SOURCE="diff"`
- 提取可能的提交类型参数

### 第二步：检查当前状态
根据分析来源检查状态：

```bash
# 检查git状态
git status --porcelain

# 根据SOURCE参数选择分析来源
if [ "$SOURCE" = "staged" ]; then
  git diff --cached --name-status
else
  git diff --name-status
fi
```

### 第三步：分析更改
根据分析来源获取详细的更改信息：

```bash
if [ "$SOURCE" = "staged" ]; then
  # 分析已暂存更改
  git diff --cached --name-only
  git diff --cached --stat
else
  # 分析未暂存更改（默认）
  git diff --name-only
  git diff --stat
fi
```

### 第三步：根据以下规则分组更改

请按照以下逻辑分析更改并分组：

1. **按文件类型分组**：
   - 配置文件更改（.json, .yaml, .yml, .toml, .env, .config.js等）→ 类型可能是`chore`或`config`
   - 源代码更改（.js, .ts, .py, .java, .go等）→ 根据功能判断类型
   - 文档更改（.md, .txt, .rst, README等）→ 类型`docs`
   - 测试文件更改（*test*, *spec*, *.test.*）→ 类型`test`
   - 样式文件更改（.css, .scss, .less, .sass）→ 类型`style`

2. **按功能模块分组**：
   - 如果文件路径包含特定目录（如 `src/auth/`, `src/api/`, `ui/`, `components/`等）
   - 相关的功能更改应该放在一起
   - 根据目录结构推断scope

3. **按更改类型分组**：
   - 新增文件 → 可能对应`feat`
   - 修改文件 → 根据修改内容判断类型
   - 删除文件 → 可能对应`refactor`或`fix`

### 第四步：为每个分组生成提交消息

对于每个逻辑分组：
1. 分析分组中的文件，推断合适的`type`和`scope`
2. 根据更改内容生成简洁的`description`
3. 生成完整的提交消息：`type(scope): description`

示例：
- `feat(auth): 添加用户登录功能`
- `fix(api): 修复用户查询接口空指针异常`
- `docs(readme): 更新安装说明`
- `chore(deps): 升级react到v18`

### 第五步：交互式确认

在开始提交前，请向我展示：
1. 分析来源：`$SOURCE` (diff或staged)
2. 你识别出的分组数量
3. 每个分组包含的文件
4. 每个分组的建议提交消息
5. 询问是否需要调整分组或提交消息

等待我的确认后再开始执行提交操作。

### 第六步：执行分次提交

对于每个确认的分组：
1. 如果 `$SOURCE = "diff"`（分析未暂存更改），需要先暂存文件：
   ```bash
   git add [文件列表]
   ```
2. 如果 `$SOURCE = "staged"`（分析已暂存更改），文件已暂存，直接提交
3. 使用 `git commit -m "提交消息"` 提交
4. 如果提供了类型参数，将其作为默认类型（用户可以覆盖）

## 排除文件

以下文件不应被提交，在分组时自动忽略：
- `CLAUDE.md`、`GEMINI.md` 等 AI 指令文件
- 二进制文件（如 `core` dump 文件）

## 注意事项

### 分析来源说明
- **`--source diff`（默认）**：分析未暂存的更改（`git diff`）。适用于正在编辑但尚未暂存的文件。
- **`--source staged`**：分析已暂存的更改（`git diff --cached`）。适用于已经使用 `git add` 暂存的文件。

### 提交流程差异
- 使用 `--source diff` 时，工具会自动暂存每个分组的文件然后提交
- 使用 `--source staged` 时，文件已经暂存，工具直接提交

### 通用注意事项
- 确保每个提交都是逻辑上完整的
- 提交消息应该清晰描述这个分组的功能
- 遵循Conventional Commits规范
- 如果有疑问，请先询问我
- 可以分多次执行，每次处理一个逻辑分组

## 错误处理

### 无更改可提交
- 如果 `--source diff` 且没有未暂存更改，提示："No unstaged changes to commit. Use `--source staged` if you have staged changes."
- 如果 `--source staged` 且没有已暂存更改，提示："No staged changes to commit. Use `--source diff` if you have unstaged changes."

### 混合状态处理
- 如果既有未暂存更改又有已暂存更改，提示用户选择分析来源
- 建议先处理已暂存更改（`--source staged`），然后再处理未暂存更改（`--source diff`）

### 其他错误
- 如果git状态异常（有未合并的冲突等），先提示解决
- 如果用户取消操作，清理临时状态
- 如果参数解析失败，显示正确的使用方式