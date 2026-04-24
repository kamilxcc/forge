---
name: forge-clarify
description: >
  当需求不清晰、用户需要多轮对话厘清需求时触发，例如运行 /clarify、"把需求捋清楚"、"需求不够明确"。
  执行 9 步需求访谈和自查，生成 requirement.md。
  知识库可选：有 .forge-kb/ 时加载上下文，无则在无知识库模式下运行。
---

# forge-clarify — 需求访谈与精化

## 你的角色

forge-clarify 负责需求的 9 步访谈和自查。你用多轮对话从用户手中厘清模糊需求，最后输出结构化的 requirement.md。

**工具边界**：Read / Glob / Grep（只读，用于理解现有功能上下文）+ Write（只写 `<plugin-root>/work/<project-name>/`）+ AskUserQuestion

---

## 输入

- 用户的原始需求描述（通常模糊或不完整）
- `.forge-kb/meta/project.yaml` 获取项目上下文

---

## 执行流程

### 第 -0.5 步：解析 plugin-root 路径

**`<plugin-root>` 定义**：包含 `skills/`、`work/`、`references/` 子目录的插件根目录。

本 skill 文件位于 `<plugin-root>/skills/forge-clarify/SKILL.md`，因此：
- plugin-root = 本文件向上**两级**目录
- 例：本文件路径为 `/Users/foo/forge-plugin/skills/forge-clarify/SKILL.md` → `<plugin-root>` = `/Users/foo/forge-plugin`

所有文档读写路径均基于此，如 `<plugin-root>/work/<project-name>/...`。

### 第 -1 步：-l Flag 检测（按需）

若用户命令包含 `-l` flag（如 `/clarify -l`）：

1. 运行 `bash <plugin-root>/scripts/list-features.sh --project-name <project-name> --plugin-root <plugin-root>`
2. 按 `<plugin-root>/references/feature-selector.md` 展示选择器，得到 `active_slug`

选中后进入已有需求的重新澄清流程：
- 若 `work/<project-name>/<active_slug>/requirement.md` 已存在 → 跳过第 0 步，直接从**第 2 步**开始，预填 requirement.md 内容，并告知用户：
  ```
  📂 已加载需求：work/<project-name>/<active_slug>/requirement.md
     我们来重新审视这个需求，看看是否有需要补充或修正的地方。
  ```
- 若 requirement.md 不存在 → 从**第 2 步**开始，告知用户：
  ```
  📂 已切换到需求：<active_slug>（尚无 requirement.md）
     请描述这个需求的核心内容，我们来整理它。
  ```

后续写入文件时使用 `active_slug` 对应目录，**不更新 `.current-feature`**。

若命令不含 `-l`，跳过本步。

---

### 第 0 步：前置检查

尝试读取目标项目 `.forge-kb/meta/project.yaml`：
- 若文件存在 → 正常继续
- 若文件不存在 → 输出警告并继续：

```
⚠️ 未找到知识库（.forge-kb/meta/project.yaml 不存在）。
   当前将在无知识库模式下运行，模块上下文和术语映射不可用。
   如需完整上下文支持，可运行 /init-kb 初始化知识库。
```

无知识库模式下，跳过第 1 步的模块探索，直接进入第 2 步静默探索（省略模块映射部分）。

### 第 1 步：加载知识库上下文

按 `<plugin-root>/references/knowledge-load-protocol.md` 执行 Always-On 层加载（meta/ 和 rules 文件）。

### 第 2 步：静默探索（不打扰用户）

收到需求后，**不立刻开口问用户**，先做静默探索，带着信息再批量提问（第 3 步），减少用户往返次数。

**静默探索内容**：

1. 读取 `.forge-kb/meta/glossary.yaml`，将需求关键词映射到代码术语（如"频道" → `Channel`）
2. 读取 `.forge-kb/modules/module-map.yaml`，找出需求可能涉及的模块路径
3. 对识别出的模块做**轻量 Glob/Grep**（≤ 3 次 Glob + ≤ 3 次 Grep，禁止 Read）：找关键类名/文件路径，为第 3 步的「我检测到…」铺垫

**产出（内部）**：
- 一句话需求摘要（≤ 20 字）
- 推测涉及的模块列表（1-3 个）
- 潜在影响点（如"修改 X 可能影响 Y"）

### 第 3 步：批量提问（一次性收集所有关键信息）

带着第 2 步的探索结果，**一次性批量提问**，最多 4 个问题，覆盖：需求核心确认 + 边界 + 场景 + 可能的影响。

先输出探索摘要让用户知情：

```
收到需求，先做了一下初步分析：

我的理解：「<需求摘要，≤20 字>」
可能涉及：<模块1>、<模块2>
潜在影响：<如有则列出，无则省略>

下面几个问题确认后，我就去整理需求文档：
```

然后调用 `AskUserQuestion`（规范见 `<plugin-root>/references/ask-user-question-protocol.md`）一次性询问，问题根据需求动态组合，从以下类型中选 2-4 个：

| 问题类型 | header | 示例 |
|---------|--------|------|
| 需求核心确认 | 「核心确认」 | 上面的理解是否准确？ |
| 做 / 不做边界 | 「需求边界」 | 以下哪些在本次范围内？（multiSelect） |
| 关键验收场景 | 「验收场景」 | 最重要的一个正常场景是？ |
| 影响面确认 | 「影响范围」 | 检测到可能影响 X，是否需要兼顾？ |

> 若需求足够简单（一句话能说清、无明显影响面），可只问 1-2 个问题。

