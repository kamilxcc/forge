# Execution Mode Protocol — 执行模式判断协议

所有需要判断 inline / agent 模式的 skill（forge-plan、forge-implement）统一使用本协议的阈值和规则，**不得各自内联重复定义**。

---

## 阈值表

| 步骤数 | 推荐模式 | 理由 |
|--------|---------|------|
| ≤ 3 步 | `inline`（当前会话直接执行） | 上下文连续，单轮会话不会漂移 |
| 4–6 步 | `agent`（Fork 子 Agent） | 步骤多时会话历史累积会影响后续判断，Agent 隔离后每步上下文干净 |
| > 6 步 | `agent` + **建议拆需求** | 单次任务过大，历史负担过重；建议与用户拆分后再执行 |

---

## forge-plan 使用方式（Step 6 — 写入 task.md）

在生成 task.md 时，按上表将推荐模式写入 `recommended_mode` 字段和「执行建议」节：

```markdown
## 执行建议

模式：**<inline|agent>**
理由：步骤数 = N，<对应阈值段的简短说明>
```

> > 6 步时额外追加：`⚠️ 步骤数超过 6，建议与用户拆分为多个子需求后分批执行。`

---

## forge-implement 使用方式（Step 3.5 — 运行时选择）

读取 task.md 中的 `estimated_steps` 字段（或手动数步骤列表），按上表判断：

- **≤ 3 步**：直接进入 Step 4，在当前 session inline 执行，不弹 AskUserQuestion
- **> 3 步**：弹出 AskUserQuestion 让用户选择：

```
📋 本次计划共 N 步，建议使用 Agent 模式执行（隔离上下文，避免长对话漂移）。
```

AskUserQuestion 参数：
- `header`：「执行模式」
- `multiSelect: false`
- `options`：
  - `label: Agent 模式（推荐）` / `description: 派发子 Agent 执行，上下文隔离，适合步骤多的任务`
  - `label: 当前会话执行` / `description: 在本 session 直接执行，上下文连续但可能变长`

---

## 关键约定

- forge-plan 只负责**写入建议**到 task.md，不做运行时模式选择
- forge-implement 负责**运行时判断**，以 task.md 中的 `estimated_steps` 为基准
- 两者阈值必须保持一致，修改时同步更新本文件，**不得单独修改任一 SKILL.md 中的阈值**
