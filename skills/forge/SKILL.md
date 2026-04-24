---
name: forge
description: >
  以下两种情况触发本 skill：
  1. 用户显式运行 /forge、/onboard 命令。
  2. 用户用自然语言描述了较复杂的需求，例如"帮我想想怎么做 X"、"这个功能该怎么规划"、"我有个需求想讨论一下"、"如何实现 X 的架构"——
     注意：简单的局部改动（"把这个文字改成 X"、"改一下颜色"）不触发本 skill，交由 Claude 默认行为处理。
  本 skill 负责 /forge 路由和 /onboard 模块速览；其余命令（/clarify /plan /implement /review /test /init-kb /update-kb）
  由各自独立的 skill 处理，不经过本 skill。
---

# Forge — 编排层

Forge 是面向大型项目的 AI 工程化插件，提供知识库驱动的多能力协作框架。

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
| `/onboard <模块>` | forge（本文件）| 快速了解模块架构和历史坑点 |

> **`-l` Flag（所有命令通用）**：在任意命令后加 `-l` 可列出当前项目所有需求，选择后本次命令针对该需求执行，不影响 `.current-feature` 指针。
> 示例：`/plan -l`、`/implement -l`、`/review -l`

---

## /forge — 万能入口（task-router）

### 第 0 步：判断入口类型

**命令入口**：用户显式输入了 `/forge <需求>`
**自然语言入口**：用户没有输入 slash 命令，由 description 匹配触发（此时进来的天然是复杂需求）

→ 两种入口的路由逻辑不同，见下方。

---

### 命令入口（`/forge`）路由

加载知识库（见下方「知识库加载」节）后，按以下路由执行：

| 情况 | 路由路径 |
|---------|---------|
| 需求描述（默认） | 调用 forge-clarify skill |
| "review"、"检查"、"看一下代码" | 调用 forge-review skill |
| "写测试"、"test" | 调用 forge-test skill |

> 所有需求（无论简单还是复杂）都先走 /clarify — 即使需求看起来清晰，/clarify 也能帮助确认边界、沉淀需求文档，再交给 /plan 执行。

---

### 自然语言入口路由

进入此入口时，需求天然已经过复杂度筛选（description 不匹配简单改动）。

加载知识库后，直接路由到 forge-clarify skill。

---

## /onboard — 模块快速了解

**直接在当前会话执行**（无独立 skill）：

1. 检查 `.forge-kb/modules/<name>/index.md` 是否存在
   - 存在 → Read 并加载内容
   - 不存在 → 提示"该模块尚无知识库记录"
2. 汇总展示：概述 + 核心架构 + 关键入口类 + 黑话 + 历史坑点 + 近期变更

