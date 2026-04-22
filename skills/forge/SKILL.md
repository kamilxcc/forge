---
name: forge
description: >
  Forge — AI 工程化插件。处理所有研发任务：新需求、编码、Review、测试、知识库管理、经验沉淀。
  用户说需求时自动路由；命令：/go、/plan、/implement、/review、/test、/deposit、/onboard、/init-kb、/update-kb。
  当用户描述功能需求、要求改代码、要求 review、要求写测试、要求了解模块、或使用上述任何命令时触发。
---

# Forge

Forge 是面向大型项目的 AI 工程化插件，提供知识库驱动的多 Agent 协作框架。

<SUBAGENT-GUARD>
如果你是被主 Claude 派发的子 Agent，跳过本 Skill，直接执行分配给你的任务。
</SUBAGENT-GUARD>

## 快速参考

| 命令 | 功能 |
|------|------|
| `/go <需求>` | 万能入口，自动路由到最合适的路径 |
| `/plan <需求>` | 生成 Feature 文档 + 执行计划 |
| `/implement` | 按当前计划执行编码 |
| `/review [files\|branch]` | 代码审查，输出 PASS/WARN/BLOCK |
| `/test [scope]` | 生成并运行测试 |
| `/deposit [描述]` | 沉淀本次会话经验到知识库 |
| `/onboard <模块>` | 快速了解模块架构和历史坑点 |
| `/init-kb` | 初始化项目知识库（首次使用） |
| `/update-kb [--since=7d]` | 增量更新知识库 |

---

## task-router：自动路由逻辑

收到用户请求后，**先判断路径，再执行**：

| 用户意图特征 | 路由路径 |
|-------------|---------|
| 新功能/需求描述，涉及多模块或设计 | `planner → 用户确认 → implementer` |
| "帮我改一下 XX"（简单，单文件/单模块） | 直接 `implementer --inline` |
| "帮我改一下 XX"（复杂，跨模块或影响接口） | `planner → implementer` |
| "review"、"检查"、"看一下代码" | `reviewer` |
| "写测试"、"test" | `test-writer` |
| "这个模块怎么工作的"、"介绍一下 XX" | `onboard`（knowledge-loader 直出）|
| "记录经验"、"沉淀"、`/deposit` | `depositor` |
| "初始化知识库"、`/init-kb` | `kb-builder` |

**复杂度判断规则**：
- 简单 = 改动集中在 1 个文件或 1 个类，需求描述清晰，无需设计决策
- 复杂 = 涉及多文件、新增接口、跨模块协作、或需求模糊需要澄清

---

## 知识库加载（每次任务开始时执行）

在执行任何任务前，先加载知识库上下文：

```
1. 检查项目根目录是否存在 .forge-kb/
   - 存在 → 继续加载
   - 不存在 → 提示"未找到知识库，运行 /init-kb 初始化"，然后继续任务（无知识库也能工作）

2. 加载 Always On（始终加载）：
   - .forge-kb/meta/project.yaml（项目概览）
   - .forge-kb/meta/glossary.yaml（术语表）

3. 加载 Task Scoped（按任务加载）：
   - 根据任务描述，用 module-resolver 推断涉及模块
   - 加载对应模块的 modules/<name>/index.md
   - 扫描 experience/rules/*.yaml，加载 keywords 匹配当前任务的规则

4. On Demand（Agent 执行中按需 Read）：
   - 模块子域文件（tab-system.md 等）
   - experience/cases/ 具体案例
```

---

## /plan — 需求规划

调用 planner Agent（Read-only）：

**输入**：用户需求描述  
**产物**：
1. `features/<feature-name>.md` — Feature 文档（长期留存）
2. `.forge-kb/.state/current-task.md` — 执行计划（可废弃）

Feature 文档结构：
```
# <功能名>
## 需求背景
## 需求描述
## 涉及模块
## 设计决策（记录 why，不只是 what）
## 实现步骤
## 边界与约定
## 待确认项
```

**完成后**：展示 Feature 文档 + 执行计划，等待用户确认。
**用户确认后**：可执行 `/implement`。

<HARD-GATE>
YOU MUST NOT 开始编码，直到用户明确确认计划。
</HARD-GATE>

---

## /implement — 执行编码

**前置条件**：存在已确认的 `.forge-kb/.state/current-task.md`

**模式选择**（根据计划步骤数自动建议）：
- 计划 ≤ 3 步 → 建议 `--inline`（当前会话直接执行）
- 计划 > 3 步 → 建议 `--agent`（fork 子 Agent，上下文隔离）

调用 implementer Agent（完整读写权限）。

详细行为见 `references/agent-prompts/implementer.md`。

---

## /review — 代码审查

调用 reviewer Agent（Read-only，无 Bash）。

**输入**：files（默认为 git diff HEAD）或 branch  
**输出**：结构化三态判定 PASS / WARN / BLOCK

BLOCK 时自动触发定向返修（最多 1 轮），返修后仍 BLOCK → 止损，交用户决策。

详细行为见 `references/agent-prompts/reviewer.md`。

---

## /deposit — 经验沉淀

调用 depositor Agent（只写 .forge-kb/ 目录）。

**触发方式**：
- 用户主动 `/deposit [描述]`
- Stop Hook 提示后用户确认

**流程**：
1. 扫描本次会话修改的文件（来自 PostToolUse Hook 记录的 `.forge-kb/.state/modified-files.txt`）
2. 分析修改内容，识别可沉淀的经验信号
3. 预填经验条目，等待用户一键确认或编辑
4. 写入 `.forge-kb/experience/rules/` 或 `cases/`

---

## /onboard — 模块快速了解

**不调用独立 Agent**，直接由主 Claude 执行：

1. 加载 `.forge-kb/modules/<name>/index.md`
2. 加载关联的 experience/rules（匹配该模块的规则）
3. 汇总展示：概述 + 核心架构 + 关键入口类 + 黑话 + 历史坑点 + 近期变更

---

## /init-kb — 初始化知识库

运行 `skills/forge/scripts/init-kb.sh`，在当前项目根目录创建 `.forge-kb/` 结构。

详见 `scripts/init-kb.sh`。

---

## /update-kb — 增量更新

调用 kb-builder Agent：
1. `git diff --name-only HEAD~N`（N 由 `--since` 参数推算）
2. module-resolver 推断受影响模块
3. 展示需要更新的知识库文件列表
4. 用户确认后执行更新
