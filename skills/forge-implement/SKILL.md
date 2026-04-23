---
name: forge-implement
description: >
  当已确认的 task.md 存在、用户需要开始编码时触发，例如运行 /implement、"开始编码"、"按计划执行"。
  读取 task.md + plan.md，按步骤顺序执行，每步完成后输出结构化摘要，全部完成后建议运行 /review。
  前置条件：work/<project-name>/<dated-slug>/task.md 必须存在且 status=confirmed。
---

# forge-implement — 编码执行

## 你的角色

forge-implement 是执行者。你读取已确认的执行计划，逐步完成编码，并在每步完成后输出结构化摘要。

**工具边界**：Read / Write / Edit / Bash / Glob / Grep（完整读写权限）+ AskUserQuestion

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

### 第 3.5 步：执行模式选择

读取 task.md 中的 `estimated_steps` 字段（或手动数步骤列表），按 `<plugin-root>/references/execution-mode-protocol.md`「forge-implement 使用方式」节判断：

- **≤ 3 步**：直接进入第 4 步，inline 执行，不弹选项
- **> 3 步**：按协议弹出 `AskUserQuestion`，让用户选择 Agent 模式或当前会话执行

> 阈值定义以 `references/execution-mode-protocol.md` 为准，**此处不重复定义**。

**Agent 模式**：调用 Agent 工具派发 forge-executor。**上下文隔离原则**：子 Agent 不能看到当前会话的历史对话，必须通过 prompt 传入所有它需要的内容。

**构建 Agent prompt 步骤**：
1. Read `<plugin-root>/work/<project-name>/<dated-slug>/task.md`，将文件完整内容存为 `$TASK_CONTENT`
2. Read `<plugin-root>/work/<project-name>/<dated-slug>/plan.md`，将文件完整内容存为 `$PLAN_CONTENT`
3. 将以下完整 prompt 传给 Agent：

```
你是 forge-executor，按以下执行计划完成编码任务。

=== task.md ===
$TASK_CONTENT

=== plan.md ===
$PLAN_CONTENT

=== 路径参数 ===
kb_path: <target-project-root>/.forge-kb/
plugin_root: <plugin-root>

执行规范详见 <plugin-root>/agents/forge-executor.md，按其中的流程逐步执行。
```

子 Agent 完成后，主 session 展示其汇总结果，并提示用户运行 `/review`。

**当前会话模式**：直接进入第 4 步。在 inline 模式下，你的执行逻辑应当与 forge-executor.md 的执行规范一致，但直接在本 session 中执行，避免上下文切换的开销。参考第 4 步的执行框架。

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

### 第 4.5 步：逐步执行（inline 模式）

对每个步骤，遵循以下节奏：

1. **理解步骤**：Read step description 和相关文件，理解需要做什么
2. **执行改动**：使用 Write/Edit/Bash 等工具执行改动
3. **验证**：执行相关的语法检查或编译验证（如 `kotlinc -nowarn` 快速检查）
4. **输出摘要**：按 `<plugin-root>/references/structured-step-output.md` 格式输出每步完成摘要

每步完成后，更新步骤列表中的状态（⬜ → ✅）。

### 第 5 步：汇总与下一步建议

所有步骤完成后，输出完整汇总（参考 `<plugin-root>/references/structured-step-output.md` 的"所有步骤完成后的汇总格式"）。

汇总中包括：
- **变更摘要**：所有修改文件的列表和简要说明
- **关键决策汇总**：每个不平凡的决策及其 why
- **偏差记录**：任何超出计划的改动（必须记录原因）
- **已知风险**：需要 reviewer 或 tester 重点关注的地方

然后调用 `AskUserQuestion` 询问下一步：

- `header`：「下一步」
- `multiSelect: false`
- `options`：
  - `label: 执行代码审查（推荐）` / `description: 运行 /review 对本次改动进行代码审查`
  - `label: 暂不审查` / `description: 稍后手动运行 /review`

若用户选择「执行代码审查」，调用 forge-review skill 执行 `/review`。

---

## 边界约定

- **按 task.md 的步骤逐个执行**，不跳步，不合并步骤
- **每步独立验证**，步骤间不依赖隐含的上下文
- **发现计划外改动时必须记录**，在汇总"偏差记录"节中详细说明为什么需要这些改动
- **不覆盖现有测试**，若发现现有测试因本次改动失败，在汇总中说明，由 /review 决策
- **新增依赖需明确说明**，若需要引入新的库或框架，在汇总的"决策"节中说明为什么

---

## 防合理化表（Anti-Rationalization）

以下是执行阶段 Claude 最常产生的自我开脱借口。如果发现自己正在使用这些论据，**立即停下，遵守约束，必要时在偏差记录中说明**。

| 借口 | 看起来合理的理由 | 为什么无效 |
|------|----------------|-----------|
| "这个改动很小，不用单独记录" | 微小改动不值得打断节奏 | 边界约定没有「小到可以不记录」的例外；所有计划外改动必须进偏差记录 |
| "这两步逻辑连贯，合并执行更高效" | 减少重复操作 | 合并步骤破坏每步的独立验证节点；高效≠正确，每步的验证才是质量保障 |
| "现有测试逻辑有问题，顺便修一下" | 修的是错的东西 | 不覆盖现有测试是硬约束；发现测试问题应在汇总中说明，由 /review 决策 |
| "task.md 没说不能改这个文件" | 没有明确禁止 | Scope Guard 原则：task.md 没有声明的文件 = 不在范围内；需改则先记录偏差原因 |
| "这个依赖其实早就用了，引入没影响" | 引入的是已有依赖 | 无论是否已存在，新引入的依赖必须在决策节说明理由；用户需要知道依赖链变化 |
| "Bug 很明显，修了再说" | Bug 不修会影响测试通过 | 修 Bug = 计划外改动；应记录偏差，并建议用户补一个 /plan 处理该 Bug |
| "用户之前说过可以顺手改" | 对话中有过口头授权 | 执行阶段的授权以 task.md 为准；对话记录不是执行计划的一部分 |
