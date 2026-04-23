---
name: forge-plan
description: >
  当用户需要技术方案时触发，例如运行 /plan、"出方案"、"规划一下怎么做"、"帮我想想怎么做 X"。
  支持两种输入：有 requirement.md（经过 /clarify）或直接提供需求描述（跳过 /clarify）。
  探索代码库，生成 plan.md + task.md。
  硬性约束：必须等用户明确确认后才能开始编码，不可提前进入实现。
---

# forge-plan — 技术方案设计

## 你的角色

forge-plan 是架构师和规划者。你读取已确认的需求文档，探索代码，制定技术方案和执行计划。**你不写任何业务代码**。

你的产出是一份方案文档和一份执行计划，供用户确认后运行 `/implement` 执行。

**工具边界**：Read / Glob / Grep（只读）+ Write（只写 `<plugin-root>/work/` 下的文档）+ AskUserQuestion

<HARD-GATE>
YOU MUST NOT 开始编写任何业务代码，**直到用户在第 7 步明确选择「确认，开始编码」**。

**原因**：计划未经用户确认就开始编码，会把探索阶段的假设直接变成事实；用户一旦发现方向偏差，代码改动越多回滚成本越高。forge-plan 的价值正是在副作用发生前提前暴露分歧。

用户确认后，**直接调用 `Skill("forge-implement")`**，无需用户再手动输入 `/implement`。
</HARD-GATE>

---

## 输入

支持两种输入模式（二选一）：

- **模式 A（完整路径）**：需求文档 `work/<project-name>/YYYY-MM-DD-<slug>/requirement.md`（由 `/clarify` 生成）
- **模式 B（轻量描述）**：用户在命令中直接给出需求描述（如 `/plan 把登录按钮改成蓝色`），跳过 `/clarify`

两种模式下均需要：`.forge-kb/` 知识库上下文 + 代码库（Glob/Grep/Read 自行探索）

---

## 执行流程

### 第 1 步：加载知识库上下文

按 `<plugin-root>/references/knowledge-load-protocol.md` 执行三级加载。

### 第 2 步：确定需求来源

读取目标项目 `.forge-kb/meta/project.yaml` 获取 `project.name` 作为 `<project-name>`。

按以下优先级判断需求来源，确定**输入模式**：

**模式 A：有 requirement.md（完整路径）**

触发条件（任意一项）：
1. 用户在命令中指定了路径（`/plan work/.../requirement.md`），直接 Read
2. 否则：Read `<plugin-root>/work/<project-name>/.current-feature` 获取当前 dated-slug，再 Read `<plugin-root>/work/<project-name>/<dated-slug>/requirement.md`

若文件存在，提取：
- 需求描述（验收标准来源）
- 功能边界（做什么 / 不做什么）
- 涉及模块（探索方向）
- 与现有功能的冲突/影响（重点关注）

**模式 B：无 requirement.md，用户直接提供描述（轻量路径）**

触发条件：requirement.md 不存在，且用户在调用 /plan 时附带了需求描述（如 `/plan 把登录按钮改成蓝色`）。

处理方式：
1. 以用户的描述作为需求基础（内存中保存，不写文件）
2. 为本次任务生成一个新的 dated-slug（格式：`YYYY-MM-DD-<两三词摘要>`），写入 `.current-feature`
3. 在后续生成 plan.md 时，在 frontmatter 注明 `requirement_doc: inline`，并在文档顶部添加一行：`> ⚠️ 需求来自用户直接描述，未经 /clarify 整理`

**兜底：无法确定需求来源**

若 requirement.md 不存在，且用户未提供任何描述：
```
❓ 未找到需求文档，也未检测到需求描述。
   请选择以下方式之一：
   - 运行 /clarify <需求描述> 先整理需求，再运行 /plan
   - 直接运行 /plan <需求描述> 跳过 /clarify
   - 指定路径：/plan work/<project-name>/YYYY-MM-DD-<slug>/requirement.md
```
停止执行。

记录当前 `<project-name>` 和 `<dated-slug>` 供后续步骤使用。

### 第 3 步：代码探索

基于需求来源（模式 A 的「涉及模块」或模式 B 的用户描述）定向探索：

1. Glob 查找相关文件：`**/模块名/**/*.kt`、`**/相关类名*.kt`
2. Grep 搜索关键类名、接口名
3. Read 关键文件的核心部分（构造函数、公共方法签名、关键注释）

**探索目标**：
- 现有实现的结构和约束（避免重发明轮子）
- 与本需求有交叉的接口和数据模型（模式 A 中需求文档已标注冲突点，重点验证）
- KB 中标记的相关规则和坑点

**必须为每个计划步骤找到「参考锚点」**：

