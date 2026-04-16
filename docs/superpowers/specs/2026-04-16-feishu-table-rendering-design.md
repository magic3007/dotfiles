# 飞书通知 Markdown 表格渲染 + 完整消息发送

**日期**: 2026-04-16
**状态**: 设计已批准

## 背景

Claude Code 通过 Stop/StopFailure/TaskCompleted hook 调用 `wechat-reminder` 向飞书发送任务完成通知。当 Claude 回复中包含 Markdown 表格时，飞书的 `lark_md` 格式不支持标准 Markdown 表格语法（`| col | col |`），导致表格显示为纯文本。同时，当前 hook 脚本将 `last_assistant_message` 截断为 500 字，用户希望发送完整内容。

## 目标

1. 将 Markdown 表格自动转换为飞书原生 `table` 卡片元素，正确渲染
2. 移除 500 字截断限制，发送完整的 `last_assistant_message`
3. 在通知中显示 `session_id`

## 改动范围

### 文件 1: `claude/hooks/claude-end-reminder.sh`

**改动点**：

1. 从 hook stdin JSON 中提取 `session_id` 字段
2. 在消息描述中增加 `**Session**: ${SESSION_ID}` 行（位于"用户"和"完成时间"之间）
3. 移除 500 字截断逻辑，直接使用完整的 `$LAST_REPLY`

### 文件 2: `wechat-reminder/wechat-reminder_main.py`

**改动点**：

#### 新增函数: `parse_content_segments(text)`

将消息文本解析为分段列表：

```python
[
  {"type": "text", "content": "文本段..."},
  {"type": "table", "headers": ["col1", "col2"], "rows": [["val1", "val2"]]},
  {"type": "text", "content": "后续文本..."}
]
```

**表格识别规则**：
- 第 1 行为表头：`| col | col |`
- 第 2 行为分隔符：`|---|---|`（允许 `:` 对齐标记）
- 第 3 行起为数据行
- 遇到非 `|` 开头的行或空行时表格结束
- 截断的表格（只有表头无数据行）降级为纯文本

#### 新增函数: `build_feishu_table(segment)`

将解析出的表格段转换为飞书原生 table 元素：

```json
{
    "tag": "table",
    "page_size": 10,
    "row_height": "low",
    "header_style": {
        "text_align": "left",
        "background_style": "grey",
        "bold": true
    },
    "columns": [
        {"name": "col_0", "display_name": "表头名", "data_type": "lark_md", "width": "auto"}
    ],
    "rows": [
        {"col_0": "单元格内容"}
    ]
}
```

- 列数据类型统一使用 `lark_md`，保留单元格中的粗体、代码等格式
- `page_size: 10` 启用飞书自动分页

#### 修改函数: `send_to_feishu()`

将 `desp` 参数通过 `parse_content_segments()` 解析后，组装为多元素卡片：

```python
elements = []
for segment in segments:
    if segment["type"] == "text" and segment["content"].strip():
        elements.append({"tag": "div", "text": {"tag": "lark_md", "content": segment["content"]}})
    elif segment["type"] == "table":
        elements.append(build_feishu_table(segment))
```

## 边界处理

| 场景 | 处理方式 |
|------|---------|
| 单卡片 > 5 个表格 | 第 6 个起降级为 lark_md 纯文本 |
| 截断的表格（无数据行） | 降级为纯文本 |
| 空的 desp | 不添加任何 element（现有行为） |
| 非常长的消息 | 完整发送，飞书卡片有约 28KB 限制 |

## 飞书卡片显示效果

```
[hostname] Claude Code 任务完成
━━━━━━━━━━━━━━━━━━━━━━━━━━
项目: my-repo
目录: /path/to/project
分支: main
最近提交: feat: add new feature
Session: abc123
用户: yanzhou@hostname
完成时间: 2026-04-16 14:30:00
───────────────────
Claude 回复:
生成了以下图表：

┌──────┬──────────────────────┬──────────────┐
│ 图表 │ 文件                  │ 内容         │
├──────┼──────────────────────┼──────────────┤
│ Fig1 │ fig1_metrics.png     │ 三线趋势图   │
│ Fig2 │ fig2_radar.png       │ 六维雷达图   │
└──────┴──────────────────────┴──────────────┘

所有图表已保存到 output/ 目录。
```

## 不涉及的改动

- WeChat PushDeer 通道不受影响（仍发送纯文本）
- 命令行接口不变（`--title`、`--desp`、`--color` 参数不变）
- hook 事件绑定配置不变
