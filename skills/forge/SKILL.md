---
name: forge
description: >
  以下两种情况触发本 skill：
  1. 用户显式运行 /forge 命令。
  2. 用户用自然语言表达了需求，但没有指定用哪条工作流链路（不确定该 clarify 还是 plan 还是 review），
     例如"我有个需求想讨论一下"、"帮我看看该怎么处理这个问题"——
     注意：简单的局部改动（"把这个文字改成 X"、"改一下颜色"）不触发本 skill，交由 Claude 默认行为处理；
     用户明确说"出方案"、"规划怎么做"等意图清晰的话语，直接由 forge-plan skill 处理，不经过本 skill。
  本 skill 负责 /forge 路由；其余命令（/clarify /plan /implement /review /test）
  由各自独立的 skill 处理，不经过本 skill。
---

# Forge — 编排层

Forge 是面向大型项目的 AI 工程化插件，提供多能力协作框架。

<SUBAGENT-GUARD>
如果你是被主 Claude 派发的子 Agent，跳过本 Skill，直接执行分配给你的任务。
</SUBAGENT-GUARD>

## 命令速查

| 命令 | 对应 Skill | 功能 |
|------|-----------|------|
| `/forge <需求>` | forge（本文件）| 万能入口，自动路由 |
| `/clarify <需求>` | forge-clarify | 多轮对话厘清需求，生成需求文档 |
| `/plan` | forge-plan | 读取需求文档，生成技术方案 + 执行计划 |
| `/implement` | forge-implement | 按当前计划执行编码 |
| `/review` | forge-review | 代码审查，输出 DONE/DONE_WITH_CONCERNS/NEEDS_CONTEXT/BLOCKED |
| `/test` | forge-test | 生成并运行测试 |
---

## /forge — 万能入口（task-router）

### 第 0 步：判断入口类型

**命令入口**：用户显式输入了 `/forge <需求>`
**自然语言入口**：用户没有输入 slash 命令，由 description 匹配触发（此时进来的天然是复杂需求）

→ 两种入口的路由逻辑不同，见下方。

---

### 命令入口（`/forge`）路由

按以下路由执行：

| 情况 | 路由路径 |
|---------|---------|
| 需求描述（默认） | 调用 forge-clarify skill |
| "review"、"检查"、"看一下代码" | 调用 forge-review skill |
| "写测试"、"test" | 调用 forge-test skill |

> 所有需求（无论简单还是复杂）都先走 /clarify — 即使需求看起来清晰，/clarify 也能帮助确认边界、沉淀需求文档，再交给 /plan 执行。

---

### 自然语言入口路由

进入此入口时，需求天然已经过复杂度筛选（description 不匹配简单改动）。

直接路由到 forge-clarify skill。


