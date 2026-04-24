# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 知识库查询

需要背景知识、技术概念、设计参考时，优先去 `/Users/kamilxiao/my-ai-wiki` 查询，再使用其他来源。

## 设计方案与架构思考

项目的架构设计方案和思考存放在 `/Users/kamilxiao/my-ai-wiki/wiki/topics/design`。涉及架构决策、方案权衡、设计演进时先查阅此目录。

## 参考实现

涉及 skill 设计、plugin 结构、工作流编排等决策时，先去以下参考仓库的源码里分析其方案和实现，再给出建议：

- **superpowers**：https://github.com/obra/superpowers
- **gstack**：https://github.com/garrytan/gstack

## What this repo is

This repo **is a Claude Code plugin**, not an application. It ships multiple skills that future Claude Code sessions load to run an AI engineering workflow (planning → implementation → review → test) on large target projects. There is no build step, no test runner, no linter — editing the skills' markdown/yaml/scripts is the "development loop."

The plugin targets consumers who will enable it in their own projects. Project context (terminology, module map, coding rules) lives in the target project's `CLAUDE.md` at the project root — Claude Code auto-loads it at session start.

## Repository layout

```
forge-plugin/
├── work/                              # 每个目标项目的工作文档（按项目+日期+slug 归档）
│   └── <project-name>/               # 当前工作目录的最后一段路径名（basename $PWD）
│       ├── .current-feature          # 当前 slug 指针（纯文本）
│       └── YYYY-MM-DD-<slug>/        # 一个 feature/fix 一个目录
│           ├── requirement.md        # /clarify 生成（可选）
│           ├── plan.md               # /plan 生成，方案文档（可选）
│           ├── task.md               # /plan 生成，执行计划（可选）
│           ├── review.md             # /review 生成（可选）
│           └── bugfix.md             # /bugfix 生成（可选）
├── hooks/_inactive/                  # 暂存（经验飞轮功能后续再做）
│   ├── post-tool-use.sh
│   └── stop.sh
├── scripts/                           # 工具脚本（直接调用）
│   └── validate-task.sh               # task.md 格式校验脚本
├── references/                        # 所有 skill 共用的 pattern 片段
│   └── structured-step-output.md     # implementer 每步输出格式
├── agents/                            # Sub-agent 定义
│   └── forge-executor.md              # forge-implement Agent 模式下的执行 Agent
├── commands/                          # 扩展用（暂空）
├── docs/                              # 文档（暂空）
├── tests/                             # 测试（暂空）
└── skills/
    ├── _inactive/                     # 暂存的 skill（未激活）
    │   └── forge-deposit.SKILL.md     # /deposit：经验飞轮，后续再做
    ├── forge/                         # 编排层：/go 路由 + /onboard
    │   └── SKILL.md                   # task-router、SUBAGENT-GUARD
    ├── forge-clarify/SKILL.md         # /clarify：需求澄清，输出需求文档
    ├── forge-plan/SKILL.md            # /plan：技术方案 + 执行计划
    ├── forge-implement/SKILL.md       # /implement：按计划执行编码
    ├── forge-review/SKILL.md          # /review：代码审查（PASS/WARN/BLOCK）
    ├── forge-test/SKILL.md            # /test：生成并运行测试
    └── forge-kb/SKILL.md             # ⚠️ 已废弃：/init-kb + /update-kb（知识库管理）
```

新工作通常是修改 `skills/forge-*/SKILL.md` 或 `scripts/`。共用 pattern 在 `references/` 下修改。

## Architecture you must understand before editing

### 1. Each skill is an independent entry point
Each `skills/forge-*/SKILL.md` is loaded directly by Claude Code when the user invokes the corresponding command. `skills/forge/SKILL.md` is the orchestrator — it handles `/go` routing and `/onboard` only. When editing a skill, you are editing the complete capability definition — there are no separate agent-prompt files to keep in sync.

### 2. Two hard invariants

- **HARD-GATE** (in `forge-plan/SKILL.md`): `/plan` must not transition into coding until the user explicitly confirms the plan. Any change that lets `/implement` auto-chain after `/plan` breaks the workflow contract.
- **SUBAGENT-GUARD** (in `forge/SKILL.md`): When Claude is spawned as a sub-agent, it must skip the orchestrator's routing logic and execute its assigned task directly. Individual skills (`forge-plan`, `forge-implement`, etc.) do **not** need this guard — they are called directly.

### 3. Skill capability boundaries
Each skill has a deliberate tool budget declared in its SKILL.md: `forge-plan`, `forge-clarify` and `forge-review` are read-only (plus Write only to `work/`); `forge-review` additionally has no `Bash`; `forge-implement` has full read/write. When editing a skill's execution logic, keep the tool-budget consistent with what the skill's frontmatter/description advertises.

### 4. Work directory — where all task documents live
All task documents (requirement / plan / task / review) are stored in `forge-plugin/work/<project-name>/YYYY-MM-DD-<slug>/`. The current active feature is tracked in `forge-plugin/work/<project-name>/.current-feature` (plain text, contains only the dated slug, e.g. `2026-04-23-add-aiapp-card`). Skills derive all document paths from this file. `<project-name>` is inferred from the last segment of the working directory path (`basename $PWD`).

## Conventions for this repo

- **Language**: SKILL.md files and templates are authored in Chinese; skill content should match. Code comments in scripts can be either.
- **Permissions file**: `.claude/settings.json` at the repo root grants broad Read/Write/Edit/Bash — it is the *plugin-development* config, not the target-project config. Changes here affect only sessions opened in this directory.
- **Sibling global rule**: the user's global `~/.claude-internal/CLAUDE.md` forbids auto-committing. Never run `git commit` on the user's behalf unless asked.
- **No auto-push**: 每次编辑后不要自动执行 `git push`。所有推送操作由用户自行决定何时执行。