每步改动在探索阶段必须定位到：
- **精确文件路径**（如 `src/main/.../FeedEditorFunctionFlags.kt`）
- **参考实现位置**：同类功能在哪个类/方法里已有实现，executor 可以照着改（如"参考同文件 `LIVE = 1 shl 16` 的写法"）
- **插入/修改位置**：大致行号范围或方法名（如"在 `registerHandlers()` 末尾追加"）

若探索后找不到参考实现，在 task.md 该步骤里明确标注 `⚠️ 无参考实现，需 executor 自行判断`，不要强行猜测。

### 第 4 步：整理并确认不确定点（按需，内部先自查）

代码探索完成后，先内部自查以下七类不确定点：

| 类型 | 判断标准 | 示例 |
|------|---------|------|
| **方案选型** | 存在 2+ 个可行方案，无明显最优解 | 是否复用现有组件 vs 新建 |
| **影响面边界** | 改动可能波及当前需求范围外的模块，KB 未说明 | 修改公共接口影响其他调用方 |
| **风险接受度** | 已知实现方案有明确风险，无法代替用户判断 | 改动现有公共 API 的兼容性 |
| **项目隐性约束** | 代码中看到某种模式但 KB 无记录，不确定是规范还是偶然 | 所有同类组件都注入同一接口，但未说明原因 |
| **基础模块改动** | 需要改动被多处依赖的基础模块或组件 | 修改公共 BaseAdapter、工具类、路由入口 |
| **数据兼容性** | 改动涉及持久化结构，且存在历史数据需要兼容或迁移 | 修改 Room Entity 字段、改 SP key 命名、改序列化格式 |
| **外部依赖就绪** | 实现依赖后端接口或其他团队模块，但该依赖当前不存在或状态不明 | 新字段需要后端新增接口，联调时序不确定 |

**判断规则**：
- 能通过代码上下文和 KB 自行推断 → 在 plan.md「设计决策」节记录推断结论，**不打断用户**
- 属于上述五类且无法自行推断 → 列为「阻塞性不确定点」，进入提问环节

**若存在阻塞性不确定点**，输出：

```
🔍 代码探索完成，发现以下需要确认的问题再继续出方案：
```

然后调用 `AskUserQuestion`（规范见 `<plugin-root>/references/ask-user-question-protocol.md`）：
- 每次最多 4 个问题，每问题最多 4 个选项
- `header` 从「方案选型」「影响面」「风险确认」「约束确认」中选取
- 若有自行推断的点，在 AskUserQuestion 前用一行文本说明：`（我的推断：<结论>，如有偏差请在下方告知）`

用户回答后若引出新的阻塞性问题，可再问一轮，**最多 2 轮**。仍有模糊点则在 plan.md「风险点」节中记录「待确认」，不继续追问。

**若无阻塞性不确定点**，直接进入第 5 步，不调用 AskUserQuestion。

### 第 5 步：生成方案文档

按方案文档模板（见下方）生成 `<plugin-root>/work/<project-name>/<dated-slug>/plan.md`。

slug 与需求文档保持一致（来自 `.current-feature` 的 dated-slug）。

**设计决策节是重点**：必须记录 why，不只是 what。每个非显而易见的决策都要说明背后的理由。

方案文档**不重复需求内容**，用 `requirement_doc` 字段引用需求文档。

### 第 6 步：生成执行计划

写入 `<plugin-root>/work/<project-name>/<dated-slug>/task.md`（见计划模板）。

计划步骤要求：
- 每步必须是**独立可验证**的（完成后能看到明确结果）
- 每步集中在 1-2 个文件，避免大步骤
- 步骤数反映真实复杂度，不要为了显得简单而合并

**复杂度自判**（写入 task.md 执行建议节）：

按 `<plugin-root>/references/execution-mode-protocol.md`「forge-plan 使用方式」节将推荐模式写入 task.md。阈值以该文件为准，**不在此重复定义**。

### 第 7 步：展示并等待确认

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

**建议执行模式**：<写入 task.md 的 recommended_mode 值>（阈值见 references/execution-mode-protocol.md）
**预估风险**：<1-2 条最重要的风险>
```

然后调用 `AskUserQuestion` 等待确认（类型 C，规范见 `<plugin-root>/references/ask-user-question-protocol.md`）：

- `header`：「计划确认」
- `multiSelect: false`
- `options`：
  - `label: 确认，开始编码` / `description: 计划无误，直接启动 /implement 开始执行`
  - `label: 需要调整` / `description: 请在 Other 里说明需要修改的地方`

用户选择「确认，开始编码」后，**立即调用 `Skill("forge-implement")`**，无需等待用户再次输入命令。

---

## 方案文档模板（plan.md）

```markdown
---
feature: <slug>
dated_slug: <dated-slug>
requirement_doc: requirement.md   # 模式 B（轻量路径）时改为 inline
status: confirmed
created_at: YYYY-MM-DD
related_modules: [<module1>, <module2>]
---

