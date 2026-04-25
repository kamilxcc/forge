# execution-core-protocol — 编码执行公共协议

本协议被 forge-implement（inline 模式）和 forge-executor（Agent 模式）共同引用。两种模式的差异在文中用标签标注。

---

## 1. TodoWrite 初始化

读取 task.md 中的步骤列表，调用 `TodoWrite` 把所有步骤写入任务列表：

```
TodoWrite([
  { id: "step-1", content: "Step 1: <标题>", status: "pending", priority: "high" },
  { id: "step-2", content: "Step 2: <标题>", status: "pending", priority: "high" },
  ...
])
```

断点续传时，已完成步骤（`[x]`）直接设为 `completed`，只把未完成步骤设为 `pending`。

---

## 2. 逐步执行节奏

**按计划步骤顺序执行，不可跳步，不可合并步骤**。每步遵循以下节奏：

### 开始前
1. 调用 `TodoWrite` 将当前步骤状态改为 `in_progress`
2. **约束核对**：对照执行约束基线（设计决策/边界约定/风险点），检查本步改动是否违反；有冲突 → 【inline】AskUserQuestion 说明冲突 / 【Agent】记录到偏差记录并自主决策是否继续

### 理解步骤
- task.md 是自包含的（/plan 已把关键代码片段内联进来），**直接读 task.md 本步骤内容执行，不做额外 Glob/Grep/Read**
- **唯一例外**：该文件已被前步修改，需要读最新状态 → Read 文件获取当前内容
- **信息缺口上报**：若步骤中有无法从 task.md 直接获取的信息（方法名不存在、行号不符、文件找不到）→ 【inline】AskUserQuestion 询问用户 / 【Agent】停止本步骤，上报 NEEDS_CONTEXT

### 执行改动
使用 Write/Edit/Bash 等工具执行改动。

### Scope Guard（不可绕过）
对比本步骤即将修改的文件与 task.md 中该步骤声明的文件列表：
- 完全一致 → 继续
- 需要额外修改计划外文件 → 先说明原因，在汇总「偏差记录」中标注
- 准备修改完全无关的模块 → 停止并标记，不静默越界

### 步骤级止损

遇到以下任一情况立即触发：
- 实际代码与 task.md 描述不符（方法签名/参数数量/文件结构不一致）
- 本步改动可能影响 task.md 未列出的调用方
- 出现非预期编译或 lint 报错

触发后输出：
```
⛔ Step N 执行中止

发现：<具体不一致描述>
task.md 预期：<预期内容>
实际情况：<实际内容>
```

**【inline】** 调用 AskUserQuestion：
- `header`：「执行中止」
- `options`：按实际情况调整后继续 / 停止重新 /plan / 跳过本步骤

**【Agent】** 自主决策：
- 小偏差（行号偏移 ±5 行、拼写变化）→ 调整后继续，在汇总记录
- 大偏差（签名不匹配、文件不存在、多处未列出的调用方）→ 停止本步骤，标记「阻塞」

### 验证
执行相关的语法检查或编译验证。Bash 执行返回非 0 时最多尝试 2 次自动修复，仍失败则标记「阻塞」。

### 完成后
1. 调用 `TodoWrite` 将当前步骤状态改为 `completed`
2. 按 `<plugin_root>/references/structured-step-output.md` 输出 Step N 摘要
3. 将 task.md 中对应步骤的 `- [ ]` 改为 `- [x]`（持久化进度）

---

## 3. 验收清单（Verification Checklist）

所有步骤完成后，在输出汇总前逐项核查。**每项必须明确回答 ✅ / ❌ / N/A，不可跳过**：

| # | 检查项 | 通过标准 |
|---|--------|---------|
| 1 | **所有步骤均已执行** | task.md 中无残留 `[ ]` 步骤 |
| 2 | **无未声明的计划外改动** | 所有超出 task.md 文件范围的改动均已在「偏差记录」中记录原因 |
| 3 | **边界约定遵守** | plan.md 中「边界与约定」节的每条"不做什么"均未被触碰 |
| 4 | **CLAUDE.md 项目规则合规** | 目标项目 CLAUDE.md 中列出的编码规则均已遵守（如日志接口、布局方式、改动前评估调用方等项目特定约束） |
| 5 | **范围外发现已显式声明** | 执行中发现的范围外问题，均已在对应步骤摘要「发现但未触碰」字段中记录 |
| 6 | **现有测试未被覆盖** | 未修改任何现有测试文件，或已在偏差记录中说明原因 |

**【inline】** 若任一项为 ❌：停止，说明具体违反原因，调用 AskUserQuestion 询问用户处理方式。
**【Agent】** 若任一项为 ❌：在汇总「偏差记录」中标记，说明具体违反原因，由主 session 处理。

---

## 4. 汇总输出

按 `<plugin_root>/references/structured-step-output.md` 的"汇总格式"输出，必须包含：
- 变更文件列表（路径 + 变更类型 + 一句话说明）——供 forge-review 直接用作审查范围
- 关键决策汇总
- 已知风险/建议检查点
- 未触碰声明（汇总自各步骤「发现但未触碰」字段）
- 偏差记录（若有）
- 验收清单结果（各项的 ✅ / ❌ / N/A）

---

## 5. 防合理化

参见 `<plugin_root>/references/implement-guardrails.md`。
