---
name: forge-clarify
description: >
  当需求不清晰、用户需要多轮对话厘清需求时触发，例如运行 /clarify、"把需求捋清楚"、"需求不够明确"。
  执行 9 步需求访谈和自查，生成 requirement.md。
  前置条件：必须在 .forge-kb/ 初始化完成后运行（缺 .forge-kb/ 时提示 /init-kb）。
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

### 第 0 步：前置检查

读取目标项目 `.forge-kb/meta/project.yaml`，若文件不存在，提示：

```
❌ 项目知识库未初始化。
   请先运行 /init-kb 创建知识库结构，再运行 /clarify。
```

停止执行。

### 第 1 步：加载知识库上下文

按 `<plugin-root>/references/knowledge-load-protocol.md` 执行 Always-On 层加载（meta/ 和 rules 文件）。

### 第 2 步：需求一句话总结

展示：

```
收到您的需求，我先理解一下。您需要的核心是：

「<提取用户输入的关键词，不超过 20 字>」

这样理解对吗？有没有需要补充或修正的地方？
```

等待用户确认，若需要修正，迭代此步。

### 第 3 步：边界划分

询问用户（调用 `AskUserQuestion`，规范见 `<plugin-root>/references/ask-user-question-protocol.md`）：

- `header`：「需求边界」
- `multiSelect: true`
- `options`（选多个）：
  - `label: <这个功能>` / `description: 这个功能需要做`
  - `label: 影响现有功能 X` / `description: 这个功能会影响现有功能 X，我需要了解具体影响`
  - `label: 新增用户界面` / `description: 这个功能需要新界面或改现有界面`
  - `label: 有后端依赖` / `description: 需要后端配合或新接口`

多个选项给用户多选，为后续「影响分析」做准备。

### 第 4 步：影响分析（按需）

若第 3 步用户选了「影响现有功能 X」或「新增用户界面」，用 Glob/Grep 快速探索，找到涉及的关键文件或模块，再问：

```
检测到这个需求可能涉及以下模块：
- <module1>
- <module2>

还有其他涉及的地方吗？
```

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
  - `label: 确认，开始方案设计` / `description: 内容无误，直接启动 /plan`
  - `label: 需要修改` / `description: 请在 Other 里说明需要改哪里`

若用户选择「需要修改」或在 Other 中输入反馈，更新对应节后重新执行第 7 步自查，再展示草稿确认，**最多修改 3 轮**。

若已修改 3 轮仍未通过确认，展示提示：

```
✋ 已修改 3 轮，建议暂时保存当前版本再手动编辑。
```

然后进入第 8 步写文档，或停止流程让用户决定。

### 第 8 步：确认后操作

用户选「确认，开始方案设计」后，询问（调用 `AskUserQuestion`）：

- `header`：「下一步」
- `multiSelect: false`
- `options`：
  - `label: 保存并自动开始方案设计` / `description: 将需求保存到磁盘，然后启动 /plan 生成技术方案`
  - `label: 仅保存需求文档` / `description: 保存需求文档到磁盘，稍后手动运行 /plan`

**若选「保存并自动开始方案设计」**：执行第 9 步，然后立即调用 `Skill("forge-plan")`。

**若选「仅保存需求文档」**：仅执行第 9 步，不调用 forge-plan。

### 第 9 步：写入需求文档

1. 确定 slug：`<verb>-<noun>` 格式，用 `-` 连接，如 `clear-channel-unread`
2. 读取目标项目 `.forge-kb/meta/project.yaml` 获取 `project.name` 作为 `<project-name>`
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
**下游**：`/plan` — 本 skill 若选「保存并自动开始方案设计」会自动调用 forge-plan

---

## 边界约定

- **不输出任何技术方案**（不出类名、不出接口设计、不出实现路径）：技术方案由 `/plan` 在代码探索后给出，此阶段给出方案会锚定后续设计，影响方案质量
- **「涉及模块」只写模块名和影响类型，不写具体类或方法**：类级别信息需要代码探索才准确，此阶段强行给出容易误导
- **需求文档写完后由用户决定是否自动启动 /plan**：需求文档是 `/plan` 和 `/implement` 的契约基础，用户在第 8 步明确选择是否继续进行方案设计，由用户控制流程

## 边缘情况

- 若用户需求含混不清，超过 3 轮修改仍无法精化，展示"保存当前版本并由用户手动编辑"选项，不强制继续
