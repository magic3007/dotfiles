---
name: debug-experience-system
description: |
  Establish systematic debugging experience documentation for projects using Claude Code.
  Use when: (1) Projects have recurring debugging issues, (2) Teams want to accumulate
  debugging knowledge, (3) Using Claude Code as development tool, (4) Need standardized
  debugging experience records. Provides rules, templates, and scripts for creating
  a complete debugging knowledge management system.
author: Claude Code
version: 1.0.0
date: 2026-03-04
---

# Debug Experience System Setup

## Problem
Debugging knowledge is often lost after solving problems, leading to repeated work when similar issues occur. Developers need a systematic way to capture, organize, and reuse debugging experiences across projects.

## Context / Trigger Conditions
- You're working on a project with complex debugging scenarios
- Team members frequently encounter similar issues
- Debugging solutions are not documented or shared
- Using Claude Code for development workflow
- Want to establish a knowledge base of debugging patterns
- Need to standardize how debugging experiences are recorded

## Solution
Create a complete debugging experience documentation system with Claude Code:

### 1. Rule Definition
Create `~/.claude/rules/debug-experience.md`:

```markdown
# Debug经验保存规则

## 概述
本规则指导在调试过程中如何系统性地记录和保存调试经验...

### 保存时机
- 当解决一个非显而易见的bug时
- 当发现一个重要的调试技巧或模式时
- 当遇到需要多次尝试才能解决的问题时
- 当发现文档未覆盖的特殊情况时

### 保存位置
调试经验应保存在当前项目的`debug_experience`目录下...

### 文档结构
每个调试经验文档应包含：
- 问题描述、症状、根本原因分析
- 解决方案、验证方法
- 关键学习经验、预防措施
- 相关资源、下一步行动
```

### 2. Template Creation
Create `~/.claude/templates/debug-experience-template.md`:

```markdown
# [问题标题]
**日期**: {{date}}
**状态**: [已解决/部分解决/未解决]

## 问题描述
## 症状与错误信息
## 根本原因分析
## 解决方案
## 验证方法
## 关键学习经验
## 预防措施
## 相关资源
## 下一步行动
```

### 3. Automation Script
Create `~/.claude/scripts/create-debug-experience.sh`:

```bash
#!/bin/bash
# Script to create debug experience documents
# Usage: create-debug-experience.sh "Issue description"
# Features: Date formatting, template application, file naming
```

### 4. Project Integration
For each project:
1. Create `debug_experience/` directory in project root
2. Follow the rule when debugging
3. Use template for consistency
4. Run script for automation

### 5. Usage Workflow
1. **During Debugging**: Apply debugging techniques to solve problem
2. **After Resolution**: Create debug experience document using script
3. **Review Periodically**: Team reviews accumulated experiences
4. **Refine Rules**: Update rules based on new patterns discovered

## Verification
1. Check `~/.claude/rules/debug-experience.md` exists with proper structure
2. Verify template and script are functional:
   ```bash
   cd ~/projects/some-project
   ~/.claude/scripts/create-debug-experience.sh "Test debug issue"
   ls debug_experience/
   ```
3. Confirm new debug documents follow the standardized format
4. Team members can easily find and apply past debugging solutions

## Example
**Scenario**: LATTE chapter compilation issues in PhD thesis project

**Application**:
1. Rule already defined in `~/.claude/rules/debug-experience.md`
2. Created document: `2026-03-04_LATTE_compilation_issues.md`
3. Content includes:
   - Problem: XeLaTeX assertion errors, missing image files
   - Root cause: Path inconsistencies between conference paper and thesis
   - Solution: Copy Images directory, fix relative paths
   - Key learnings: Conference paper integration patterns
   - Prevention: Checklist for future chapter integration

**Result**: Future integration of conference papers can reference this document, avoiding similar issues.

## Notes
### Integration with Existing Systems
- **Claudeception**: This system complements claudeception by providing structured documentation for debugging experiences
- **Project Rules**: Can be extended to include project-specific debugging patterns
- **Team Sharing**: Debug experience documents can be committed to version control for team access

### Best Practices
1. **Be Specific**: Include exact error messages, commands used, file paths
2. **Include Context**: Document environment, versions, dependencies
3. **Focus on Learning**: Emphasize what was learned, not just what was fixed
4. **Keep it Actionable**: Provide clear steps for similar situations
5. **Regular Review**: Periodically review and update accumulated experiences

### Common Patterns Observed
1. **Path Issues**: Common in multi-directory projects, LaTeX compilation
2. **Dependency Conflicts**: Version mismatches, conflicting libraries
3. **Configuration Problems**: Environment variables, config file locations
4. **Tool-Specific Bugs**: Workarounds for compiler/linter/tool bugs

### Scaling the System
- For large teams: Consider centralized knowledge base
- Multiple projects: Shared template repository
- Integration with CI/CD: Automated documentation generation
- Search functionality: Tag-based organization

## References
- *Based on implementation in dotfiles repository*
- *Example: PhD thesis project debug_experience directory*