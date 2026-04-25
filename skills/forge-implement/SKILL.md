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

读取 task.md 中的 `estimated_steps` 字段（或手动数步骤列表），按 `<plugin-root>/references/execution-mode-protocol.md`「forge-implement 使用方式」节判断：

- **≤ 3 步**：直接进入第 3 步，inline 执行，不弹选项
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
plugin_root: <plugin-root>

执行规范详见 <plugin-root>/agents/forge-executor.md，按其中的流程逐步执行。
```

派发子 Agent 前，先输出以下提示，让用户知道如何追踪进度：

```
🚀 已启动 Agent 模式执行（共 N 步）。

执行进度实时显示在 Claude Code 左侧的任务面板（Todo list）中，
每步开始时标为进行中，完成后标为已完成。
完成后我会在此展示汇总结果。
```

子 Agent 完成后，主 session 展示其汇总结果，并提示用户运行 `/review`。

**当前会话模式**：直接进入第 3 步。在 inline 模式下，你的执行逻辑应当与 forge-executor.md 的执行规范一致，但直接在本 session 中执行，避免上下文切换的开销。参考第 3 步的执行框架。

### 第 3 步：初始化任务列表（inline 模式）

读取 task.md 中的步骤列表，调用 `TodoWrite` 把所有步骤写入任务列表，状态全部设为 `pending`：

```
TodoWrite([
  { id: "step-1", content: "Step 1: <标题>", status: "pending", priority: "high" },
  { id: "step-2", content: "Step 2: <标题>", status: "pending", priority: "high" },
  ...
])
```

用户在 Claude Code 任务面板里能实时看到执行进度。

**并行标注**：初始化任务列表时，检查步骤间的依赖关系：

- 若相邻步骤的 `文件` 字段**完全不重叠**，且步骤 N+1 不依赖步骤 N 的输出 → 在内部标记为「可并行」
- 可并行的步骤在第 3.5 步中**合并为单次 Agent 并发调用**，而非串行等待
- 有依赖关系的步骤（如步骤 N+1 要读步骤 N 新建的文件）→ 保持串行

### 第 3.5 步：逐步执行（inline 模式）

对每个步骤，遵循以下节奏：

1. **开始前**：调用 `TodoWrite` 将当前步骤状态改为 `in_progress`
2. **约束核对**：对照 Step 2 提取的执行约束基线，检查本步改动是否违反设计决策或边界约定，是否触碰风险点；有冲突 → 停止，AskUserQuestion 说明冲突
3. **理解步骤**：task.md 是自包含的（/plan 的 Stage B 已把关键代码片段内联进来），**直接读 task.md 本步骤内容执行，不做额外 Glob/Grep/Read**
   - **唯一例外**：该文件已被前步修改，需要读最新状态 → Read 文件获取当前内容
3. **执行改动**：使用 Write/Edit/Bash 等工具执行改动
4. **步骤级止损**：执行过程中遇到以下任一情况，立即触发止损协议（见下方）：
   - 实际代码与 task.md 描述不符（方法签名/参数数量/文件结构与预期不一致）
   - 本步改动可能影响 task.md 未列出的调用方（发现多处依赖当前修改的方法/接口）
   - 出现非预期编译或 lint 报错，且不是本步骤引入的已知改动导致的
5. **验证**：执行相关的语法检查或编译验证（如 `kotlinc -nowarn` 快速检查）
6. **完成后**：调用 `TodoWrite` 将当前步骤状态改为 `completed`，再输出步骤摘要；将 task.md 中对应步骤的 `- [ ]` 改为 `- [x]`（持久化进度）

**步骤级止损协议**：

触发后停止执行当前步骤，输出：

```
⛔ Step N 执行中止

发现：<具体不一致描述>
task.md 预期：<预期内容>
实际情况：<实际内容>
```

然后调用 `AskUserQuestion`：
- `header`：「执行中止」
- `multiSelect: false`
- `options`：
  - `label: 按实际情况调整后继续` / `description: 以实际代码为准，调整本步执行方式后继续`
  - `label: 停止，重新 /plan` / `description: 停止执行，回到 /plan 重新生成计划`
  - `label: 跳过本步骤` / `description: 跳过当前步骤，继续执行后续步骤`

用户选择「按实际情况调整后继续」时，将调整内容记录到步骤摘要的「关键决策」字段，并在汇总「偏差记录」中标注。

### 第 3.8 步：完成验收清单（Verification Checklist）

所有步骤的 `TodoWrite` 都已标为 `completed` 后，在输出汇总前，逐项核查以下清单。**每项必须明确回答 ✅ / ❌ / N/A，不可跳过**：

| # | 检查项 | 通过标准 |
|---|--------|---------|
| 1 | **所有步骤均已执行** | task.md 中无残留 `[ ]` 步骤 |
| 2 | **无未声明的计划外改动** | 所有超出 task.md 文件范围的改动均已在「偏差记录」中记录原因 |
| 3 | **边界约定遵守** | plan.md 中「边界与约定」节的每条"不做什么"均未被触碰 |
| 4 | **CLAUDE.md 项目规则合规** | 涉及日志的地方使用了 Logger 接口（非 Log/println）；FeedList 的 View 未使用屏幕宽度硬编码（或已说明理由）；改动方法前已搜索并评估所有调用方 |
| 5 | **范围外发现已显式声明** | 执行中发现的范围外问题，均已在对应步骤摘要「发现但未触碰」字段中记录 |
| 6 | **现有测试未被覆盖** | 未修改任何现有测试文件，或已在偏差记录中说明原因 |

若任一项为 ❌：停止，说明具体违反原因，调用 `AskUserQuestion` 询问用户处理方式（修复 / 记录偏差后继续 / 停止）。

所有项为 ✅ 或 N/A 后，继续第 4 步。

### 第 4 步：汇总与下一步建议

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
| "这个文件刚才没改，重新 Read 一下更保险" | 防止信息过时 | task.md 是自包含的，关键代码片段已由 /plan 内联进来；只有前步已修改过的文件才需要重新 Read，其余直接按 task.md 执行 |
