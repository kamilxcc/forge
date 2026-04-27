# forge-plugin

**Forge** 是一个 Claude Code 插件，为大型项目提供结构化的 AI 工程化工作流：

`/forge <需求>` → `/clarify`（可选）→ `/plan` → 用户确认 → `/implement` → `/review`

---

## 安装

```bash
# 第一步：添加 marketplace（只需执行一次）
claude plugin marketplace add kamilxcc/forge

# 第二步：安装插件
claude plugin install forge@forge
```

安装后重启 Claude Code 生效。

### 更新

```bash
claude plugin update forge
```

---

## 命令速查

| 命令 | 功能 |
|------|------|
| `/forge <需求>` | 万能入口，自动路由到合适的步骤 |
| `/clarify <需求>` | 多轮对话厘清需求，生成 requirement.md |
| `/plan [需求描述]` | 探索代码库，生成技术方案 + 执行计划 |
| `/implement` | 按计划逐步执行编码 |
| `/review` | 代码审查（PASS/WARN/BLOCK） |
| `/test` | 生成并运行测试 |

---

## 工作流说明

### 完整流程（复杂需求）

```
/forge <需求>
  └→ /clarify   # 多轮对话，产出 requirement.md
  └→ /plan      # 探索代码，产出 plan.md + task.md
  └→ 用户确认    # HARD-GATE：必须确认后才进入编码
  └→ /implement # 按步骤执行，支持 inline/Agent 两种模式
  └→ /review    # 代码审查
```

### 轻量流程（简单/清晰需求）

```
/plan <需求描述>
  └→ 直接以描述为输入，跳过 /clarify
  └→ 用户确认
  └→ /implement
  └→ /review
```

---

## 目录结构

```
forge-plugin/
├── skills/
│   ├── forge/                 # /forge 路由入口
│   ├── forge-clarify/         # /clarify：需求澄清，输出 requirement.md
│   ├── forge-plan/            # /plan：技术方案 + 执行计划
│   ├── forge-implement/       # /implement：编码执行（支持 Agent/inline 模式）
│   ├── forge-review/          # /review：代码审查
│   ├── forge-test/            # /test：测试生成
│   └── _inactive/             # 暂存的 skill（未激活）
├── agents/
│   ├── forge-executor.md      # 编码执行子 Agent（由 /implement 派发）
│   └── forge-reviewer.md      # 代码审查子 Agent（由 /review 派发）
├── references/                # 所有 skill 共用的协议和模板
│   ├── execution-core-protocol.md    # 编码执行公共协议（inline/Agent 共用）
│   ├── execution-mode-protocol.md    # Agent/inline 模式选择阈值
│   ├── structured-step-output.md     # 执行步骤输出格式
│   ├── plan-template.md              # plan.md 文档模板
│   ├── task-template.md              # task.md 文档模板
│   ├── plan-guardrails.md            # 规划阶段护栏（陷阱 + 防合理化）
│   ├── implement-guardrails.md       # 执行阶段护栏（防合理化）
│   └── ask-user-question-protocol.md # AskUserQuestion 调用规范
├── scripts/
│   └── validate-task.sh       # task.md 格式校验脚本
├── work/                      # 工作文档（按项目+日期+slug 归档）
│   └── <project-name>/
│       ├── .current-feature   # 当前活跃 feature 指针
│       └── YYYY-MM-DD-<slug>/
│           ├── requirement.md # /clarify 产出
│           ├── plan.md        # /plan 产出：方案文档
│           ├── task.md        # /plan 产出：执行计划
│           └── review.md      # /review 产出
└── hooks/_inactive/           # 暂存（经验飞轮功能后续启用）
```

---

## 设计原则

### 只补 Claude Code 不会自发做的事

Skill 不教 Claude 怎么搜索代码（它比手写流程做得更好），而是补充它不会自发做的：

- **思维框架**：探索面声明（先列维度再搜索）、完成度检查（逐维度审计覆盖情况）、不确定点分类（七类，区分可自推断 vs 需用户确认）
- **产出标准**：参考锚点（绝对路径 + 行号 + 参考实现）、task.md 内联代码（executor 不需要额外 Read）
- **行为护栏**：HARD-GATE（plan 必须用户确认）、Scope Guard（执行不越界）、防合理化表（针对实际出现过的绕过行为）

### HARD-GATE

`/plan` 产出必须经用户确认后才能进入 `/implement`，防止假设变事实。

### 上下文隔离

长任务（≥ 4 步）派发子 Agent（forge-executor）执行，避免长对话上下文漂移；父 session 负责用户交互，子 Agent 负责编码执行。

### Scope Guard

执行器每步对比计划声明的文件范围，超界改动必须先说明理由并记录偏差，不静默越界。

### 断点续传

task.md 用 `[ ]` / `[x]` 标记步骤进度。中断后重新 `/implement`，自动检测已完成步骤，从断点继续。
