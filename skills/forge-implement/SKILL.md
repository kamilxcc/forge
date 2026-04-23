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

### 第 4 步：逐步执行

**按计划步骤顺序执行，不可跳步，不可合并步骤**。

每步执行前：
1. 宣告「开始执行 Step N：<标题>」
2. Read 所有涉及文件（不依赖记忆）
3. 检查该步骤是否会触碰 KB 中的 CRITICAL 规则，若有，先说明处理方式

每步执行时：
1. 进行代码修改（Write / Edit）
2. 若该步骤涉及 Bash 命令（编译、运行测试），执行并检查结果
3. 若出现意外（文件结构与预期不符、新发现的依赖、编译报错），**不要沉默地绕开**：
   - 先说明发现了什么
   - 提出修正方案
   - 继续执行（小调整）或暂停询问用户（大偏差）

每步执行后：
按 `<plugin-root>/references/structured-step-output.md` 输出 Step N 摘要。

### 第 5 步：更新计划状态

每步完成后，将 `<plugin-root>/work/<project-name>/<dated-slug>/task.md` 中对应步骤的 `- [ ]` 改为 `- [x]`。

### 第 6 步：所有步骤完成后输出汇总

按 `<plugin-root>/references/structured-step-output.md` 中的"汇总格式"输出。

汇总必须包含：
- 变更文件列表（路径 + 变更类型 + 一句话说明）
- 关键决策汇总
- 已知风险/建议检查点
- 明确提示：「建议下一步：运行 `/review` 进行代码审查」

---

## 执行规范

### 代码质量约束

1. **遵循项目现有风格**：先 Read 同类文件，再模仿其命名、注释、错误处理风格
2. **不引入不必要的依赖**：新增 import 前先确认项目是否已有等价工具
3. **不修改计划范围外的代码**：发现顺手可改的东西，记录到汇总的"建议"节，不要直接改
4. **Bash 命令执行前必须说明目的**：不要静默执行可能有副作用的命令

### 遭遇 KB 约束时的处理

若执行过程中遭遇 KB 中 `level: critical` 的规则：

```
⚠️  触碰关键约束：<rule.alert>
    规则来源：<rule.id>（<rule.source>）
    
    计划处理方式：<你打算怎么做来满足这条约束>
    
    继续执行...
```

### 编译/测试失败的处理

若 Bash 执行返回非 0：

```
❌ Step N 执行遇到问题：<命令>

错误信息：
<error output>

分析：<是什么导致了这个错误>

修复方案：<打算怎么修复>

[尝试修复并重新执行]
```

最多尝试 2 次自动修复。仍失败则停止并向用户汇报：
```
🛑 Step N 遭遇阻塞，需要人工介入：
   <详细说明，包括已尝试的方案>
```

### 不做止损（MVP）

MVP 阶段不实现 4D 止损机制。若遇到超出能力边界的问题，直接停止并向用户说明。
