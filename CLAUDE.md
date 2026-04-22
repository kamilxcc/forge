# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

This repo **is a Claude Code plugin**, not an application. It ships a single skill (`forge`) that future Claude Code sessions load to run an AI engineering workflow (planning → implementation → review → test → experience-capture) on large target projects. There is no build step, no test runner, no linter — editing the skill's markdown/yaml/scripts is the "development loop."

The plugin targets consumers who will enable it in their own projects. The target project gets a `.forge-kb/` knowledge base at its root; that KB is **not** in this repo. The templates for bootstrapping a target KB live in `skills/forge/templates/kb/`.

## Repository layout

```
skills/forge/
├── SKILL.md                           # Entry point Claude loads. Contains task-router,
│                                      # slash-command dispatch, KB loading protocol,
│                                      # and HARD-GATE / SUBAGENT-GUARD directives.
├── references/
│   ├── agent-prompts/                 # Per-agent full prompts (planner, implementer,
│   │                                  # reviewer, test-writer, depositor, kb-builder).
│   │                                  # Referenced from SKILL.md via
│   │                                  # "详细行为见 references/agent-prompts/<name>.md".
│   └── patterns/                      # Reusable pattern snippets referenced by agents.
├── scripts/                           # Shell scripts invoked by slash commands
│                                      # (e.g. init-kb.sh for /init-kb).
└── templates/kb/                      # Files copied into a target project's .forge-kb/
    ├── project.yaml                   # Always-On meta — <200 tokens, loaded every turn.
    ├── glossary.yaml                  # Always-On — product-term ↔ code-name mapping.
    └── module-map.yaml                # Used by module-resolver to map paths → modules.
```

`references/agent-prompts/` and `references/patterns/` and `scripts/` are currently empty — they are referenced by `SKILL.md` but not yet filled in. New work typically means authoring these files.

## Architecture you must understand before editing

### 1. SKILL.md is the control plane
When a user message comes in, Claude loads `SKILL.md` and follows its **task-router table** to decide which agent/path to invoke. The router distinguishes simple (single-file) from complex (multi-module/interface-changing) work — simple goes `implementer --inline`, complex goes `planner → implementer`. When editing the router, preserve the complexity-judgment rules at the bottom of that section; agents depend on them.

### 2. Two hard invariants enforced by SKILL.md
- **HARD-GATE**: `/plan` must not transition into coding until the user explicitly confirms the plan. Any change that lets `/implement` auto-chain after `/plan` breaks the workflow contract.
- **SUBAGENT-GUARD**: When Claude is spawned as a sub-agent it must skip the skill's routing logic and execute its assigned task directly. If you add new top-level instructions to SKILL.md, make sure they respect this guard (otherwise sub-agents re-enter routing and loop).

### 3. Tiered KB loading is the performance contract
Every task starts with a 3-tier load:
- **Always On** (`project.yaml` + `glossary.yaml`) — sized to stay under ~200 tokens so the cost is negligible.
- **Task Scoped** — `module-map.yaml` + matching `modules/<name>/index.md` + keyword-matched `experience/rules/*.yaml`.
- **On Demand** — agents `Read` specific case files and sub-domain docs during execution.

When adding templates or updating agent prompts, respect these tiers. Do not move on-demand content into always-on, and do not make always-on files grow unboundedly.

### 4. Agent capability boundaries
SKILL.md assigns each agent a deliberate tool budget: `planner` and `reviewer` are read-only; `reviewer` additionally has no `Bash`; `depositor` writes only under `.forge-kb/`; `implementer` has full read/write. If you author new agent prompts under `references/agent-prompts/`, keep the tool-budget expectations consistent with what SKILL.md advertises, or update SKILL.md in the same change.

### 5. Experience-capture loop
`/deposit` reads `.forge-kb/.state/modified-files.txt`, which is written by a `PostToolUse` hook in the **target project's** settings (not this repo's `.claude/settings.json`). When changing the deposit flow, remember the producer of that file lives outside this repo.

## Templates — what's Claude-fillable vs. user-fillable

The files in `templates/kb/` have two kinds of placeholders:
- `YOUR_PROJECT_NAME`, `REPLACE_ME`, `example-module` — literal placeholders the **end user** fills in after `/init-kb`.
- Comments like `# 示例条目` — illustrative entries to delete.

When editing templates, keep the inline maintenance instructions (Chinese comments at top of each yaml) — they are the only onboarding docs a target-project maintainer gets.

## Conventions for this repo

- **Language**: SKILL.md and templates are authored in Chinese; agent prompts should match. Code comments in scripts can be either.
- **No git repo yet**: this directory is not under version control. Do not run `git init` unless the user asks.
- **Permissions file**: `.claude/settings.json` at the repo root grants broad Read/Write/Edit/Bash — it is the *plugin-development* config, not the target-project config. Changes here affect only sessions opened in this directory.
- **Sibling global rule**: the user's global `~/.claude-internal/CLAUDE.md` forbids auto-committing. Never run `git commit` on the user's behalf unless asked.