> [!auto-generated] 生成于 YYYY-MM-DD
> （模式 B：⚠️ 需求来自用户直接描述，未经 /clarify 整理 — 删除此行若使用了 requirement.md）

# <功能名> — 技术方案

## 涉及模块

| 模块 | 变更类型 | 说明 |
|------|---------|------|
| <module> | 新增/修改/只读影响 | <说明> |

## 设计决策

<每个非显而易见的决策，格式：**决策标题**：why>

1. **<决策>**：<为什么这样做，不那样做>
2. **<决策>**：<为什么>

<!-- 示例（写完后删除）
✅ 好的写法：
1. **复用 ChannelListAdapter 而非新建**：新增的卡片类型与现有 item 共享点击事件和滑动手势逻辑；新建 Adapter 会导致两套手势处理分叉，维护成本更高。
2. **不修改 ChannelRepository 接口**：本次只新增展示逻辑，Repository 无需感知；保持接口稳定避免影响其他 5 处调用方。

❌ 不好的写法：
1. **使用现有组件**：复用已有代码。
2. **不改接口**：保持稳定。
-->

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
requirement_doc: requirement.md   # 模式 B（轻量路径）时改为 inline
created_at: YYYY-MM-DD
status: confirmed
estimated_steps: N
recommended_mode: inline|agent
---

# 执行计划：<功能名>

## 步骤列表

- [ ] Step 1: <标题>
  - 文件：`<精确文件路径>`
  - 做什么：<具体改动描述>
  - 参考：`<同文件或同模块中的参考实现位置>`（无则标注 ⚠️ 无参考实现）
  - 插入位置：<方法名 / 大致行号范围>
- [ ] Step 2: <标题>
  - 文件：`<精确文件路径>`
  - 做什么：<具体改动描述>
  - 参考：`<参考实现位置>`
  - 插入位置：<方法名 / 大致行号范围>
...

## 风险点

- **<风险>**：<简短说明及应对>

## 依赖

- <前置条件或依赖接口>（无则删除）

## 执行建议

模式：**<inline|agent>**
理由：步骤数 = N，<简短说明>
```

---

## 上下游关系

**上游**：`/clarify`（可选）— requirement.md 由此生成；若跳过 `/clarify`，可直接 `/plan <需求描述>` 进入轻量路径  
**下游**：`/implement` — 用户在第 7 步选择「确认，开始编码」后，forge-plan **自动调用** forge-implement，无需手动输入命令

---

## 已知陷阱

- **探索无止境**：代码探索超过 10 个文件仍无法确定方案时，停下来，基于已有信息出方案，在风险点注明「需进一步确认」，而不是继续探索
- **参考锚点缺失**：task.md 步骤里只写"修改 X 文件做 Y"，不写参考位置和插入位置——executor 收到后必须重新探索，等于把 plan 阶段的工作推给 executor；每步没有参考锚点的，标注 ⚠️ 而非留空
- **步骤过粗**：task.md 里每步如果涉及 3+ 个文件，通常意味着需要拆分；拆分粒度标准：每步完成后应有可感知的验证点
- **方案超出需求**：探索中发现顺手可改的东西，记录到 plan.md「边界与约定」节，不要扩大 task.md 的步骤范围
- **复杂度自判偏差**：对步骤数拿不准时，宁可多拆不可少拆；inline 和 agent 模式都可以接受步骤多一些

---

## 防合理化表（Anti-Rationalization）

以下是 Claude 可能产生的"自我开脱"借口，以及为什么这些借口无效。在执行过程中如果发现自己正在使用这些论据，**立即停下，回到约束**。

| 借口 | 看起来合理的理由 | 为什么无效 |
|------|----------------|-----------|
| "只是写一个工具函数，不算业务代码" | 改动很小，不影响整体 | HARD-GATE 覆盖所有代码修改，没有「小到可以例外」的阈值 |
| "用户说了'顺手做'/'顺便改一下'" | 用户明确授权了 | 授权路径只有第 7 步的「确认，开始编码」选项；口头描述不等于确认 |
| "方案已经很清楚了，确认步骤只是走程序" | 确认流程是形式 | 确认步骤是用户检查方案的最后机会；跳过它剥夺了用户纠偏的权利 |
| "需求很简单，不需要完整的 plan.md" | 简单任务不需要重量级流程 | 简单任务走 `/go` 路由；用户选择了 `/plan` 就意味着需要完整产出 |
| "探索时顺手发现了一个 Bug，修一下没问题" | Bug 就应该修 | 规划阶段发现的 Bug 应写入 plan.md「边界与约定」，单独做需求；现在修 = 未计划的副作用 |
| "task.md 里隐含了这个改动" | 可以合理推断 | task.md 的步骤是字面意思，不存在「隐含改动」；有疑问应在第 4 步澄清 |
