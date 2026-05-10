---
name: feishu-webhook-message-formatting
description: |
  解决飞书自定义机器人webhook消息发送格式问题。使用当：
  (1) 发送post类型富文本消息返回19002参数错误，
  (2) 消息格式调试困难，
  (3) 需要快速验证webhook可用性，
  (4) 发送包含特殊字符的文本时出现JSON解析错误。
  包含正确的消息格式示例和常见错误解决方案。
author: Claude Code
version: 1.4.0
date: 2026-05-10
---

# 飞书Webhook消息格式指南

## Problem
飞书自定义机器人webhook对消息格式有严格要求，富文本（post类型）格式容易出现参数错误，且错误提示不明确（仅返回"params error, unknown content value"），导致调试困难。

## Context / Trigger Conditions
- 调用飞书webhook发送消息时返回错误码19002
- 错误信息："params error, unknown content value"
- post类型富文本消息格式调试耗时
- 需要快速验证webhook是否可用

## Solution
### 1. 优先使用简单文本格式验证
在调试初期，先使用最简单的text格式确保webhook可以正常工作：
```bash
curl -X POST -H "Content-Type: application/json" -d '{
  "msg_type": "text",
  "content": {
    "text": "测试消息\n第二行内容"
  }
}' "$FEISHU_WEBHOOK_URL"
```

### 2. 富文本（post类型）正确格式
如果需要使用富文本，遵循以下格式要求：
- content是二维数组，每个子数组代表一行内容
- 每行内容由多个富文本元素组成
- 标签包括：text（普通文本）、a（链接）、at（@用户）
- style属性用于设置粗体、斜体等样式，**值为字符串而非对象**

**⚠️ style 格式关键点：** style 的值必须是字符串（如 `"bold"`），不能是对象（如 `{"bold": true}`）。使用对象格式会导致 19002 错误！

**正确示例：**
```json
{
  "msg_type": "post",
  "content": {
    "post": {
      "zh_cn": {
        "title": "消息标题",
        "content": [
          [{"tag": "text", "text": "第一行内容"}],
          [{"tag": "text", "text": "第二行："}],
          [
            {"tag": "text", "text": "粗体文本", "style": "bold"},
            {"tag": "text", "text": " 普通文本 "}
          ],
          [
            {"tag": "a", "text": "链接文本", "href": "https://example.com"},
            {"tag": "text", "text": " 更多内容"}
          ]
        ]
      }
    }
  }
}
```

### 3. 常见格式错误
#### 错误码 19002：params error, unknown content value
- **原因**：post类型富文本消息格式不符合飞书要求
- **解决方案**：参考本指南的post格式示例，确保content是二维数组结构
- **建议**：优先使用text类型消息，避免复杂的post格式

#### 错误码 9499：Bad Request
- **原因**：JSON请求体格式错误，通常是特殊字符未正确转义或shell解析问题
- **常见场景**：
  - 文本内容中的双引号没有正确转义
  - 特殊字符（如中文引号、emoji）编码问题
  - JSON结构不完整或语法错误
  - 在bash/zsh中使用单引号包裹curl的JSON参数时，如果内容中包含单引号，会打断shell的引号匹配，导致后续内容被shell解析（如**被当成通配符展开，$开头内容被当成变量替换），出现"no matches found"等错误
- **解决方案**：
  - 确保所有双引号在JSON中正确转义为 \"
  - 在bash/zsh curl命令中，内容中的单引号需要转义为 '\''
  - 使用JSON校验工具验证请求体格式正确性
  - 避免直接在curl命令中拼接复杂内容，建议使用文件或变量传递
  - 若出现"no matches found"错误，可在执行curl前运行`setopt noglob`（zsh）或`set -o noglob`（bash）临时关闭通配符解析

#### 其他常见错误
- ❌ 错误：在text内容中使用Markdown格式（如**粗体**），飞书不识别
- ❌ 错误：content是一维数组而不是二维数组
- ❌ 错误：每行内容包含多个元素但没有放在同一个数组里
- ❌ 错误：style属性使用对象格式 `{"bold": true}`，正确应为字符串格式 `"bold"`（会导致 19002 错误）
- ❌ 错误：包含不支持的标签类型
- ❌ 错误：文本内容中的特殊字符（如单引号、双引号）没有正确转义，导致JSON解析失败
  - 示例：文本中的 "Let's think step by step" 需要转义为 "Let'\''s think step by step" 在bash curl命令中
  - 建议：使用JSON工具生成消息体，避免手动转义错误

### 4. 调试技巧
1. 先发送最简格式验证webhook连通性
2. 逐步增加富文本元素，每次增加一个元素后测试
3. 使用JSON校验工具确保格式正确
4. 参考官方文档的格式示例

## Verification
发送消息后返回：
```json
{"StatusCode":0,"StatusMessage":"success","code":0,"data":{},"msg":"success"}
```
即表示发送成功。

## Example
### 完整可用的富文本示例
```bash
curl -X POST -H "Content-Type: application/json" -d '{
  "msg_type": "post",
  "content": {
    "post": {
      "zh_cn": {
        "title": "🌟 每日推荐",
        "content": [
          [{"tag": "text", "text": "今日之星：张三", "style": "bold"}],
          [{"tag": "text", "text": "机构：某某大学"}],
          [{"tag": "text", "text": "研究方向：人工智能"}],
          [
            {"tag": "a", "text": "个人主页", "href": "https://example.com"},
            {"tag": "text", "text": " | "},
            {"tag": "a", "text": "详细信息", "href": "https://notion.so/xxx"}
          ]
        ]
      }
    }
  }
}' "$FEISHU_WEBHOOK_URL"
```

## Notes
- 飞书webhook有频率限制：每分钟最多发送60条消息
- 富文本中可以添加图片、at用户等更多元素，详见官方文档
- 如果富文本格式过于复杂，可以考虑使用interactive消息类型或卡片消息
- 环境变量`FEISHU_WEBHOOK_URL`不要硬编码，通过配置或环境变量传递

## References
- [飞书开放平台 - 自定义机器人消息格式文档](https://open.feishu.cn/documentation/client/custom-bot/develop/message-format)
- [飞书开放平台 - 错误码说明](https://open.feishu.cn/documentation/home/faq/error-code)
