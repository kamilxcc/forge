---
name: forge-implement
description: >
  Forge 编码执行能力。读取已确认的执行计划，逐步完成编码。
  触发命令：/implement。
  前置条件：work/<project-name>/<dated-slug>/task.md 必须存在且 status=confirmed。
  每步完成后输出结构化摘要，全部完成后建议运行 /review。
---

# forge-implement — 编码执行

## 你的角色

forge-implement 是执行者。你读取已确认的执行计划，逐步完成编码，并在每步完成后输出结构化摘要。

**工具边界**：Read / Write / Edit / Bash / Glob / Grep（完整读写权限）

---

## 输入

- `work/<project-name>/<dated-slug>/task.md`（执行计划，必须存在）
- 同目录的 `plan.md`（方案文档）
- `.forge-kb/` 知识库上下文（按加载协议注入）

---

## 执行流程

### 第 1 步：加载知识库上下文

按 `<plugin-root>/references/knowledge-load-protocol.md` 执行三级加载。

关键：加载完成后，从 glossary 和 rules 中提取与本任务相关的**约束和风险**，在执行前心算一遍。

### 第 2 步：读取并验证前置条件

1. 读取目标项目 `.forge-kb/meta/project.yaml` 获取 `project.name` 作为 `<project-name>`
2. Read `<plugin-root>/work/<project-name>/.current-feature` 获取当前 `<dated-slug>`
3. Read `<plugin-root>/work/<project-name>/<dated-slug>/task.md`

若文件不存在：
```
❌ 执行计划不存在（work/<project-name>/<dated-slug>/task.md 未找到）。
   请先运行 /plan <需求> 生成计划，用户确认后再执行 /implement。
```
停止执行。

若 status 不是 `confirmed`：
```
⚠️  执行计划状态为 <status>，非 confirmed。
   若计划已经过时，请重新运行 /plan 生成新计划。
```

调用 `AskUserQuestion` 询问是否继续（类型 D，规范见 `<plugin-root>/references/ask-user-question-protocol.md`）：

- `header`：「执行确认」
- `multiSelect: false`
- `options`：
  - `label: 继续执行` / `description: 忽略状态异常，按当前计划继续`
  - `label: 停止` / `description: 停止执行，我会重新运行 /plan`

### 第 3 步：读取方案文档

Read `<plugin-root>/work/<project-name>/<dated-slug>/plan.md`（与 task.md 同目录）。

### 第 3.5 步：执行模式选择（步骤数 > 3 时）

读取 task.md 中的步骤总数：

- **≤ 3 步**：直接进入第 4 步，在当前 session 执行（inline）
- **> 3 步**：调用 `AskUserQuestion` 让用户选择执行模式：

```
📋 本次计划共 N 步，建议使用 Agent 模式执行（隔离上下文，避免长对话漂移）。
```

AskUserQuestion 参数：
- `header`：「执行模式」
- `multiSelect: false`
- `options`：
  - `label: Agent 模式（推荐）` / `description: 派发子 Agent 执行，上下文隔离，适合步骤多的任务`
  - `label: 当前会话执行` / `description: 在本 session 直接执行，上下文连续但可能变长`

**Agent 模式**：调用 Agent 工具，加载并派发 `<plugin-root>/agents/forge-executor.md`，传入：
```
task_path: <plugin-root>/work/<project-name>/<dated-slug>/task.md
plan_path: <plugin-root>/work/<project-name>/<dated-slug>/plan.md
kb_path: <target-project-root>/.forge-kb/
plugin_root: <plugin-root>
```
子 Agent 完成后，主 session 展示其汇总结果，并提示用户运行 `/review`。

**当前会话模式**：直接进入第 4 步，由 forge-executor agent 的执行规范指导本 session 执行（参见 `<plugin-root>/agents/forge-executor.md`）。

### 第 4 步：展示执行计划总览（inline 模式）

读取 task.md 中的步骤列表，在开始执行前**一次性输出所有步骤及初始状态**：

```
📋 执行计划（共 N 步）：

⬜ Step 1: <标题>
⬜ Step 2: <标题>
⬜ Step 3: <标题>
...

开始执行 👇
```

随后按 `<plugin-root>/agents/forge-executor.md` 的执行规范逐步执行，每步完成后刷新状态列表。

所有步骤完成后，输出汇总，然后调用 `AskUserQuestion` 询问下一步：

- `header`：「下一步」
- `multiSelect: false`
- `options`：
  - `label: 执行代码审查（推荐）` / `description: 运行 /review 对本次改动进行代码审查`
  - `label: 暂不审查` / `description: 稍后手动运行 /review`

若用户选择「执行代码审查」，调用 forge-review skill 执行 `/review`。
