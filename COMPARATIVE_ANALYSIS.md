# Forge Plugin vs Franco: AI 工程化架构深度对比分析

**生成日期**: 2026-04-24  
**对比版本**: Forge Plugin (main) vs Franco v2.0

---

## 目录

1. [执行摘要](#执行摘要)
2. [项目定位](#项目定位)
3. [核心架构差异](#核心架构差异)
4. [知识库管理策略](#知识库管理策略)
5. [工作流对比](#工作流对比)
6. [设计决策理由](#设计决策理由)
7. [代码探索机制](#代码探索机制)
8. [质量保障机制](#质量保障机制)
9. [相似性与差异矩阵](#相似性与差异矩阵)
10. [行业基准对比](#行业基准对比)
11. [融合架构建议](#融合架构建议)

---

## 执行摘要

### 维度对比表

| 维度 | Forge Plugin | Franco v2.0 |
|------|-------------|-----------|
| **架构定位** | 通用工程框架 | 团队专有工程化系统 |
| **编排方式** | 路由式（命令→技能） | 配置式（流程→配置） |
| **约束层级** | Prompt + 协议 | L1-L4（硬约束→提示词） |
| **上下文管理** | 优化加载（Token省） | 物理隔离（独立窗口） |
| **Sub-Agent个数** | 按需分配 | 固定9个专业角色 |
| **知识库模式** | 通用模板 | AIGC蒸馏+人工审核 |
| **文件交接方式** | 内存共享 + 工作目录 | 磁盘文件交接 |
| **配置驱动程度** | 中等（SKILL.md） | 高（flows/ + state.json） |
| **状态持久化** | 隐式（工作目录） | 显式（state.json） |
| **流程灵活性** | 高（运行时路由） | 中（预定义流程） |

### 核心特征对比

**Forge Plugin**
- ✅ 通用性强，适配任意项目
- ✅ Token优化，Knowledge-library驱动
- ✅ 灵活的运行时路由
- ⚠️  需要user确认每个阶段转换
- ⚠️  上下文可能截断

**Franco v2.0**
- ✅ 结构约束严格，防超权
- ✅ 流程清晰可追踪
- ✅ 独立Sub-Agent隔离噪音
- ⚠️  初始化配置复杂
- ⚠️  扩展需要修改flows

---

## 项目定位

### Forge Plugin 的定位

**类型**: Claude Code 通用插件  
**目标用户**: 所有大型项目开发者  
**部署模式**: 目标项目内 + `.forge-kb/` 知识库（独立维护）  

**核心价值**:
1. **知识库驱动** — 利用 `.forge-kb/` 为每个目标项目定制规则库
2. **Token经济学** — 三级加载协议(Always On / Task Scoped / On Demand)最小化上下文
3. **灵活编排** — 运行时路由，支持 `-l` flag 选择需求
4. **开箱即用** — `/init-kb` 快速初始化目标项目

**适用场景**:
- 大型项目（≥20 modules）
- 团队需要标准化工程流程
- 知识库维护成本可控

---

### Franco v2.0 的定位

**类型**: QQGYBiz 团队自研 AI 开发工程师  
**目标用户**: QQGYBiz 内部 + 关联项目  
**部署模式**: CodeBuddy 平台（基于 Claude） + 项目仓库集成  

**核心价值**:
1. **Harness四层约束** — 用结构替代 Prompt，工程级的reliability
2. **流程即配置** — `flows/` 目录，每个流程独立可编辑
3. **专业角色层** — 9个 Sub-Agent，各司其职
4. **AIGC知识蒸馏** — 从项目文档自动生成AI可消费的结构化KB

**适用场景**:
- 团队规模稳定（20-50人）
- 流程复杂度高（多轮CR、严格SDD）
- 知识库维护成本投入大

---

## 核心架构差异

### 维度1: 编排模式

#### Forge Plugin — 轻量路由式

```
user input
    ↓
/forge (orchestrator)
    ├→ /clarify (需求澄清)
    ├→ /plan (技术方案)
    ├→ /implement (按计划编码)
    ├→ /review (代码审查)
    ├→ /test (生成测试)
    └→ /init-kb / /update-kb (知识库)
    
特点: 命令驱动，每个skill独立路由
```

**实现方式**:
- 单个 `forge/SKILL.md` 在 Step 0 判断入口类型
- 按情况调用对应 skill
- 各 skill 独立加载知识库，self-contained

**设计原则**:
- **Routing is cheap** — 由 LLM 做判断，编排层极简
- **Skills are first-class** — 每个skill是完整能力单位
- **Knowledge-scoped** — 在知识库维度做加载优化，不在编排维度做

---

#### Franco v2.0 — 流程配置式

```
user input (+TAPD ID / +描述)
    ↓
lightweight orchestrator (轻量编排层)
    ├→ read state.json & flows/
    ├→ route to appropriate flow
    │   ├→ init-wizard.flow
    │   ├→ story-dev.flow (7-stage)
    │   ├→ bug-fix.flow
    │   ├→ demo-quick-dev.flow
    │   └→ checkpoint-resume.flow
    ↓
dispatch Sub-Agent (专业执行层)
    ├→ Demo分析师 + Demo开发工程师
    ├→ 需求分析师
    ├→ 技术方案设计师
    ├→ 功能开发工程师
    ├→ 代码审查工程师
    ├→ BUG修复工程师
    ├→ 迭代追加工程师
    └→ 断点续传工程师

特点: 流程驱动，显式路由规则，固定Sub-Agent体系
```

**实现方式**:
- `flows/` 目录存储所有流程定义（`.flow` 文件）
- `state.json` 全局状态，支持断点续传
- 轻量编排层读 state → 选 flow → dispatch Sub-Agent
- 每个 Sub-Agent 有独立上下文窗口

**设计原则**:
- **Explicit routing** — 14条精确路由规则，无歧义
- **Flow-first** — 流程是一等公民，配置优先
- **Context isolation** — 物理隔离Sub-Agent上下文

---

### 维度2: 约束机制

#### Forge Plugin — 协议式约束

```
L1 Workflow Protocol (HARD-GATE)
  └─ /plan 必须 HARD-GATE，user 显式确认后才能进 /implement
  └─ 每个 phase transition 都需要 user 确认

L2 Schema Constraints (references/)
  └─ knowledge-load-protocol.md — 三级加载
  └─ structured-step-output.md — 每步输出格式
  └─ execution-mode-protocol.md — inline vs agent 模式选择

L3 Tool Budget
  ├─ forge-clarify: Read/Write 仅限 work/
  ├─ forge-plan: Read-only + Write work/
  ├─ forge-implement: Full read/write
  └─ forge-review: Read-only（无 Bash）

L4 Prompt Guidance
  └─ 每个 SKILL.md 中的 anti-rationalization 表
  └─ "防合理化"检查清单
```

**约束特点**:
- 软约束为主（Prompt引导）
- 依赖 Claude 的自律执行
- 通过文档规范化行为
- 可通过修改 Prompt 调整

---

#### Franco v2.0 — Harness四层约束

```
L1 硬约束 (结构上无法逾越)
  ├─ 工具白名单（严格工具权限）
  ├─ 物理上下文隔离（Sub-Agent独立窗口）
  ├─ 强制构建闸门（每次改动后必须 ./build.sh）
  └─ 搜索配额限制（Specify ≤5轮，Plan ≤5轮，Diagnose ≤6轮）

L2 Schema约束 (数据/文件格式强制)
  ├─ state.json 结构强制
  ├─ flows/ 文件格式标准
  ├─ .ai/<id>/ 目录规范
  └─ CR 分级处理（must/should/ignore/manual）

L3 流程约束 (强制执行顺序)
  ├─ SDD三段：规范→Review规范→代码
  ├─ 先构建后CR
  ├─ 修复轮次≤3（超限立即报告）
  └─ 断点续传机制

L4 Prompt约束 (提示词引导)
  └─ 搜索配额提醒，禁止操作提醒，分级CR规则
```

**约束特点**:
- 硬约束为主（结构强制）
- 用工程手段替代自律
- L1-L2 物理不可能逾越
- L3-L4 逻辑上保证流程正确

---

### 维度3: 上下文管理

#### Forge Plugin — 优化加载策略

**目标**: 最小化 token 消耗，同时保持完整信息

**实现**:
```
阶段1: Always On (固定 ~200 tokens)
  ├─ project.yaml (meta 信息)
  └─ glossary.yaml (产品术语)
  
阶段2: Task Scoped (按需加载)
  ├─ 根据需求描述推断模块
  ├─ 加载 modules/<name>/index.md
  └─ 按 keywords 匹配 experience/rules/*.yaml
  
阶段3: On Demand (执行时)
  └─ skill 按需 Read 具体代码文件
  
不加载: Never Load
  └─ 冗余文档、过时archive、私密信息
```

**优势**:
- ✅ Token消耗可预测
- ✅ 冷启动快（Always On很小）
- ✅ 动态适应（根据需求加载）
- ⚠️  可能在长流程中截断上下文

---

#### Franco v2.0 — 物理隔离策略

**目标**: 每个 Sub-Agent 有独立、充足的上下文窗口

**实现**:
```
轻量编排层 (主 Agent)
  └─ 体积极小（仅路由逻辑）
  └─ 读 state.json 和 .ai/<id>/
  
专业执行层 (Sub-Agent)
  ├─ 每个Sub-Agent有独立上下文窗口
  ├─ 通过 prompt 传入完整 task.md + plan.md
  ├─ 不共享主 session 历史
  └─ 通过磁盘文件交接状态

交接协议:
  ├─ state.json — 全局状态
  ├─ .ai/<id>/ 目录 — Feature Doc、API Contract、Task List
  └─ 各Sub-Agent写回 .ai/<id>/ 结果
```

**优势**:
- ✅ 每个Sub-Agent都有充足窗口
- ✅ 物理隔离噪音（不受其他对话污染）
- ✅ 断点续传清晰（文件即记录）
- ⚠️  Sub-Agent之间通信需要磁盘I/O

---

## 知识库管理策略

### Forge Plugin KB 设计

#### 结构

```
target-project/.forge-kb/
├── meta/
│   ├── project.yaml           # Always On: 项目元数据 (~50 tokens)
│   ├── glossary.yaml          # Always On: 术语映射 (~150 tokens)
│   └── module-map.yaml        # 模块路径映射
├── modules/
│   ├── <name>/
│   │   ├── index.md           # 模块概述 + 关键入口类 + 历史坑点
│   │   ├── architecture.md    # 模块架构文档
│   │   └── api/               # API 参考
│   └── ...
├── experience/
│   ├── rules/                 # YAML 规则库
│   │   ├── <domain>.yaml      # keywords: [k1, k2, ...] + rules
│   │   └── ...
│   └── patterns/              # 设计模式库
└── templates/
    └── <template-name>/       # 快速启动模板
```

#### 加载流程

1. **Always On** (`project.yaml` + `glossary.yaml`)
   - 大小控制：< 200 tokens
   - 内容：项目基本信息、核心术语、约定俗成

2. **Task Scoped** (根据需求推断)
   - 步骤1: 从需求推断涉及模块 → 加载 `modules/<name>/index.md`
   - 步骤2: 从 keywords 匹配 → 加载相关 `experience/rules/*.yaml`
   - 步骤3: 从代码探索反馈 → 动态加载更多规则

3. **On Demand** (skill 执行时)
   - 按需 Read 具体代码文件
   - 不会全量加载任何文件

#### 知识来源与维护

**知识来源**:
- 项目README、API文档 → 初始化
- Code review 决策 → experience/rules 积累
- 团队讨论记录 → glossary 更新

**维护方式**:
- 自动：`/update-kb` 扫描项目，更新 modules/
- 手动：修改 glossary.yaml 和 experience/rules/

**特点**:
- 知识库是独立仓库（或 git submodule）
- 无需与代码仓库同步
- 可被多个项目复用

---

### Franco v2.0 KB 设计

#### 结构

```
<project>/.ai-knowledge/
├── meta/
│   ├── project.yaml           # 项目元数据
│   ├── glossary.yaml          # 术语映射
│   └── frameworks.yaml        # 框架/库 信息
├── modules/
│   ├── <name>/
│   │   ├── index.md           # 模块概述
│   │   ├── api/               # API 参考
│   │   └── changelog.md       # 近期变更
│   └── ...
├── experience/
│   ├── rules/                 # YAML 规则库（来自AIGC蒸馏）
│   └── patterns/
├── aigc-distilled/            # ⭐ AIGC知识蒸馏区
│   ├── asyncinit-patterns.md  # 异步初始化模式
│   ├── ntcompose-api-tricks.md # NTCompose API 技巧
│   ├── mcp-query-guide.md     # MCP 查询指南
│   └── ...
└── official-docs/            # 官方文档快照
    ├── ntcompose/
    ├── android-qq/
    └── iphone-qq/
```

#### 加载流程

1. **Always On** (同 Forge)
   - `project.yaml` + `glossary.yaml`

2. **Task Scoped**
   - 加载相关 `modules/*/index.md`
   - 加载匹配 `experience/rules/*.yaml`
   - **新增**: 根据技术栈加载 `aigc-distilled/` 内容

3. **On Demand**
   - 执行时 Read 具体文件
   - 支持 MCP 查询官方 API

#### 知识来源与维护

**知识来源**:
- 项目实践 → modules/ 模块文档
- Code review 决策 → experience/rules 积累
- **官方文档 AIGC蒸馏** → aigc-distilled/ 结构化知识
- 开发者反馈 → 迭代优化

**维护方式**:
- 自动：AIGC蒸馏（从官方文档自动转化）
- 人工审核：所有蒸馏内容需Team Lead过审
- 版本追踪：changelog.md 记录知识库演进

**特点**:
- 知识库与代码仓库紧耦合
- AIGC蒸馏 + 人工审核双层质保
- 支持多项目共享（通过 git submodule）
- 可追溯的知识演进历史

---

### 知识库对比矩阵

| 维度 | Forge | Franco |
|------|-------|--------|
| **源头** | 多源（代码+文档+CR） | 多源 + AIGC蒸馏 |
| **维护** | 自动扫描 + 手动 | 自动蒸馏 + 人工审核 |
| **权威性** | 高（原始来源） | 极高（蒸馏+审核） |
| **结构化程度** | 中等 | 高（明确classification） |
| **可复用性** | 高（通用格式） | 中等（项目特定） |
| **Token成本** | 低（优化加载） | 低（隔离设计） |
| **更新频率** | 周期性 | 持续（AIGC驱动） |

---

## 工作流对比

### 简单需求工作流（"把这个改成 X"）

#### Forge Plugin

```
user input (简单改动)
    ↓
Claude 默认行为（不触发 /forge）
    ↓
完成改动
    
说明: 简单改动不经过 forge 流程，直接由 Claude 处理
```

**设计理由**:
- 框架成本不应该体现在简单改动中
- Claude 的 general capability 足以应对
- 保持系统的轻量级

---

#### Franco v2.0

```
user input (简单改动)
    ↓
Demo快速开发模式（独立流程）
    ├─ 不需要TAPD单号
    ├─ 不走完整7阶段
    ├─ 一次确认即可开干
    └─ 支持多轮迭代
    
执行: Demo分析师 + Demo开发工程师
    ↓
完成并可选加入正式迭代

说明: 即使简单改动也走规范化流程，但用专用快速模式
```

**设计理由**:
- 即使小改动也要有追溯（compliance）
- Demo流程是产品判断的一部分
- 支持 ad hoc 探索但留下记录

---

### 复杂需求工作流（标准路径）

#### Forge Plugin — 标准5步

```
Step 1: /clarify (需求澄清)
  input: 原始需求描述
  output: requirement.md (需求文档)
  user confirm? → YES/NO

Step 2: /plan (技术方案)
  input: requirement.md
  output: plan.md (方案) + task.md (执行计划)
  HARD-GATE: user 显式确认 → YES/NO
  if NO → go back to /clarify

Step 3: /implement (按计划编码)
  input: task.md + plan.md
  process: 
    ├─ 执行模式选择: ≤3步 inline，>3步 agent
    ├─ 逐步执行，每步验证
    └─ 输出 deviation 记录（计划外改动）
  
Step 4: /review (代码审查)
  input: 改动文件 + deviation 记录
  output: DONE / DONE_WITH_CONCERNS / NEEDS_CONTEXT / BLOCKED
  if BLOCKED → 可能回到 /plan

Step 5: /test (生成并运行测试)
  input: 改动文件
  output: 测试覆盖率报告
  success? → 完成
```

**特点**:
- 5个独立phase，每个都是user确认点
- 三个强制门：HARD-GATE@plan / confirmation@implement / result check@review
- 灵活回退：任何阶段都可回到前一步

---

#### Franco v2.0 — Story开发7阶段

```
前置: 读TAPD Story单 → 拉取需求

Stage 1: 需求分析 (需求分析师)
  ├─ 理解Story描述
  ├─ 抽取功能需求
  └─ 生成 Feature Doc

Stage 2: 规范审查 (需求分析师)
  ├─ Review Feature Doc
  ├─ 问题反馈迭代
  └─ 规范定版

Stage 3: 技术方案设计 (技术方案设计师)
  ├─ 设计系统架构
  ├─ 定义API Contract
  └─ 生成 Plan Doc

Stage 4: 方案审查 (技术方案设计师)
  ├─ Review Plan Doc
  ├─ 设计方案确认
  └─ 迭代定版

Stage 5: 功能开发 (功能开发工程师)
  ├─ 按API Contract编码
  ├─ 每次改动后强制 ./build.sh
  ├─ 修复轮次≤3
  └─ 生成 dev branch

Stage 6: 代码审查 (代码审查工程师)
  ├─ CR 分级处理 (must/should/ignore/manual)
  ├─ must 项必须修复
  ├─ 修复后回到 Stage 5
  └─ CR 通过后merge

Stage 7: 回归测试 (测试)
  ├─ 运行自动化测试
  ├─ 问题反馈迭代
  └─ Story 完成

断点续传:
  └─ state.json + .ai/<id>/ 支持任意阶段断点恢复
```

**特点**:
- 7个sequential stage，流程明确不歧义
- 每个stage有专属Agent + 特定约束
- SDD三段：Feature Doc → API Contract → 代码
- 强制构建闸门 + 修复轮次限制
- 完整追踪：所有决策、CR意见、修复历史

---

### 工作流对比矩阵

| 维度 | Forge Plugin | Franco v2.0 |
|------|-------------|-----------|
| **简单改动** | Claude直接处理 | Demo快速模式 |
| **复杂需求步数** | 5步 | 7步 |
| **user确认点** | 5个 | 前置+阶段间隐式 |
| **阶段回退** | 灵活 | 支持（via checkpoint） |
| **SDD严格度** | 中等（提示词） | 高（强制三段） |
| **构建验证** | 无强制 | 强制每步 |
| **修复轮次** | 无限制 | ≤3（超限报告） |
| **并行度** | 高（可并行步骤） | 中（sequential stage） |
| **追踪完整性** | 中等 | 极高（每决策记录） |

---

## 设计决策理由

### Forge Plugin 为什么采用这些设计

#### ❓ 为什么是轻量路由而不是流程配置?

**决策**:
- 轻量路由（运行时判断）
- vs 流程配置（预定义flows）

**理由**:
1. **通用性** — 不同项目的流程差异大，无法预定义
   - 团队A可能要求SDD三段，团队B两段
   - 无法用固定7-stage适应所有项目

2. **灵活性** — 运行时路由支持：
   - 临时的单项改动（无需完整流程）
   - user可随时调整路径
   - 易于A/B test新流程

3. **可维护性** — 流程配置需维护 flows/ 目录
   - Forge 不维护它，由目标项目维护
   - 减少 plugin 本身的复杂度

---

#### ❓ 为什么用三级加载而不是全量加载?

**决策**:
- 三级加载（Always On / Task Scoped / On Demand）
- vs 全量加载（启动时加载整个KB）

**理由**:
1. **Token经济学** — Always On 控制在 ~200 tokens
   - 摊销成本极低（任何流程都需付出）
   - 规模化后节省显著

2. **冷启动速度** — 不需要等待KB解析
   - 用户感知延迟低
   - 适合快速迭代

3. **模块独立性** — 按需加载天然支持
   - 新增模块无需修改加载逻辑
   - 易于团队并行维护KB

4. **噪音控制** — 只加载相关知识
   - 减少token中的无关信息
   - 提高模型focus

---

#### ❓ 为什么user确认要穿插整个流程?

**决策**:
- HARD-GATE@plan + confirmations@implement/review
- vs 单一起点确认

**理由**:
1. **渐进式信息收集** — 边做边确认
   - 第一次 /clarify 后可能发现需要改需求
   - 第二次 /plan 后可能发现技术方案不可行
   - 单一起点会导致长流程后发现问题、返工多

2. **control感** — user对过程有主导权
   - 不是"输入需求→等待输出"的黑盒
   - 可在任何点介入、调整

3. **质量保障** — 多次确认 = 多次错误检查
   - /plan 用户可确认方案合理性
   - /implement 用户可确认偏差记录
   - /review 用户可确认修复有效性

---

### Franco v2.0 为什么采用这些设计

#### ❓ 为什么用固定7-stage而不是灵活路由?

**决策**:
- 固定7-stage + state.json 支持任意阶段恢复
- vs Forge 的灵活5步

**理由**:
1. **流程明确性** — 无歧义的任务分解
   - Stage 1-2: 需求明确
   - Stage 3-4: 方案定版
   - Stage 5-7: 实现+验收
   - 任何时间点打开 state.json 都知道当前卡在哪

2. **角色明确性** — 每个Agent有明确职责
   - 需求分析师只做Stage 1-2
   - 开发工程师只做Stage 5
   - 便于多人/Agent 并行处理

3. **compliance** — 监管要求
   - QQGYBiz内部可能需要流程可追溯
   - 固定stage便于审计
   - 与JIRA/TAPD集成清晰

---

#### ❓ 为什么用Sub-Agent物理隔离而不是上下文优化?

**决策**:
- 9个Sub-Agent各自独立上下文
- vs Forge 的三级加载+内存共享

**理由**:
1. **可靠性** — 长流程中的上下文截断
   - v1.0 单体Agent暴露问题：SKILL.md(40KB) + artifacts 填满窗口，LLM"忘记"流程指令
   - 物理隔离天然避免此问题：每个Stage都是新的窗口

2. **Agent专业度** — 减少噪音
   - Code Review Agent 只看改动 + 规则
   - 不需要知道需求分析的复杂过程
   - 每个Agent都专注于自己的领域

3. **错误隔离** — 一个Agent的失败不影响后续
   - Forge: 如果implement过程中某个决策有问题，回到plan→implement的环，可能重复长过程
   - Franco: 实现Agent做错了，只需改state.json的stage标记，重新dispatch新Agent

---

#### ❓ 为什么强制SDD三段而不是灵活?

**决策**:
- 强制 Feature Doc → API Contract → 代码
- vs 可选的规范

**理由**:
1. **质量保障** — 规范是承诺
   - 实现前签合同（API Contract）
   - 实现过程中可验证是否逸出
   - CR时对照Contract判断bug还是特性

2. **沟通效率** — 显式文档
   - 需求和方案的分歧在规范阶段暴露
   - 不是到了implementation才发现理解错误

3. **技术债控制** — 防止快速coding
   - "先做再说" 容易累积债
   - 强制规范阶段天然拉长周期，但质量更高

---

## 代码探索机制

### Forge Plugin 的代码探索

**三维探索**：分为 Stage 0 → Stage A → Stage B

#### Stage 0: KB优先性检查

```
问题: 这个问题在KB中能解决吗?
流程:
  1. 加载 Always On KB (project.yaml + glossary.yaml)
  2. 检查 glossary 术语、project 配置是否包含答案
  3. 若KB能解决，直接返回
  4. 否则进入 Stage A
```

**Cost**: ≤ 1 次API调用

---

#### Stage A: 候选文件识别

```
问题: 哪些文件可能相关?
流程:
  1. 加载 Task Scoped KB (modules/index.md + experience/rules)
  2. 根据需求描述的关键词，结合KB规则，推荐候选文件
  3. 按相关度排序
  4. 分批次返回 (分页，防一次性过多)
  
输出: 候选文件列表 + 相关模块
```

**Cost**: ≤ 5 轮迭代（受搜索配额限制）

**特点**:
- 主动利用KB减少盲目探索
- 支持user反馈（"这个方向不对"）
- 分页防止信息爆炸

---

#### Stage B: 代码细读

```
问题: 这些文件具体怎么用?
流程:
  1. Read 候选文件（受 scope 限制）
  2. 提取关键代码片段
  3. 内联进 plan.md（成为plan的一部分）
  4. 基于这些片段生成 task.md
  
输出: 
  ├─ plan.md (包含代码片段和决策理由)
  └─ task.md (逐步执行计划，可直接run)
```

**Cost**: ≤ 6 轮诊断（Diagnose quota）

**特点**:
- Stage B 内联代码，task.md 自包含
- implement 阶段可直接按 task.md 执行，无需重新探索

---

### Franco v2.0 的代码探索

**集成在需求分析 + 方案设计中**

#### Stage 1-2: 需求分析阶段的代码查询

```
需求分析师的职责:
  1. 理解Story描述 (TAPD单)
  2. 查询项目KB的 modules/ 确定影响的模块
  3. 用MCP查询 NTCompose API (若涉及UI)
  4. 抽取功能需求 → Feature Doc
  
代码查询:
  ├─ .ai-knowledge/modules/*/index.md (模块入口)
  ├─ MCP 官方API查询 (实时)
  └─ 历史Feature Doc 参考 (相似case)
```

---

#### Stage 3-4: 方案设计阶段的代码细读

```
技术方案设计师的职责:
  1. 阅读 Feature Doc
  2. 分析技术可行性
  3. Read 关键模块代码（文件受限）
  4. 定义 API Contract
  5. 生成 Plan Doc
  
代码细读:
  ├─ 核心模块架构 (3-5个关键类)
  ├─ 相似实现的参考 (from .ai-knowledge/experience)
  ├─ 依赖版本约束 (frameworks.yaml)
  └─ 已知坑点 (changelog.md)
```

---

#### Stage 5: 实现阶段的代码生成

```
功能开发工程师的职责:
  1. 按 API Contract 编码
  2. 每步改动后强制 ./build.sh 验证
  3. 若编译失败，诊断错误
  4. 修复 (≤3轮限制)
  5. 提交改动
  
与Forge区别:
  ├─ Forge: 从task.md的代码片段出发
  └─ Franco: 从API Contract出发，no explicit code snippets
  
原因: Franco假设开发工程师有足够能力从Contract生成代码
      Forge是通用框架，需要更多context
```

---

### 代码探索对比矩阵

| 维度 | Forge Plugin | Franco v2.0 |
|------|-------------|-----------|
| **探索阶段数** | 3阶段(S0/A/B) | 集成于2个阶段(需求+方案) |
| **Stage 0 KB优先** | ✅ 主动检查 | ✅ 隐式(modules/) |
| **候选文件识别** | 5轮限制 | 集成于需求分析 |
| **代码细读** | 6轮限制 + 内联片段 | 集成于方案设计 |
| **外部API查询** | 无 | ✅ MCP查询官方API |
| **参考实现查询** | experience/rules | aigc-distilled/ |
| **Query Cost控制** | 严格配额 | 隐式（阶段划分） |
| **代码片段内联** | ✅ 内联进plan.md | ❌ 仅API Contract |

---

## 质量保障机制

### Forge Plugin 的质量保障

#### 层级1: 计划验证（/plan 阶段）

```
HARD-GATE: plan → implement 必须user确认

内容:
  ├─ 需求理解是否正确?
  ├─ 技术方案是否可行?
  ├─ 执行计划是否合理?
  ├─ 风险点是否明确?
  └─ 估时是否合理?
```

**防合理化表** (plan阶段)

| 自我欺骗 | 实际 |
|---------|-----|
| "这个计划很清楚，user肯定会同意" | 计划清楚≠user同意，需user显式确认 |
| "这个需求这么简单，不用plan直接做" | 所有复杂需求先走/clarify→/plan |
| "搜索了很多文件但都不是，第N+1个肯定是" | 若某模块连续3轮无收获，标记"该方向无果" |
| "这个风险很小，不用记录" | 任何风险点≥2个优先级都必须记录 |

---

#### 层级2: 执行约束（/implement 阶段）

```
Constraint Checking Before Each Step:

对每个step执行前:
  1. 对照 plan.md 的"设计决策"，本步改动是否违反?
  2. 检查"边界与约定"，是否涉及不做什么的内容?
  3. 触碰"风险点"了吗? 需要特别验证?
  
若有冲突 → 停止，用AskUserQuestion说明并请求决策
```

**防合理化表** (implement阶段)

| 自我欺骗 | 实际 |
|---------|-----|
| "这个改动很小，不用单独记录" | 所有计划外改动必须进偏差记录 |
| "这两步逻辑连贯，合并执行更高效" | 每步独立验证是质量保障，high efficiency ≠ correctness |
| "现有测试逻辑有问题，顺便修一下" | 发现测试问题应记录，由/review决策 |
| "task.md没说不能改这个文件" | Scope Guard: task.md未声明=超范围 |
| "这个依赖其实早就用了，引入没影响" | 新依赖必须在决策节说明理由 |
| "Bug很明显，修了再说" | 修Bug=计划外改动，记录后由user/review决策 |
| "user之前说过可以顺手改" | 对话记录不是执行计划，以task.md为准 |

---

#### 层级3: 偏差追踪（/implement 完成后）

```
在汇总中必须包含:
  ├─ 变更摘要: 所有改动文件和说明
  ├─ 关键决策: 每个不平凡决策及why
  ├─ 偏差记录: 超出计划的改动 + 原因
  ├─ 已知风险: reviewer/tester需关注的地方
  └─ 决策依据: 这些决策从何而来
```

---

#### 层级4: 代码审查（/review 阶段）

```
输出四级结果:
  DONE
    └─ 无问题，可merge

  DONE_WITH_CONCERNS
    ├─ 通过但有需关注的地方
    └─ 应补充测试或文档

  NEEDS_CONTEXT
    ├─ 审查需要更多上下文
    ├─ 需要PM/TM介入
    └─ 或需要阅读更多代码

  BLOCKED
    ├─ 发现严重问题
    ├─ 需要返回implement修复
    └─ 或需要返回plan重新设计
```

---

### Franco v2.0 的质量保障

#### 层级1: SDD三段制（需求→规范→代码）

```
前置要求:
  ├─ Feature Doc (Stage 1-2)
  │   └─ 需求分析师编写 + 审查
  ├─ API Contract (Stage 3-4)
  │   └─ 方案设计师编写 + 审查
  └─ Implementation (Stage 5)
      └─ 开发工程师按Contract编码

质保机制:
  ├─ Feature Doc被认可后，视为需求已定版
  ├─ API Contract被认可后，视为方案已确认
  ├─ 实现必须 100% 遵循 Contract
  ├─ 超出 Contract 的改动 = CR意见 must fix
  └─ Contract 本身有问题 = 回到 Stage 3 重新设计
```

---

#### 层级2: 强制构建闸门

```
每次改动后必须 ./build.sh -p android -t dex debug

目的:
  ├─ 编译错误 fail-fast
  ├─ 防止累积syntax错误到later stage
  ├─ 每个commit点都是可编译状态

限制:
  └─ 修复轮次 ≤ 3
      若超过3轮构建失败 → 立即报告，escalate
```

---

#### 层级3: CR分级处理

```
Code Review 意见分级:

must
  ├─ 逻辑bug、安全问题、违反API Contract
  ├─ 必须修复
  └─ 不修复 = CR不通过

should
  ├─ 最佳实践、性能优化建议
  ├─ 建议修复但非硬性
  └─ 可留作技术债跟进

ignore
  ├─ 样式、命名细节、无关意见
  ├─ 不需修复
  └─ 开发工程师可忽略

manual
  ├─ 超出AI能力范围
  ├─ 需人工处理
  └─ Reviewer标记后人工跟进
```

**CR回环**:
```
if must items exist:
  → 开发工程师修复
  → 重新提交 (Stage 5)
  
if should/ignore/manual only:
  → CR通过，进入 Stage 7 回归测试
```

---

#### 层级4: 搜索配额限制（防无限诊断）

```
Specify (需求澄清)
  └─ ≤ 5 轮

Plan (技术方案)
  └─ ≤ 5 轮

Diagnose (问题诊断)
  └─ ≤ 6 轮
  
超配额 → 立即停止并报告
```

---

### 质量保障对比矩阵

| 维度 | Forge | Franco |
|------|-------|--------|
| **计划验证** | HARD-GATE (user确认) | SDD三段(规范审查) |
| **执行约束** | 每步Constraint Check | 强制构建+修复限制 |
| **偏差追踪** | 完整偏差记录 + 理由 | state.json记录状态 |
| **代码审查** | 4级结果+修复建议 | must/should/ignore/manual分级 |
| **CR回环** | 可能返回implement/plan | 仅返回implement (≤3轮) |
| **质保机制** | 流程驱动 | 规范驱动 |
| **防合理化** | 明确列表(7项) | 流程约束(hard-code) |
| **查询成本** | 配额限制(Specify/Plan/Diagnose) | 配额限制(同Forge) |

---

## 相似性与差异矩阵

### 完整对比表

| 维度 | Forge Plugin | Franco v2.0 | 相似度 |
|------|-------------|-----------|--------|
| **项目类型** | 通用插件 | 团队专有系统 | 不同 |
| **部署方式** | 目标项目 + plugin | CodeBuddy + 代码仓库 | 不同 |
| **编排层** | 轻量路由 | 流程配置 | 10% |
| **Sub-Agent数** | 按需 | 固定9个 | 30% |
| **上下文策略** | 三级优化加载 | 物理隔离 | 20% |
| **知识库结构** | modules+experience | modules+aigc-distilled | 70% |
| **知识维护** | 自动扫描 | AIGC蒸馏+审核 | 60% |
| **SDD严格度** | 中等 | 极高 | 40% |
| **人工确认** | 多次(5个点) | 隐式(前置+检查) | 50% |
| **流程阶段数** | 5步 | 7步 | 60% |
| **修复轮次** | 无限制 | ≤3 | 10% |
| **配置驱动** | 低 | 高 | 20% |
| **可追踪性** | 中等 | 极高 | 30% |

---

## 行业基准对比

### vs QAE (QQ Agentic Engineering)

**QAE 特点**:
- 多链路全覆盖（代码+文档+测试）
- CodeBuddy平台集成
- 8项鲁棒性增强

**相似**:
- Forge: 吸收了QAE的knowledge库概念 → Always On / Task Scoped
- Franco: 采用了QAE的多Sub-Agent思路 → 9个专业角色

**差异**:
- Forge: 更通用，不锁定特定平台
- Franco: 更严格，更依赖平台特性

---

### vs Superpowers

**Superpowers 特点**:
- 反合理化系统（与Forge的防合理化表类似）
- 五步开发流程
- 15.1万星开源项目

**相似**:
- Forge / Franco: 都学习了Superpowers的质量保障思路
- 都使用了多级确认机制

**差异**:
- Forge: 更轻量（参考，未直接继承）
- Franco: 更严格（超过Superpowers的约束）

---

### vs OpenClaw / Hermes

**OpenClaw (TS, 安全优先)**:
- 人工维护Skills
- TypeScript实现
- 4个月18万Stars

**Hermes (Python, 自进化)**:
- Agent自写Skills
- 3层记忆系统
- RL工具链

**Forge vs OpenClaw**:
- Forge: 更灵活（自动路由），OpenClaw: 更安全（人工维护）
- 架构理念不同

**Franco vs Hermes**:
- Franco: 人工维护flows，Hermes: 自动学习
- Franco更保守，Hermes更冒险

---

## 融合架构建议

### 场景1: 企业内部采用 Franco 的严格流程

```
基础采用 Franco v2.0 的:
  ├─ Harness四层约束
  ├─ SDD三段制
  ├─ 固定7-stage流程
  ├─ 强制构建闸门
  └─ 修复轮次限制

补充 Forge 的:
  ├─ 三级加载KB策略 (vs Franco的全加载)
  ├─ 防合理化表(显式列表)
  ├─ Task-scoped KB加载逻辑
  └─ 灵活的user确认UX
```

**价值**:
- 获得Franco的严格度
- 获得Forge的Token经济学
- 获得两者的质保机制

---

### 场景2: 开源项目采用 Forge 的灵活性

```
基础采用 Forge 的:
  ├─ 轻量路由编排
  ├─ 三级KB加载
  ├─ 灵活flow支持
  └─ user driven pipeline

补充 Franco 的:
  ├─ 物理上下文隔离 (vs Forge的内存共享)
  ├─ 明确的Sub-Agent角色
  ├─ flows/ 配置可选择
  └─ state.json 断点续传
```

**价值**:
- 获得Forge的通用性
- 获得Franco的可追踪性
- 可根据项目选择严格度

---

### 场景3: 双轨制架构

```
组织结构:
  
企业内部正式项目
  ├─ 采用 Franco 严格7-stage
  ├─ SDD + 强制构建
  ├─ 人工维护flows/
  └─ AIGC蒸馏 + 审核KB

开源/探索项目
  ├─ 采用 Forge 灵活5步
  ├─ 三级KB加载
  ├─ user决策驱动
  └─ 自动KB扫描

共用层:
  ├─ 防合理化表
  ├─ 质保检查清单
  ├─ 知识库模块结构
  └─ Sub-Agent角色定义
```

---

## 总结

### 核心洞见

1. **架构选择的Trade-off**
   - Forge: 通用性 vs 严格度（选通用）
   - Franco: 严格度 vs 灵活性（选严格）
   - 没有绝对优劣，关键是match场景

2. **质保的两条路**
   - Forge: 流程驱动（多次user确认）
   - Franco: 规范驱动（SDD三段 + 强制约束）
   - 都是可行的，选择取决于团队文化

3. **上下文管理的本质**
   - Forge: 优化加载（Token省）
   - Franco: 物理隔离（reliability高）
   - 长流程中隔离优于加载

4. **知识库的价值**
   - Forge: 通用模板 + 自动扫描
   - Franco: AIGC蒸馏 + 人工审核
   - 知识库是最高价值资产

### 建议路径

**如果你的团队是**:
- 新成立 → 采用 Forge 快速start
- 规模扩大 → 迁移到 Franco 的严格度
- 既定文化 → 混合方案（双轨或分项选择）

**重点投入顺序**:
1. 知识库维护（最高ROI）
2. 流程规范化（SDD or 确认机制）
3. 工具链优化（Sub-Agent、并行度）

---

**Generated by**: Claude Code Analysis  
**Last Updated**: 2026-04-24  
**Next Review**: 2026-05-24 (Monthly)

