---
name: mcp-notion-usage-guide
description: |
  MCP Notion工具使用指南，包含常见问题解决方案和最佳实践。使用当：
  (1) 访问Notion数据库view URL出现"URL type view not currently supported"错误，
  (2) 需要获取数据库schema和表结构信息，
  (3) 查询数据库中的条目内容，
  (4) 创建页面时MULTI_SELECT字段值不存在导致失败，
  (5) 需要更新数据库schema添加新选项，
  (6) 开发需要集成Notion数据的自动化工作流，
  (7) query_data_sources/query-database-view返回Business Plan要求错误，
  (8) 需要在无Business Plan的情况下枚举数据库所有条目，
  (9) 需要在SQL查询中随机选择条目（RANDOM()函数不被支持）。
author: Claude Code
version: 1.5.0
date: 2026-08-17
---

# MCP Notion工具使用指南

## Problem
MCP Notion工具的使用方式和错误处理在官方文档中没有详细说明，遇到错误时难以快速定位和解决，尤其是在访问数据库视图和查询数据时容易遇到问题。

## Context / Trigger Conditions
- 调用`mcp__notion__notion-fetch`工具访问view URL时返回错误："URL type view not currently supported for fetch tool"
- 需要获取Notion数据库的字段结构和schema信息
- 需要查询数据库中的所有条目或过滤特定条目
- 开发自动化工作流需要从Notion数据库获取数据

## Solution
### 1. 数据库访问最佳实践
当需要访问Notion数据库内容时：
1. **优先使用数据库页面URL**，而不是view URL，避免不支持的URL类型错误
2. 数据库页面URL格式通常为：`https://www.notion.so/[workspace]/[database-id]`
3. 调用`mcp__notion__notion-fetch`工具时传入数据库页面URL，即可获取完整的数据库schema信息，包括所有字段定义、选项配置等

### 2. 获取数据库条目内容
要获取数据库中的所有条目：
1. 首先通过数据库页面URL获取对应的data source URL，格式为：`collection://[data-source-id]`
2. 使用该data source URL作为`mcp__notion__notion-fetch`的参数，并搭配SQL查询语句获取内容
3. 示例查询：
   ```python
   # 获取所有条目的基本信息
   query = """
   SELECT "Name", "Institution", "Category", "Advisor", "userDefined:URL", "url" 
   FROM "collection://[data-source-id]"
   """
   ```

### 3. 常见错误解决方案
#### 错误："URL type view not currently supported for fetch tool"
- **原因**：当前MCP Notion工具不支持直接访问view类型的URL
- **解决方案**：改用数据库的主页面URL访问，所有view的数据都可以通过SQL查询在主数据源上实现
- **替代方案**：如果需要特定view的过滤条件，可以在SQL查询中添加对应的WHERE子句实现相同效果

#### 限制：SQL查询仅返回表结构，无实际数据
- **现象**：使用`SELECT`查询数据库内容时，仅返回表结构和schema信息，没有实际数据记录
- **原因**：当前版本MCP Notion工具的SQL查询功能尚未完全实现，只支持获取表结构，不支持查询实际数据
- **解决方案**：
  1. 如果需要获取数据库中的实际记录，使用`mcp__notion__notion-search`工具搜索特定条目，然后通过`mcp__notion__notion-fetch`获取单个页面的完整属性
  2. 直接访问数据库页面或通过Notion API获取完整数据集
- **注意**：技能文档中的SQL查询示例仅为预期功能，目前暂不支持使用

### 4. 数据库Schema更新（添加MULTI_SELECT新选项）
当需要在数据库中创建新页面，但目标字段的MULTI_SELECT选项中不存在需要的值时：
1. **先使用`notion-update-data-source`更新schema**，添加新选项
2. 然后才能创建包含该选项值的页面

**示例：**
```
ALTER COLUMN "Institution" SET MULTI_SELECT('existing1':blue, 'existing2':red, 'NewSchool':green)
```

**注意事项：**
- 必须列出所有现有选项和新选项，否则会丢失已有选项
- 颜色值可选：default, gray, brown, orange, yellow, green, blue, purple, pink, red
- 更新完成后，SQLite表定义中的枚举值列表会自动更新

### 5. 创建页面时的属性命名注意事项
- URL属性必须使用`userDefined:URL`（URL是保留字，不能直接写为"URL"）
- 日期字段需要拆分为`date:[field-name]:start`、`date:[field-name]:end`和`date:[field-name]:is_datetime`
- 多选字段的内容需要以JSON数组格式传递，如`["THU", "Yale"]`
- MULTI_SELECT字段的值必须是数据库schema中已定义的选项，否则创建会失败

### 6. 数据库查询限制与无Business Plan的枚举方案

#### 背景：两个查询工具均需Business Plan
MCP Notion提供了两个数据库查询工具，但**都需要Notion Business计划 + Notion AI**：
- `query_data_sources`（SQL模式）：支持SQLite查询，需Business Plan
- `query_data_sources`（view模式）：基于视图查询，需Business Plan
- `query-database-view`：查询视图数据，需Business Plan

当账户为Free/Plus计划时，这些工具会返回：
```
This tool requires a Business plan or higher with Notion AI. Upgrade your plan to query data sources
```

#### 解决方案：多关键词语义搜索枚举法
当无法使用SQL/视图查询时，可以通过`notion-search`工具配合`data_source_url`参数，使用**多种不同搜索关键词**系统性地枚举数据库中的所有条目。

