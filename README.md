# forge-plugin

**Forge** 是一个 Claude Code 插件，为大型项目提供知识库驱动的 AI 工程化工作流：

`/forge <需求>` → `/clarify`（可选）→ `/plan` → 用户确认 → `/implement` → `/review`

---

## 安装

在项目目录下启动 Claude Code 时，通过 `--plugin-dir` 指定本地插件路径：

```bash
claude --plugin-dir /Users/kamilxiao/code/forge-plugin
```

---

## 命令速查

| 命令 | 功能 |
|------|------|
| `/forge <需求>` | 万能入口，自动路由到合适的步骤 |
| `/clarify <需求>` | 多轮对话厘清需求，生成 requirement.md |
| `/plan [需求描述]` | 探索代码库，生成技术方案 + 执行计划 |
| `/implement` | 按计划逐步执行编码 |
| `/review` | 代码审查（DONE / DONE_WITH_CONCERNS / NEEDS_CONTEXT / BLOCKED） |
| `/test` | 生成并运行测试 |
| `/onboard <模块>` | 快速了解模块架构和历史坑点 |
| `/init-kb` | 初始化项目知识库 |
| `/update-kb [--since=7d]` | 增量更新知识库 |

---

## 工作流说明

### 完整流程（复杂需求）

```
/forge <需求>
  └→ /clarify   # 多轮对话，产出 requirement.md
  └→ /plan      # 探索代码，产出 plan.md + task.md
  └→ 用户确认
  └→ /implement # 按步骤执行，子 Agent 隔离上下文
  └→ /review    # 两阶段审查，子 Agent 执行
```

### 轻量流程（简单/清晰需求）

```
/forge <需求>  或  /plan <需求描述>
  └→ /plan      # 直接以描述为输入，跳过 /clarify
  └→ 用户确认
  └→ /implement
  └→ /review
```

### 路由规则

| 入口 | 简单需求 | 复杂需求 |
|------|---------|---------|
| `/forge X` | → /plan（内联描述） | 模糊 → /clarify；清晰 → /plan |
| 自然语言 | Claude 默认处理 | → forge 工作流 |

---

## 目录结构

```
forge-plugin/
├── skills/
│   ├── forge/                # /forge 路由入口 + /onboard
│   │   └── templates/kb/     # 目标项目 .forge-kb/ 初始化模板
│   ├── forge-clarify/        # /clarify：需求澄清，输出 requirement.md
│   ├── forge-plan/           # /plan：技术方案 + 执行计划
│   ├── forge-implement/      # /implement：编码执行（支持 Agent/inline 模式）
│   ├── forge-review/         # /review：代码审查
│   ├── forge-test/           # /test：测试生成
│   └── forge-kb/             # /init-kb + /update-kb：知识库管理
├── agents/
│   ├── forge-executor.md     # 编码执行子 Agent（由 /implement 派发）
│   └── forge-reviewer.md     # 代码审查子 Agent（由 /review 派发）
├── scripts/
│   ├── init-kb.sh            # 初始化目标项目知识库
│   └── kb-load.sh            # 知识库三级加载封装
├── references/
│   ├── knowledge-load-protocol.md   # 三级 KB 加载协议
│   ├── structured-step-output.md    # 执行步骤输出格式
│   └── execution-mode-protocol.md   # Agent/inline 模式选择协议
├── work/                     # 工作文档（gitignore，本地归档）
│   └── <project-name>/
│       ├── .current-feature  # 当前活跃 feature 指针
│       └── YYYY-MM-DD-<slug>/
│           ├── requirement.md
│           ├── plan.md
│           ├── task.md
│           └── review.md
└── hooks/_inactive/          # 暂存（经验飞轮功能后续启用）
    ├── post-tool-use.sh
    └── stop.sh
```

---

## 知识库结构（目标项目）

初始化后，目标项目根目录会生成 `.forge-kb/`：

```
.forge-kb/
├── meta/
│   ├── project.yaml      # 项目概述（Always-On，< 200 tokens）
│   └── glossary.yaml     # 产品/技术术语映射
├── modules/
│   └── <name>/
│       └── index.md      # 模块架构速览
└── experience/
    └── rules/
        └── <name>.yaml   # 经验规则（CRITICAL/WARN 级别）
```

---

## 设计原则

- **HARD-GATE**：`/plan` 产出必须经用户确认后才能进入 `/implement`，防止假设变事实
- **上下文隔离**：长任务派发子 Agent 执行，避免长对话漂移；父 session 负责交互，子 Agent 负责执行
- **三级 KB 加载**：Always-On（极小）/ Task-Scoped（按需）/ On-Demand（执行中按需读取），控制 token 成本
- **Scope Guard**：执行器每步对比计划声明的文件范围，超界改动必须先说明理由，不静默越界
