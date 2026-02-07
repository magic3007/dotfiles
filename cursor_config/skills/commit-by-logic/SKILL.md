---
name: commit-by-logic
description: 分析当前的git diff，然后git commit，可以分多次，每次commit都是一个逻辑上独立的功能。Use when the user wants to commit changes by logical grouping, or asks to split commits, or mentions commit-by-logic.
---

# 智能分次提交工具

这个工具帮助你分析当前的git diff，然后将更改分成多个逻辑上独立的提交。每个提交都遵循`<type>(<scope>): <description>`格式。

## 使用方式

当用户要求按逻辑分组提交代码时触发。用户可以可选地指定提交类型前缀（如`feat`、`fix`等）。如果不提供，系统会为每个分组自动选择合适的类型。

## 工作流程

1. **分析当前更改**：检查git status和git diff
2. **识别逻辑分组**：根据文件类型、功能模块或更改类型将更改分组
3. **生成提交消息**：为每个分组生成符合`<type>(<scope>): <description>`格式的提交消息
4. **交互式确认**：向用户展示每个分组并确认是否提交
5. **分次提交**：为每个逻辑分组创建独立的提交

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
简短描述，使用现在时祈使句，首字母不大写，不加句号。

## 具体步骤

### 第一步：检查当前状态

运行以下命令查看当前 git 状态：

```bash
git status --porcelain
```

### 第二步：分析更改

```bash
git diff --name-status
```

如果有未暂存的新文件，也检查：

```bash
git diff --cached --name-status
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

在开始提交前，请向用户展示：
1. 你识别出的分组数量
2. 每个分组包含的文件
3. 每个分组的建议提交消息
4. 询问是否需要调整分组或提交消息

等待用户的确认后再开始执行提交操作。

### 第六步：执行分次提交

对于每个确认的分组：
1. 使用 `git add [文件列表]` 添加该分组的文件
2. 使用 `git commit -m "提交消息"` 提交
3. 如果用户指定了提交类型，将其作为默认类型（用户可以覆盖）

## 排除文件

以下文件不应被提交，在分组时自动忽略：
- `CLAUDE.md`、`GEMINI.md` 等 AI 指令文件
- 二进制文件（如 `core` dump 文件）

## 注意事项

- 确保每个提交都是逻辑上完整的
- 提交消息应该清晰描述这个分组的功能
- 遵循Conventional Commits规范
- 如果有疑问，请先询问用户
- 可以分多次执行，每次处理一个逻辑分组

## 错误处理

- 如果没有更改可提交，提示用户
- 如果git状态异常（有未合并的冲突等），先提示解决
- 如果用户取消操作，清理临时状态