**核心原理：**
- `notion-search`对`data_source_url`内的语义搜索没有计划限制
- 不同搜索关键词会匹配到数据库中不同的条目子集
- 通过足够多的关键词轮次，可以覆盖绝大部分（甚至全部）数据库条目

**操作步骤：**
1. 先用`notion-fetch`获取数据库页面，从中提取`data_source_url`（格式：`collection://...`）
2. 使用`notion-search`，传入`data_source_url`参数，用不同关键词进行多轮搜索
3. 将所有轮次的结果去重合并，得到完整的条目列表

**关键词策略（按覆盖效果排序）：**
1. **字母分组**：`a b c d e`, `h i j k l m n`, `v w x y z` 等 → 覆盖面最广
2. **领域关键词**：`AI ML PhD`, `computer science`, `deep learning` → 命中研究相关条目
3. **角色/身份词**：`student lab research`, `professor`, `postdoc` → 按类型覆盖
4. **通用标签**：`University`, `engineering`, `candidate` → 补充遗漏

**实战经验：**
- 对于~60条记录的数据库，6-7轮不同关键词搜索可覆盖95%+的条目
- 每轮`page_size=25`，实际去重后通常获得40-60条唯一记录
- 搜索结果按语义相关性排序，配合不同关键词可让不同条目轮流"置顶"

#### 两个工具的能力矩阵

| 工具 | 用途 | Free/Plus | Business+AI |
|------|------|-----------|-------------|
| `notion-fetch` | 获取页面/数据库schema | ✅ | ✅ |
| `notion-search` | 语义搜索（支持data_source限定） | ✅ | ✅ |
| `query_data_sources` (SQL) | SQL查询数据库 | ❌ | ✅ |
| `query_data_sources` (view) | 视图查询 | ❌ | ✅ |
| `query-database-view` | 视图查询 | ❌ | ✅ |

#### SQL查询返回结构无数据的说明
- `query_data_sources` 的SQL模式在Free/Plus计划完全不可用（直接报Business Plan错误），不是"返回空数据"
- 这与早期版本的`notion-fetch` SQL查询限制（仅返回schema）是**两个不同的问题**

### 7. SQL随机选择限制（RANDOM()不被支持）
当需要从数据库中随机选择条目时（例如每日随机推荐一位研究者），不能使用SQLite的`RANDOM()`函数：

```sql
SELECT * FROM "collection://..." ORDER BY RANDOM() LIMIT 1
```

会返回错误（已验证 2026-08-17）：
```
Failed to execute query: Only a single SELECT query against the provided collection views is permitted. Reason: function "random" is not allowed.
```

**注意**：错误信息中的"Only a single SELECT query"是误导性的，真正原因是`RANDOM()`函数被禁用（非标准函数均不可用）。

**解决方案**：先查询全部条目，再在客户端随机选择：
1. 用SQL查询获取所有条目的`url`、`Name`等字段（`ORDER BY "Name"`等确定性排序可用，仅`RANDOM()`被禁用）
2. 在客户端生成随机索引，如Bash `echo $((RANDOM % N + 1))`
3. 按索引取对应条目，再用`notion-fetch`获取该页面的完整内容

**已验证（2026-08-17）**：当前账户的`query_data_sources`（SQL模式）已能返回实际行数据（约100条），说明早期"仅返回表结构"的限制已不再适用（或账户已升级到Business Plan）；但`RANDOM()`等非标准SQL函数仍被禁用。

## Verification
1. 调用`mcp__notion__notion-fetch`传入数据库页面URL，能够正常返回包含schema和表结构的信息
2. 使用data source URL和SQL查询，能够获取到数据库中的条目内容
3. 不再出现"URL type view not currently supported"错误

## Example
```python
# 完整的Notion数据库访问示例
from claude_code_tools import mcp__notion__notion_fetch

# 1. 获取数据库schema信息
db_response = mcp__notion__notion_fetch(id="https://www.notion.so/workspace/073f0f11774a47edbb7f703153593880")
data_source_url = db_response["data_sources"][0]["url"]

# 2. 查询所有研究者信息
query = f"""
SELECT "Name", "Institution", "Category", "Advisor", "userDefined:URL", "url" 
FROM "{data_source_url}"
"""
data_response = mcp__notion__notion_fetch(id=data_source_url, query=query)
researchers = data_response["results"]

# 3. 处理查询结果
for researcher in researchers:
    name = researcher["Name"]
    institution = researcher["Institution"]
    print(f"Name: {name}, Institution: {institution}")
```

## Notes
- MCP Notion工具返回的JSON结构可能会随着版本更新而变化，使用时建议添加错误处理
- 对于大型数据库，建议添加LIMIT限制查询结果数量，避免响应过大
- 敏感数据库需要确保Claude Code有访问权限，否则会返回权限错误
- 定期检查MCP官方文档获取最新功能和API变化
- **重要限制（已过时）**：早期版本MCP Notion工具的SQL查询仅支持获取表结构；自2026-08-17起已验证`query_data_sources`（SQL模式）能返回实际行数据，但`RANDOM()`等非标准SQL函数仍被禁用（见第7节）
- **Business Plan限制**：`query_data_sources`和`query-database-view`工具在Free/Plus计划不可用。如需枚举数据库条目，使用第6节的多关键词语义搜索枚举法
- **搜索枚举覆盖率**：对于大型数据库（100条+），多轮语义搜索可能无法100%覆盖，需要更多的关键词轮次和更大的page_size。如确实需要完整数据，建议升级到Business计划

## References
- [Notion MCP 工具官方文档](https://github.com/modelcontextprotocol/servers/tree/main/src/notion)
- [Notion API 官方文档](https://developers.notion.com/reference/intro)
