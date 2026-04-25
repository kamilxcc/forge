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

---

## 执行流程

### 第 1 步：读取并验证前置条件

1. 获取 `<project-name>`：使用当前工作目录的最后一段路径名
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

**断点续传检测**（status 检查通过后执行）：

扫描步骤列表中 `[ ]` 和 `[x]` 的分布：

| 状态 | 处理方式 |
|------|---------|
| 全部 `[ ]` | 正常从第 1 步开始，不提示 |
| 全部 `[x]` | 输出「所有步骤已完成，建议运行 /review」，停止执行 |
| 混合（部分 `[x]`，部分 `[ ]`）| 调用 `AskUserQuestion` 询问用户（见下方） |

混合状态时输出：
```
🔄 发现执行中断记录：N 步已完成，M 步待执行。
   已完成：Step 1～Step N
   待执行：Step N+1～Step N+M
```

然后调用 `AskUserQuestion`：
- `header`：「断点续传」
- `multiSelect: false`
- `options`：
  - `label: 从 Step N+1 继续` / `description: 跳过已完成步骤，从第一个未完成步骤继续执行`
  - `label: 从头重新执行` / `description: 忽略已有进度，重新执行全部步骤`
  - `label: 停止` / `description: 不执行，我来手动处理`

用户选择「从 Step N+1 继续」时，第 4 步的 `TodoWrite` 初始化任务列表时，已完成步骤直接设为 `completed`，只把未完成步骤设为 `pending`；第 4.5 步从第一个 `[ ]` 步骤开始执行，跳过所有 `[x]` 步骤。

### 第 2 步：读取方案文档，提取执行约束

Read `<plugin-root>/work/<project-name>/<dated-slug>/plan.md`，提取以下三节作为**执行约束基线**：

- **设计决策**：每个决策的 why，执行时不得偏离
- **边界与约定**：明确说了不做什么，执行时遇到边界情况直接拒绝，不擅自扩展
- **风险点**：需要特别小心的地方，在对应步骤执行前重点核对

提取后在内部保持这三节内容，**Step 3.5 每步执行前都要对照检查**：本步改动是否违反任何设计决策或边界约定？是否触碰了风险点？若有冲突 → 停止执行，用 AskUserQuestion 说明冲突并询问用户。

### 第 2.5 步：执行模式选择

读取 task.md 中的 `recommended_mode` 字段（或根据步骤数判断），**直接按推荐模式执行，不弹选项**：

- **inline**（≤ 3 步）→ 直接进入第 3 步
- **agent**（> 3 步）→ 派发 forge-executor（见下方 Agent 模式）

执行前输出一行提示：
```
📋 本次计划共 N 步，执行模式：<inline|Agent>
```

> 阈值定义以 `references/execution-mode-protocol.md` 为准。

**Agent 模式**：调用 Agent 工具派发 forge-executor。**上下文隔离原则**：子 Agent 不能看到当前会话的历史对话，必须通过 prompt 传入所有它需要的内容。

**构建 Agent prompt 步骤**：
1. Read `<plugin-root>/work/<project-name>/<dated-slug>/task.md`，将文件完整内容存为 `$TASK_CONTENT`
2. Read `<plugin-root>/work/<project-name>/<dated-slug>/plan.md`，提取「设计决策」+「边界与约定」+「风险点」三节内容存为 `$PLAN_CONSTRAINTS`
3. 将以下完整 prompt 传给 Agent：

```
你是 forge-executor，按以下执行计划完成编码任务。

=== task.md ===
$TASK_CONTENT

=== 执行约束（来自 plan.md） ===
$PLAN_CONSTRAINTS

=== 路径参数 ===
plugin_root: <plugin-root>
plan_path: <plugin-root>/work/<project-name>/<dated-slug>/plan.md

执行规范详见 <plugin-root>/agents/forge-executor.md，按其中的流程逐步执行。
```

派发子 Agent 前，先输出以下提示：

```
🚀 已启动 Agent 模式执行（共 N 步）。

执行进度实时显示在 Claude Code 左侧的任务面板（Todo list）中，
每步开始时标为进行中，完成后标为已完成。
完成后我会在此展示汇总结果。
```

子 Agent 完成后，主 session 展示其汇总结果，然后调用 `AskUserQuestion` 询问下一步（与 inline 模式第 3.8 步相同的选项）。

> ⚠️ 子 Agent 无法调用 AskUserQuestion，因此所有用户交互（下一步建议、验收清单异常处理）统一由主 session 在收到汇总后处理。

**当前会话模式**：直接进入第 3 步。

### 第 3 步：执行编码（inline 模式）

按 `<plugin-root>/references/execution-core-protocol.md` 执行：
1. 初始化 TodoWrite 任务列表
2. 逐步执行（约束核对 → 执行 → Scope Guard → 止损 → 验证）
3. 完成验收清单（6 项）

**inline 模式特有**：
- 步骤级止损和信息缺口时使用 `AskUserQuestion` 与用户交互
- 验收清单有 ❌ 时停止并询问用户处理方式
- **并行标注**：初始化时检查步骤间依赖，若相邻步骤文件不重叠且无依赖 → 标记「可并行」，合并为单次并发调用

### 第 3.8 步：汇总与下一步建议

所有步骤完成后，输出完整汇总（参考 `<plugin-root>/references/structured-step-output.md` 的"所有步骤完成后的汇总格式"）。

汇总中包括：
- **变更摘要**：所有修改文件的列表和简要说明
- **关键决策汇总**：每个不平凡的决策及其 why
- **偏差记录**：任何超出计划的改动（必须记录原因）
- **已知风险**：需要 reviewer 或 tester 重点关注的地方
- **未触碰声明**：执行中发现但未处理的范围外问题（汇总自各步骤「发现但未触碰」字段）
- **验收清单结果**：第 3.8 步各项的 ✅ / ❌ / N/A 结果（供 /review 快速定位风险区域）

> 汇总的读者是 /review。**变更摘要中的文件列表**将由 forge-review 直接消费作为审查范围，确保列表完整准确。

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
- **发现范围外问题但不处理时，必须显式声明**：在本步骤摘要的「发现但未触碰」字段记录，汇总时合并到「未触碰声明」节；沉默跳过等同于信息损失
- **不覆盖现有测试**，若发现现有测试因本次改动失败，在汇总中说明，由 /review 决策
- **新增依赖需明确说明**，若需要引入新的库或框架，在汇总的"决策"节中说明为什么

---

## 防合理化

参见 `<plugin-root>/references/implement-guardrails.md`。执行过程中如果发现自己正在使用其中的借口，**立即停下，遵守约束**。
