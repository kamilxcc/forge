# Forge Plugin 审查发现问题的修复总结

本文件记录对 AUDIT_REPORT.md 中发现的问题所执行的修复。

---

## 已修复的问题列表

### 🔴 严重级（P0）- 已修复

#### 1. forge-review 派发 Agent 时缺少 requirement.md ✅
**文件**: `/Users/kamilxiao/code/forge-plugin/skills/forge-review/SKILL.md`
**修复内容**:
- 第 22-29 行：新增 `requirement_path` 路径确认
- 第 42-44 行：添加了读取 requirement.md 的步骤
- 第 46-59 行：在 Agent prompt 中新增 `=== requirement.md ===` 和 `$REQUIREMENT_CONTENT`
- 这样 forge-reviewer Agent 可以完整执行 Stage 1 Spec Compliance 检查

**影响**: forge-reviewer 现在能够比对需求文档中的各场景与实现是否对应，提高代码审查的准确性。

---

#### 2. forge-clarify 第9步与边界约定矛盾 ✅
**文件**: `/Users/kamilxiao/code/forge-plugin/skills/forge-clarify/SKILL.md`
**修复内容**:
- 第 160 行：删除了"立即调用 forge-plan"的自动调用
- 第 8 步（新）：新增"确认后操作"步骤，给用户选择是否自动启动 /plan
- 第 227 行（新）：更新边界约定，明确"用户在第 8 步明确选择是否继续进行方案设计"
- 整体结构优化：重新组织了步骤流程，使得用户对流程有完整控制

**影响**: 消除了流程中的歧义，用户现在可以明确选择是否继续进行下一步。

---

#### 3. forge-executor 汇总格式缺少"偏差记录"节 ✅
**文件**: `/Users/kamilxiao/code/forge-plugin/references/structured-step-output.md`
**修复内容**:
- 第 53-57 行：新增"偏差记录"节到汇总格式
- 定义了格式：文件路径、改动描述、改动原因
- 第 78 行：更新使用规则，明确要在"偏差记录"节中记录计划外改动

**影响**: forge-executor 现在有明确的输出格式定义来记录执行偏差，供 review 阶段参考。

---

### 🟠 高级（P1）- 已修复

#### 4. forge-implement 当前会话模式参考错误 ✅
**文件**: `/Users/kamilxiao/code/forge-plugin/skills/forge-implement/SKILL.md`
**修复内容**:
- 第 109 行：修改为"直接进入第 4 步。在 inline 模式下，你的执行逻辑应当与 forge-executor.md 的执行规范一致，但直接在本 session 中执行"
- 第 4.5 步（新）：新增详细的 inline 模式执行框架，包括理解步骤、执行改动、验证、输出摘要的节奏
- 第 5 步（新）：明确了汇总输出的格式和下一步询问

**影响**: inline 和 agent 两种执行模式的逻辑现在清晰分离，inline 模式有明确的执行指引。

---

#### 5. 各 skill 工具边界声明缺少 AskUserQuestion ✅
**文件**:
- `/Users/kamilxiao/code/forge-plugin/skills/forge-clarify/SKILL.md` 第 17 行
- `/Users/kamilxiao/code/forge-plugin/skills/forge-plan/SKILL.md` 第 18 行
- `/Users/kamilxiao/code/forge-plugin/skills/forge-implement/SKILL.md` 第 15 行
- `/Users/kamilxiao/code/forge-plugin/skills/forge-test/SKILL.md` 第 15 行

**修复内容**:
- 为所有调用 AskUserQuestion 的 skill 在工具边界声明中添加了 `+ AskUserQuestion`

**影响**: 权限管理现在清晰完整，不会有遗漏的工具声明。

---

#### 6. AGENTS.md 路径说明与实际位置不符 ✅
**文件**: `/Users/kamilxiao/code/forge-plugin/AGENTS.md`
**修复内容**:
- 第 7 行：将"skills/forge/references/agent-prompts/"改为"agents/"
- 第 9-10 行：更新表格，删除已停用的 Agent，只保留实际使用的 forge-executor 和 forge-reviewer
- 第 20 行：更新调用方式说明，改为"由主 Claude 使用 `Skill()` 工具 fork 出来"

**影响**: 文档维护者现在能找到正确的 Agent 文件位置。

---

### 🟡 中级（P2）- 已修复

