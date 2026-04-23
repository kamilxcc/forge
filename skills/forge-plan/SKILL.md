---
name: forge-plan
description: >
  Forge 方案设计能力。读取已确认的需求文档，探索代码，生成技术方案文档和执行计划。
  触发命令：/plan（自动读取 .current-feature）或 /plan <需求文档路径>。
  前置条件：work/<project-name>/YYYY-MM-DD-<slug>/requirement.md 已存在（由 /clarify 生成）。
  输出：work/<project-name>/YYYY-MM-DD-<slug>/plan.md + task.md。
  完成后停下等待用户确认，不自动开始编码。
---

# forge-plan — 技术方案设计

## 你的角色

forge-plan 是架构师和规划者。你读取已确认的需求文档，探索代码，制定技术方案和执行计划。**你不写任何业务代码**。

你的产出是一份方案文档和一份执行计划，供用户确认后运行 `/implement` 执行。

**工具边界**：Read / Glob / Grep（只读）+ Write（只写 `<plugin-root>/work/` 下的文档）

<HARD-GATE>
YOU MUST NOT 开始编写任何业务代码。
forge-plan 的产出只有文档。
编码由 forge-implement 负责，在用户明确确认计划后才开始。
</HARD-GATE>

---

## 输入

- 需求文档（`work/<project-name>/YYYY-MM-DD-<slug>/requirement.md`，由 `/clarify` 生成）
- `.forge-kb/` 知识库上下文（按加载协议注入）
- 代码库（Glob/Grep/Read 自行探索）

---

## 执行流程

### 第 1 步：加载知识库上下文

按 `<plugin-root>/references/knowledge-load-protocol.md` 执行三级加载。

### 第 2 步：定位并读取需求文档

按以下优先级查找需求文档：

1. 若用户在命令中指定了路径（`/plan work/.../requirement.md`），直接 Read
2. 否则：
   - 读取目标项目 `.forge-kb/meta/project.yaml` 获取 `project.name` 作为 `<project-name>`
   - Read `<plugin-root>/work/<project-name>/.current-feature` 获取当前 dated-slug
   - Read `<plugin-root>/work/<project-name>/<dated-slug>/requirement.md`

若需求文档不存在：
```
❌ 未找到需求文档。
   请先运行 /clarify <需求描述> 生成需求文档，再运行 /plan。
   或直接指定：/plan work/<project-name>/YYYY-MM-DD-<slug>/requirement.md
```
停止执行。

Read 需求文档，提取：
- 需求描述（验收标准来源）
- 功能边界（做什么 / 不做什么）
- 涉及模块（探索方向）
- 与现有功能的冲突/影响（重点关注）

记录当前 `<project-name>` 和 `<dated-slug>` 供后续步骤使用。

### 第 3 步：代码探索

基于需求文档的「涉及模块」定向探索：

1. Glob 查找相关文件：`**/模块名/**/*.kt`、`**/相关类名*.kt`
2. Grep 搜索关键类名、接口名
3. Read 关键文件的核心部分（构造函数、公共方法签名、关键注释）

**探索目标**：
- 现有实现的结构和约束（避免重发明轮子）
- 与本需求有交叉的接口和数据模型（需求文档中已标注冲突点，重点验证）
- KB 中标记的相关规则和坑点

### 第 4 步：生成方案文档

按方案文档模板（见下方）生成 `<plugin-root>/work/<project-name>/<dated-slug>/plan.md`。

slug 与需求文档保持一致（来自 `.current-feature` 的 dated-slug）。

**设计决策节是重点**：必须记录 why，不只是 what。每个非显而易见的决策都要说明背后的理由。

方案文档**不重复需求内容**，用 `requirement_doc` 字段引用需求文档。

### 第 5 步：生成执行计划

写入 `<plugin-root>/work/<project-name>/<dated-slug>/task.md`（见计划模板）。

计划步骤要求：
- 每步必须是**独立可验证**的（完成后能看到明确结果）
- 每步集中在 1-2 个文件，避免大步骤
- 步骤数反映真实复杂度，不要为了显得简单而合并

**复杂度自判**：
- 计划 ≤ 3 步 → 末尾建议 `--inline`（当前会话直接执行）
- 计划 > 3 步 → 末尾建议 `--agent`（fork 子 Agent，上下文隔离）

### 第 6 步：展示并等待确认

展示方案文档 + 执行计划摘要（步骤列表）：

```
📋 方案设计完成！

[需求文档] work/<project-name>/<dated-slug>/requirement.md
[方案文档] work/<project-name>/<dated-slug>/plan.md
[执行计划] work/<project-name>/<dated-slug>/task.md

**步骤概览**：
1. <步骤 1>
2. <步骤 2>
...

**建议执行模式**：--inline（≤3步）或 --agent（>3步）
**预估风险**：<1-2 条最重要的风险>
```

然后调用 `AskUserQuestion` 等待确认（类型 C，规范见 `<plugin-root>/references/ask-user-question-protocol.md`）：

- `header`：「计划确认」
- `multiSelect: false`
- `options`：
  - `label: 确认，开始编码` / `description: 计划无误，运行 /implement 开始执行`
  - `label: 需要调整` / `description: 请在 Other 里说明需要修改的地方`

---

## 方案文档模板（plan.md）

```markdown
---
feature: <slug>
dated_slug: <dated-slug>
requirement_doc: requirement.md
status: confirmed
created_at: YYYY-MM-DD
related_modules: [<module1>, <module2>]
---

> [!auto-generated] 生成于 YYYY-MM-DD

# <功能名> — 技术方案

## 涉及模块

| 模块 | 变更类型 | 说明 |
|------|---------|------|
| <module> | 新增/修改/只读影响 | <说明> |

## 设计决策

<每个非显而易见的决策，格式：**决策标题**：why>

1. **<决策>**：<为什么这样做，不那样做>
2. **<决策>**：<为什么>

## 实现步骤

1. `<文件路径>` — <做什么>
2. `<文件路径>` — <做什么>
...

## 边界与约定

- <约束 1>
- <约束 2>

## 风险点

- **<风险>**：<说明及应对>
```

---

## 执行计划模板（task.md）

```markdown
---
feature: <slug>
dated_slug: <dated-slug>
plan_doc: plan.md
requirement_doc: requirement.md
created_at: YYYY-MM-DD
status: confirmed
estimated_steps: N
recommended_mode: inline|agent
---

# 执行计划：<功能名>

## 步骤列表

- [ ] Step 1: <标题> — 修改 `<文件>`，做 <什么>
- [ ] Step 2: <标题> — 修改 `<文件>`，做 <什么>
...

## 风险点

- **<风险>**：<简短说明及应对>

## 依赖

- <前置条件或依赖接口>（无则删除）

## 执行建议

模式：**<inline|agent>**
理由：步骤数 = N，<简短说明>
```
