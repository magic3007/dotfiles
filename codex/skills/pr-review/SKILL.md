---
name: pr-review
description: Review a GitHub pull request with risk-based analysis and parallel subagents. Use when asked to review the current branch PR or a specific PR number.
---

# PR Code Review (Dynamic Agent Allocation)

Intelligent code review for the current branch's Pull Request. Dynamically generates
targeted review tasks based on PR changes.

## Arguments

Treat text following the `$pr-review` mention as arguments.

- No arguments: Review PR for current branch
- PR number: Review specific PR (e.g., `$pr-review 123`)
- `--quick`: Quick mode, only run Phase 1 analysis

## Quick Start

1. Get current branch PR: `gh pr view --json number,title,state,isDraft`
1. If PR doesn't exist or is closed, stop and explain
1. Execute Phases 1-4 in order

## Workflow Overview

```
Phase 1: Deep PR Analysis [Haiku + Sonnet]
    ├─ 1.0 PR Status Check [Haiku]
    ├─ 1.1 Get PR Summary [Haiku]
    └─ 1.2-1.4 Change Type Detection [Sonnet]
    ↓
Phase 2: Dynamic Agent Planning [Sonnet]
    ↓
Phase 3: Execute Review Tasks [Parallel, Dynamic Model Selection]
    ↓
Phase 4: Confidence Scoring & Summary [Haiku]
```

## Model Configuration

The Opus, Sonnet, and Haiku labels below are review-depth tiers inherited from
the original workflow, not literal model requirements. Use the current Codex
model and assign parallel subagents the corresponding deep, standard, or quick
review scope.

| Mode                      | CRITICAL/HIGH | MEDIUM | LOW    |
| ------------------------- | ------------- | ------ | ------ |
| **Default**               | Opus          | Sonnet | Haiku  |
| **Quick** (`--quick`)     | Sonnet        | Sonnet | Sonnet |
| **Economy** (`--economy`) | Sonnet        | Haiku  | Haiku  |

______________________________________________________________________

## Phase 1: Deep PR Analysis

### 1.0 PR Status Check \[Haiku\]

Check if PR should be reviewed:

- Is it closed? → Stop
- Is it a draft? → Note but continue
- Is it bot-generated? → Skip

### 1.1 Get PR Summary \[Haiku\]

Get basic PR info: title, description, modified files, change summary.

### 1.2 Change Type Detection \[Sonnet\]

Analyze each file change, detecting change types by risk level.

Use these detection categories:

- CRITICAL level types (FrameworkA, FrameworkB, FrameworkC, FrameworkD)
- HIGH level types (distributed comm, DTensor, MoE, TP/EP/CP)
- MEDIUM level types (tensor ops, workflow, API, compile)
- LOW level types (tests, docs, config)

### 1.3 Framework-Specific Risk Identification

Based on detected types, identify corresponding risks.

Infer framework-specific risks from the changed code and repository context.

### 1.4 Output Change Analysis Report

```
CHANGE_ANALYSIS_REPORT:
- detected_types: [FRAMEWORK_PARALLEL, COMPONENT_A, FRAMEWORK_CORE, ...]
- risk_level: CRITICAL | HIGH | MEDIUM | LOW
- affected_files: [file1.py, file2.py, ...]
- identified_risks: [risk1, risk2, ...]
- related_frameworks: [frameworkA, frameworkB, frameworkC, ...]
```

______________________________________________________________________

## Phase 2: Dynamic Agent Planning \[Sonnet\]

### 2.1 Planning Principles

1. **Generate tasks by risk area**: Each high-risk area gets a dedicated task
1. **Merge related changes**: Interdependent changes can be merged
1. **Model selection**: CRITICAL/HIGH → Opus, MEDIUM → Sonnet, LOW → Haiku
1. **Minimum coverage**: Even simple changes get at least 1 basic review task

### 2.2 Task Template Selection

Based on detected change types, select appropriate review task templates.

Generate task templates from these categories:

- Framework-specific tasks (FrameworkA, FrameworkB, FrameworkC, FrameworkD, Core)
- General tasks (Logic, Concurrency, Data Structures, Numerical, Performance, etc.)

### 2.3 Output Review Task List

