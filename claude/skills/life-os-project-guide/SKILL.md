---
name: life-os-project-guide
description: |
  Guide for working with the life-os personal knowledge management system. Use when: (1) Need to create or update CLAUDE.md for the life-os repo, (2) Need to understand the project structure and conventions of life-os, (3) Want to follow the standard workflow for managing projects and diary entries in this system.
author: Claude Code
version: 1.0.0
date: 2026-03-31
---

# Life-OS Project Guide

## Problem
Working with the life-os personal knowledge management system requires understanding its specific structure, conventions, and workflows, which aren't obvious from casual inspection.

## Context / Trigger Conditions
- You need to create or update the CLAUDE.md file for the life-os repository
- You're new to the life-os project and need to understand its structure
- You want to follow the standard workflow for managing projects or diary entries
- You need to create a new project document in the projects directory

## Solution

### Project Overview
life-os is a personal knowledge management system built on Obsidian, using Markdown files for all content. It organizes knowledge by projects, diary entries, and archives.

### Directory Structure
```
life-os/
├── .obsidian/              # Obsidian configuration files
├── projects/               # Project documentation (one Markdown file per project)
├── diary/                  # Diary system with weekly records and templates
│   └── templates/          # Templates for weekly goals and diary entries
├── archive/                # Historical archives organized by year
├── attachments/            # Obsidian-managed attachment files
├── docs/                   # Documentation directory
└── tmp/                    # Temporary files
```

### Core Architecture Patterns
1. **Document-centric**: All knowledge stored as Markdown files
2. **Metadata-driven**: Uses YAML frontmatter for document metadata
3. **Link-based knowledge graph**: Uses [[internal links]] for document associations
4. **Dual organization**: By function (projects, diary, archive) and by time

### Standard Project Document Conventions
Each project in `projects/` follows this structure:
1. **YAML Frontmatter**: Metadata including type, status, dates, tags
2. **Dashboard**: Overview table with status, timeline, progress
3. **Weekly Log**: Table tracking progress by week
4. **Milestones**: Task list for project milestones
5. **Work Log**: Daily time tracking and task breakdown

### Standard Workflows

#### Creating a New Project
1. Copy the template: `cp projects/项目文档模板.md projects/[project-name].md`
2. Update the YAML frontmatter with project details
3. Fill in the Dashboard, weekly logs, milestones, and work logs
4. Add the project to the status table in `projects/README.md`

#### Managing Diary Entries
1. Use templates from `diary/templates/` for weekly goals and diary entries
2. Follow the standardized table formats for tracking progress
3. Organize entries by date in the diary directory

## Verification
The structure and conventions documented here match the existing files in the life-os repository, including:
- README.md overview
- Project documentation template
- Existing project files in projects/

## Example
Creating a new project:
```bash
# Copy the template
cp projects/项目文档模板.md projects/新的项目.md

# Edit the file to add project details
# Then update the README
vim projects/README.md
```

## Notes
- This is a personal knowledge management system, not a software development project with build/test commands
- All content uses Markdown with Obsidian-specific extensions
- Internal links use the [[document-name]] format
- Follow the existing naming conventions for files and directories

## References
- README.md in the root directory
- projects/项目文档模板.md
- projects/README.md