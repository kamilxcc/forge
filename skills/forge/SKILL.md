---
name: forge
description: >
  You MUST use this skill when the user describes a feature request, bug fix, or any functional
  change — e.g. "我想做 X"、"帮我加 X"、"改一下 X"、"我需要 X"、"实现 X"。
  Forge 编排层。处理 /go 万能入口和 /onboard 模块速览；所有其他命令由独立 skill 处理。
  其余命令（/clarify、/plan、/implement、/review、/test、/init-kb、/update-kb）由对应 skill 直接处理，无需经过本 skill。
---

# Forge — 编排层

Forge 是面向大型项目的 AI 工程化插件，提供知识库驱动的多能力协作框架。

<SUBAGENT-GUARD>
如果你是被主 Claude 派发的子 Agent，跳过本 Skill，直接执行分配给你的任务。
</SUBAGENT-GUARD>

## 命令速查

| 命令 | 对应 Skill | 功能 |
|------|-----------|------|
| `/go <需求>` | forge（本文件）| 万能入口，自动路由 |
| `/clarify <需求>` | forge-clarify | 多轮对话厘清需求，生成需求文档 |
| `/plan` | forge-plan | 读取需求文档，生成技术方案 + 执行计划 |
| `/implement` | forge-implement | 按当前计划执行编码 |
| `/review` | forge-review | 代码审查，输出 PASS/WARN/BLOCK |
| `/test` | forge-test | 生成并运行测试 |
| `/onboard <模块>` | forge（本文件）| 快速了解模块架构和历史坑点 |
| `/init-kb` | forge-kb | 初始化项目知识库 |
| `/update-kb [--since=7d]` | forge-kb | 增量更新知识库 |

---

## /go — 万能入口（task-router）

收到 `/go <需求>` 或自然语言需求描述时，**先做快速评估，再路由**：

### 第 1 步：快速评估（必须先于路由）

加载知识库（见下方「知识库加载」节）后，用 Glob/Grep 快速浏览涉及文件（**不超过 5 个文件，不超过 60 秒**），判断复杂度：

**简单** = 同时满足以下三条：
1. 改动集中在 1-2 个文件
2. 不涉及公共接口、跨模块调用、现有行为变更
3. 意图明确，无歧义

**复杂** = 满足任意一条：
- 涉及 3+ 个文件，或跨模块
- 可能改动公共接口或影响其他调用方
- 需求描述有歧义或边界不清

### 第 2 步：路由

| 评估结果 | 路由路径 |
|---------|---------|
| **简单** | 输出一句话方案，调用 `AskUserQuestion` 询问「直接做」还是「走完整流程」 |
| **复杂 + 需求模糊** | 调用 forge-clarify skill |
| **复杂 + 需求清晰**（有 requirement.md 或描述无歧义） | 调用 forge-plan skill |
| "review"、"检查"、"看一下代码" | 调用 forge-review skill |
| "写测试"、"test" | 调用 forge-test skill |
| "初始化知识库" | 调用 forge-kb skill |

**简单路径的 AskUserQuestion 格式**：

```
我看了一下，这个改动比较简单：<一句话描述改动范围>

建议直接做：<具体做法一句话>
```

然后调用 AskUserQuestion：
- `header`：「执行方式」
- `multiSelect: false`
- options：
  - `label: 直接做` / `description: 按上述方案立即执行`
  - `label: 走完整流程` / `description: 经过 /clarify → /plan 再执行`

---

## /onboard — 模块快速了解

**直接在当前会话执行**（无独立 skill）：

1. 检查 `.forge-kb/modules/<name>/index.md` 是否存在
   - 存在 → Read 并加载内容
   - 不存在 → 提示"该模块尚无知识库记录，可运行 `/update-kb` 生成"
2. 加载对应的 `experience/rules/*.yaml` 中 `module` 字段匹配的规则
3. 汇总展示：概述 + 核心架构 + 关键入口类 + 黑话 + 历史坑点 + 近期变更

---

## 知识库加载（/go 和 /onboard 执行前）

```
1. 检查项目根目录是否存在 .forge-kb/
   - 存在 → 继续加载
   - 不存在 → 提示"未找到知识库，运行 /init-kb 初始化"，然后继续任务

2. 加载 Always On：
   - .forge-kb/meta/project.yaml
   - .forge-kb/meta/glossary.yaml

3. 加载 Task Scoped（按需）：
   - 根据任务描述推断涉及模块
   - 加载对应 modules/<name>/index.md
   - 扫描 experience/rules/*.yaml，加载 keywords 匹配当前任务的规则
```

加载逻辑由 `<plugin-root>/scripts/kb-load.sh` 封装。
完整三级加载协议见 `<plugin-root>/references/knowledge-load-protocol.md`。
