---
name: forge
description: >
  Forge 编排层。处理 /go 万能入口和 /onboard 模块速览；所有其他命令由独立 skill 处理。
  当用户输入 /go <需求> 或 /onboard <模块>，或自然语言描述需求时触发。
  其余命令（/plan、/implement、/review、/test、/deposit、/init-kb、/update-kb）由对应 skill 直接处理，无需经过本 skill。
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
| `/deposit [描述]` | forge-deposit | 沉淀本次会话经验到知识库 |
| `/onboard <模块>` | forge（本文件）| 快速了解模块架构和历史坑点 |
| `/init-kb` | forge-kb | 初始化项目知识库 |
| `/update-kb [--since=7d]` | forge-kb | 增量更新知识库 |

---

## /go — 万能入口（task-router）

收到 `/go <需求>` 或自然语言需求描述时，**先判断路径，再执行**：

| 用户意图特征 | 路由路径 |
|-------------|---------|
| 新功能/需求描述，**需求模糊**（边界不清、可能有冲突、跨模块影响不明） | 调用 forge-clarify skill |
| 新功能/需求描述，**需求已清晰**（有 requirements/ 文档，或描述明确无歧义） | 调用 forge-plan skill |
| "帮我改一下 XX"（简单，单文件/单模块，需求清晰） | 直接执行编码（inline，相当于 forge-implement） |
| "帮我改一下 XX"（复杂，跨模块或影响接口） | 调用 forge-clarify skill |
| "review"、"检查"、"看一下代码" | 调用 forge-review skill |
| "写测试"、"test" | 调用 forge-test skill |
| "记录经验"、"沉淀" | 调用 forge-deposit skill |
| "初始化知识库" | 调用 forge-kb skill |

**需求清晰度判断规则**：
- 清晰 = 功能边界明确、改动集中、无需确认冲突或影响面
- 模糊 = 边界不清、描述含糊、可能与现有功能冲突、跨模块影响未知

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