```
GENERATED_REVIEW_TASKS:
1. [Opus] Task Name
   - Reason: XXX change type detected
   - Checklist: [...]
   - Focus files: [...]

2. [Sonnet] Task Name
   - Reason: ...
   ...
```

______________________________________________________________________

## Phase 3: Execute Review Tasks \[Parallel\]

### 3.1 Execution Rules

- Use Phase 2 specified model for each task
- Execute all agents **in parallel**
- Each agent reviews independently

### 3.2 Agent Output Format

```
REVIEW_RESULT:
task_name: "Task Name"
model: Opus | Sonnet | Haiku
findings:
  - issue: "Issue description"
    severity: CRITICAL | HIGH | MEDIUM | LOW
    file: "path/to/file.py"
    line: 123
    code_snippet: |
      Relevant code snippet
    reason: "Why this is an issue"
    suggestion: "Fix suggestion"
```

### 3.3 Review Depth by Model

| Model      | Requirements                                                               |
| ---------- | -------------------------------------------------------------------------- |
| **Opus**   | Complete context, cross-file traces, verify parallel strategy interactions |
| **Sonnet** | Changed code + direct callers/callees, type signature consistency          |
| **Haiku**  | Format and basic correctness only                                          |

______________________________________________________________________

## Phase 4: Confidence Scoring & Summary \[Haiku\]

### 4.1 Confidence Scoring (0-100)

| Score   | Meaning                               |
| ------- | ------------------------------------- |
| **0**   | False positive or pre-existing issue  |
| **25**  | May be real, cannot verify            |
| **50**  | Real but minor or rare                |
| **75**  | Very likely real, important           |
| **100** | Confirmed real, will frequently occur |

### 4.2 Summary Report Format

```markdown
# PR Review Summary

## PR Overview
- **Title**: PR title
- **Detected Change Types**: [...]
- **Risk Level**: CRITICAL | HIGH | MEDIUM | LOW
- **Generated Review Tasks**: N

## Executed Review Tasks
| # | Model | Task Name | Reason |
|---|-------|-----------|--------|

## Findings

### CRITICAL Severity (Confidence >= 75)
#### Issue 1: [Title]
- **File**: `path/to/file.py:123`
- **Confidence**: 85
- **Description**: ...
- **Fix Suggestion**: ...

### HIGH Severity (Confidence >= 50)
...

## Review Statistics
- Total issues: X (CRITICAL: X, HIGH: X, MEDIUM: X, LOW: X)
- Filtered false positives: X
```

______________________________________________________________________

## Dynamic Generation Examples

| PR Type        | Detected Types                        | Generated Tasks |
| -------------- | ------------------------------------- | --------------- |
| Docs only      | \[DOCS\]                              | 1 Haiku         |
| Config only    | \[CONFIG_ONLY\]                       | 1-2 Haiku       |
| Single bug fix | \[TENSOR_OPS\]                        | 2-4 Sonnet      |
| FrameworkA core | \[FRAMEWORKA\_\*, COMPONENT_A, DATA_TENSOR\] | 4-8 Opus        |
| Cross-domain   | \[WORKFLOW_ENGINE, FRAMEWORK_CORE, TESTS\] | 5-10 mixed      |

______________________________________________________________________

## False Positive Guide (Rate Confidence 0)

- Pre-existing issues (not introduced by this PR)
- Intentionally designed code that looks like a bug
- Issues linter/compiler would catch
- Issues on lines user didn't modify
- Explicitly disabled issues (lint ignore comments)

______________________________________________________________________

## Important Notes

- **Do NOT** check build signals or try to build/type-check
- Use `gh` to interact with GitHub, not web fetch
- **Do NOT** automatically post comments to PR
- Must provide file path and line number when referencing issues

______________________________________________________________________

<!--
================================================================================
                            MAINTAINER GUIDE
================================================================================

Location: ~/.codex/skills/pr-review/SKILL.md
Invocation: $pr-review

## Structure

- Main file (this): workflow, detection categories, and task templates

## How to Update

### Adding New Change Types
Edit the detection categories in this file:
1. Add to appropriate level table (CRITICAL/HIGH/MEDIUM/LOW)
2. Add framework risks if applicable

### Adding New Task Templates
Edit the task template categories in this file:
1. Add to framework-specific or general section
2. Include checklist

### Adjusting Model Selection
Modify "Model Configuration" table in this file.

================================================================================
-->
