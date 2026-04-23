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

The plugin targets consumers who will enable it in their own projects. The target project gets a `.forge-kb/` knowledge base at its root; that KB is **not** in this repo. The templates for bootstrapping a target KB live in `skills/forge/templates/kb/`.

## Repository layout

```
forge-plugin/
├── work/                              # 每个目标项目的工作文档（按项目+日期+slug 归档）
│   └── <project-name>/               # 来自目标项目 project.yaml 的 project.name
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
│   ├── init-kb.sh                     # /init-kb: 在目标项目初始化 .forge-kb/ 目录树
│   └── kb-load.sh                     # 知识库加载封装，输出三级 KB 内容到 stdout
├── references/                        # 所有 skill 共用的 pattern 片段
│   ├── knowledge-load-protocol.md     # 三级 KB 加载协议
│   └── structured-step-output.md     # implementer 每步输出格式
├── agents/                            # 扩展用（暂空）
├── commands/                          # 扩展用（暂空）
├── docs/                              # 文档（暂空）
├── tests/                             # 测试（暂空）
└── skills/
    ├── _inactive/                     # 暂存的 skill（未激活）
    │   └── forge-deposit.SKILL.md     # /deposit：经验飞轮，后续再做
    ├── forge/                         # 编排层：/go 路由 + /onboard
    │   ├── SKILL.md                   # task-router、SUBAGENT-GUARD
    │   └── templates/kb/              # 目标项目 .forge-kb/ 的初始化模板
    │       ├── project.yaml           # Always-On meta，<200 tokens
    │       ├── glossary.yaml          # Always-On 产品术语映射
    │       └── module-map.yaml        # 模块路径映射
    ├── forge-clarify/SKILL.md         # /clarify：需求澄清，输出需求文档
    ├── forge-plan/SKILL.md            # /plan：技术方案 + 执行计划
    ├── forge-implement/SKILL.md       # /implement：按计划执行编码
    ├── forge-review/SKILL.md          # /review：代码审查（PASS/WARN/BLOCK）
    ├── forge-test/SKILL.md            # /test：生成并运行测试
    └── forge-kb/SKILL.md             # /init-kb + /update-kb：知识库管理
```

新工作通常是修改 `skills/forge-*/SKILL.md` 或 `scripts/`。共用 pattern 在 `references/` 下修改。

## Architecture you must understand before editing

### 1. Each skill is an independent entry point
Each `skills/forge-*/SKILL.md` is loaded directly by Claude Code when the user invokes the corresponding command. `skills/forge/SKILL.md` is the orchestrator — it handles `/go` routing and `/onboard` only. When editing a skill, you are editing the complete capability definition — there are no separate agent-prompt files to keep in sync.

### 2. Two hard invariants

- **HARD-GATE** (in `forge-plan/SKILL.md`): `/plan` must not transition into coding until the user explicitly confirms the plan. Any change that lets `/implement` auto-chain after `/plan` breaks the workflow contract.
- **SUBAGENT-GUARD** (in `forge/SKILL.md`): When Claude is spawned as a sub-agent, it must skip the orchestrator's routing logic and execute its assigned task directly. Individual skills (`forge-plan`, `forge-implement`, etc.) do **not** need this guard — they are called directly.

### 3. Tiered KB loading is the performance contract
Every task starts with a 3-tier load (protocol in `references/knowledge-load-protocol.md`):
- **Always On** (`project.yaml` + `glossary.yaml`) — sized to stay under ~200 tokens so the cost is negligible.
- **Task Scoped** — `module-map.yaml` + matching `modules/<name>/index.md` + keyword-matched `experience/rules/*.yaml`.
- **On Demand** — skills `Read` specific case files and sub-domain docs during execution.

When updating skills or templates, respect these tiers. Do not move on-demand content into always-on, and do not make always-on files grow unboundedly.

### 4. Skill capability boundaries
Each skill has a deliberate tool budget declared in its SKILL.md: `forge-plan`, `forge-clarify` and `forge-review` are read-only (plus Write only to `work/`); `forge-review` additionally has no `Bash`; `forge-implement` has full read/write. When editing a skill's execution logic, keep the tool-budget consistent with what the skill's frontmatter/description advertises.

### 5. Work directory — where all task documents live
All task documents (requirement / plan / task / review) are stored in `forge-plugin/work/<project-name>/YYYY-MM-DD-<slug>/`. The current active feature is tracked in `forge-plugin/work/<project-name>/.current-feature` (plain text, contains only the dated slug, e.g. `2026-04-23-add-aiapp-card`). Skills derive all document paths from this file. The target project's `.forge-kb/` only contains the knowledge base — no state files.

## Templates — what's Claude-fillable vs. user-fillable

The files in `templates/kb/` have two kinds of placeholders:
- `YOUR_PROJECT_NAME`, `REPLACE_ME`, `example-module` — literal placeholders the **end user** fills in after `/init-kb`.
- Comments like `# 示例条目` — illustrative entries to delete.

When editing templates, keep the inline maintenance instructions (Chinese comments at top of each yaml) — they are the only onboarding docs a target-project maintainer gets.

## Conventions for this repo

- **Language**: SKILL.md files and templates are authored in Chinese; skill content should match. Code comments in scripts can be either.
- **Permissions file**: `.claude/settings.json` at the repo root grants broad Read/Write/Edit/Bash — it is the *plugin-development* config, not the target-project config. Changes here affect only sessions opened in this directory.
- **Sibling global rule**: the user's global `~/.claude-internal/CLAUDE.md` forbids auto-committing. Never run `git commit` on the user's behalf unless asked.