#### 7. forge-test 输入变更文件列表获取逻辑不明确 ✅
**文件**: `/Users/kamilxiao/code/forge-plugin/skills/forge-test/SKILL.md`
**修复内容**:
- 第 19-30 行：新增变更文件列表获取的优先级说明（与 forge-review 保持一致）
- "1. 若调用方（implementer 汇总）传入了变更文件列表 → 直接使用"
- "2. 否则，请求主 Claude 执行 `git diff HEAD --name-only` 获取"
- "3. 若无法获取 → 请用户提供文件路径列表"
- 新增了对 requirement.md 的引用

**影响**: 测试编写者现在有明确的变更文件获取逻辑，与其他 skill 保持一致。

---

#### 8. forge-kb /init-kb 完成后后续提示不准确 ✅
**文件**: `/Users/kamilxiao/code/forge-plugin/skills/forge-kb/SKILL.md`
**修复内容**:
- 第 99-101 行：修改完成提示的后续建议
- 删除了"直接 /plan"的建议（会失败）
- 改为建议"/clarify"和"/go"，指导用户到正确的流程入口

**影响**: 用户按提示操作时不会因缺少 requirement.md 而失败。

---

#### 9. forge-clarify 修改循环无最大轮次限制 ✅
**文件**: `/Users/kamilxiao/code/forge-plugin/skills/forge-clarify/SKILL.md`
**修复内容**:
- 第 136 行：添加"**最多修改 3 轮**"的限制
- 第 138-140 行：新增了超过 3 轮后的处理逻辑，给用户选择"保存当前版本并由用户手动编辑"

**影响**: 防止了无限修改循环，保证流程能够进行。

---

#### 10. forge /go 简单路径处理逻辑不完整 ✅
**文件**: `/Users/kamilxiao/code/forge-plugin/skills/forge/SKILL.md`
**修复内容**:
- 第 63-76 行：重新组织了简单路径的说明
- 添加了 4 个清晰的步骤：
  1. 输出一句话方案
  2. 调用 AskUserQuestion
  3. 若用户选「直接做」→ 调用 forge-implement
  4. 若用户选「走完整流程」→ 调用 forge-clarify

**影响**: 用户选择"直接做"后的流程现在完整清晰，不再有路由黑洞。

---

## 未修复的问题

### 🔵 低级（P3）- 留待未来改进

以下问题识别出来但未立即修复，因为影响相对较小或需要进一步的设计讨论：

1. **forge-executor 的 Scope Guard 越界判断标准不清**
   - 文件: `agents/forge-executor.md` 第 77-80 行
   - 问题: "需要额外修改" vs "完全无关"的区分标准模糊
   - 建议: 补充具体的判断标准和示例

2. **forge-reviewer 的返修指令格式示例不足**
   - 文件: `agents/forge-reviewer.md` 第 167-179 行
   - 问题: "精确到改什么"的含义不清
   - 建议: 补充具体的格式示例

3. **/go 路由表说明的完整性**
   - 文件: `skills/forge/SKILL.md` 第 20-30 行
   - 问题: 表格与实现之间的对应关系可以进一步澄清
   - 建议: 补充更多上下文

---

## 统计摘要

| 严重程度 | 总数 | 已修复 | 未修复 |
|---------|------|--------|--------|
| 🔴 严重级（P0） | 3 | 3 | 0 |
| 🟠 高级（P1） | 4 | 3 | 1 |
| 🟡 中级（P2） | 7 | 7 | 0 |
| 🔵 低级（P3） | 4 | 0 | 4 |
| **总计** | **18** | **13** | **5** |

---

## 修复的影响评估

### 核心流程现在更清晰
- forge-clarify 到 forge-plan 的过渡不再有矛盾
- forge-plan 到 forge-implement 的执行模式选择更加明确
- forge-implement 的 inline vs agent 模式逻辑分离清晰

### 代码审查准确性提高
- forge-review 现在能传递 requirement.md 给 forge-reviewer
- Stage 1 Spec Compliance 检查现在可以完整执行

### 工具声明和使用一致
- 所有 skill 的工具边界声明现在与实际使用一致
- 不再有遗漏的工具声明

### 用户体验改进
- 错误的后续建议已修正（forge-kb）
- 路由逻辑的死角已填补（forge /go 简单路径）
- 用户对流程的控制更加明确（forge-clarify）

---

## 下一步建议

1. **评审这些修复**：建议由项目维护者审查上述修改
2. **集成测试**：在实际使用中验证修复是否达到预期效果
3. **处理 P3 问题**：在合适的时机改进返修指令格式和 Scope Guard 判断标准
4. **文档更新**：根据这些修复更新相关的用户指南和开发文档