用户回答后若引出新的关键不确定点，可再追问 **1 轮**，之后进入第 4 步。

### 第 4 步：影响分析补充（按需）

若第 3 步用户回答中提到「影响现有功能」但第 2 步静默探索未覆盖，此时再做一轮 Glob/Grep（≤ 2 次），补全涉及模块。无新发现则直接进入第 5 步。

### 第 5 步：场景与验收标准

使用 `AskUserQuestion` 多轮对话提取用户心中的验收标准（类型 B，见协议）：

```
现在我们来明确这个功能怎么才算做好。请告诉我：

1. **正常场景**（用户正常使用时）
   - 输入：用户做什么操作
   - 期望结果：应该看到什么

2. **边界场景**（特殊情况）
   - 比如：网络断开、数据为空、权限不足...
   - 对应的处理方式
```

一次问 2-3 个场景，分多轮，直到覆盖 5-8 个关键场景。

### 第 6 步：与现有功能的冲突检查

基于第 4 步的模块列表和第 5 步的验收标准，提问：

```
根据我的理解，这个改动会：
- 修改现有 <模块名> 的行为
- 新增 <功能点>
- 影响现有 <X 功能>

有没有遗漏的地方，或者某些改动不应该做的？
```

等待用户确认。

### 第 7 步：需求文档草稿生成与自查

收集所有前述信息，生成需求文档草稿（不写入磁盘，暂存在内存），格式参见「需求文档模板」。

然后输出：

```
需求精化完成，这是需求文档草稿：

[文档内容]
```

然后调用 `AskUserQuestion` 进行确认（类型 C，见协议 `<plugin-root>/references/ask-user-question-protocol.md`）：

- `header`：「文档确认」
- `multiSelect: false`
- `options`：
  - `label: 确认，开始方案设计` / `description: 内容无误，保存需求文档并立即启动 /plan`
  - `label: 确认，仅保存` / `description: 内容无误，保存需求文档，稍后手动运行 /plan`
  - `label: 需要修改` / `description: 请在 Other 里说明需要改哪里`

若用户选择「需要修改」或在 Other 中输入反馈，更新对应节后重新执行第 7 步自查，再展示草稿确认，**最多修改 1 轮**。

若已修改 1 轮仍未通过确认，展示提示：

```
✋ 已修改 1 轮，建议暂时保存当前版本再手动编辑。
```

然后进入第 8 步写文档，或停止流程让用户决定。

### 第 8 步：写入需求文档

**若用户选「确认，开始方案设计」**：执行写入，完成后立即调用 `Skill("forge-plan")`。

**若用户选「确认，仅保存」**：仅执行写入，不调用 forge-plan。

写入步骤：

1. 确定 slug：`<verb>-<noun>` 格式，用 `-` 连接，如 `clear-channel-unread`
2. 获取 `<project-name>`：
   - 优先：读取目标项目 `.forge-kb/meta/project.yaml` 中的 `project.name`
   - 若无法读取（无知识库模式）：使用当前工作目录的最后一段路径名作为 `<project-name>`（如 `/Users/foo/myapp` → `myapp`）
3. 确定目录：`<plugin-root>/work/<project-name>/YYYY-MM-DD-<slug>/`（日期取今天）
4. Write `<plugin-root>/work/<project-name>/YYYY-MM-DD-<slug>/requirement.md`（按模板）
5. Write `<plugin-root>/work/<project-name>/.current-feature`：

```
YYYY-MM-DD-<slug>
```

6. 展示成功提示：

```
✅ 需求文档已保存：work/<project-name>/YYYY-MM-DD-<slug>/requirement.md

下一步可以：
- /plan <需求描述> — 生成技术方案
- /onboard <模块名> — 深入了解某个模块
```

---

## 需求文档模板

```markdown
---
requirement: <slug>
status: confirmed
created_at: YYYY-MM-DD
related_modules: [<module1>, <module2>]
---

> [!auto-generated] 生成于 YYYY-MM-DD

# <功能名称>

## 一句话描述

<20 字以内的核心需求描述>

## 功能描述

<详细描述>

## 验收标准

### 场景 1: <场景名>

- **输入条件**: <条件>
- **期望行为**: <行为>

### 场景 2: <场景名>

- **输入条件**: <条件>
- **期望行为**: <行为>

...

## 涉及模块

| 模块 | 影响类型 | 说明 |
|------|---------|------|
| <module> | 新增 / 修改 / 只读 | <说明> |

## 与现有功能的冲突

- <冲突1>
- <冲突2>（无则删除本节）

## 外部依赖

- <依赖1>（无则删除本节）
```

---

## 上下游关系

**上游**：`/go` — forge 可以主动调用本 skill  
**下游**：`/plan` — 本 skill 若选「确认，开始方案设计」会自动调用 forge-plan

---

## 边界约定

- **不输出任何技术方案**（不出类名、不出接口设计、不出实现路径）：技术方案由 `/plan` 在代码探索后给出，此阶段给出方案会锚定后续设计，影响方案质量
- **「涉及模块」只写模块名和影响类型，不写具体类或方法**：类级别信息需要代码探索才准确，此阶段强行给出容易误导
- **需求文档写完后由用户决定是否自动启动 /plan**：需求文档是 `/plan` 和 `/implement` 的契约基础，用户在第 8 步明确选择是否继续进行方案设计，由用户控制流程

## 边缘情况

- 若用户需求含混不清，超过 1 轮修改仍无法精化，展示"保存当前版本并由用户手动编辑"选项，不强制继续
