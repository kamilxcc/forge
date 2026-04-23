# Forge Plugin 全面审查报告

## 问题汇总

### 1. 内部一致性问题

#### 1.1 forge-clarify 第9步与边界约定矛盾【严重】
**文件**: `/Users/kamilxiao/code/forge-plugin/skills/forge-clarify/SKILL.md`
**位置**: 
  - 第 160 行（第9步）："立即调用 `Skill("forge-plan")`，无需等待用户再次输入命令。"
  - 第 227 行（边界约定第3条）："需求文档写完后必须等用户确认，不自动触发 `/plan`"

**问题**: 自相矛盾。第9步说"立即调用forge-plan"，边界约定说"不自动触发"。

**影响**: 
- 如果自动触发，违反了要求用户确认的原则
- 如果不自动触发，第9步的实现步骤是错的

**建议修复**: 选择其一：
  - 要么删除第160行自动调用逻辑，改为询问用户
  - 要么删除边界约定第3条，明确允许自动触发

---

#### 1.2 forge-plan 与 forge-clarify 对"自动调用下一步"的处理不一致
**文件**: 
  - `/Users/kamilxiao/code/forge-plugin/skills/forge-plan/SKILL.md` 第 171 行
  - `/Users/kamilxiao/code/forge-plugin/skills/forge-clarify/SKILL.md` 第 160 行

**问题**: 
- forge-clarify 第9步说"立即调用 forge-plan"（第160行）
- forge-plan 第7步说"立即调用 forge-implement"（第171行）

但两处都在边界约定中说"不自动触发下一步"或"必须等用户确认"。

**具体矛盾**:
```
forge-clarify 边界约定第3条（第227行）：
"需求文档写完后必须等用户确认，不自动触发 `/plan`"

但第160行说：
"立即调用 `Skill("forge-plan")`"
```

**影响**: 对用户体验和流程控制的设计原则不清晰。

---

#### 1.3 forge-review SKILL.md 中的 Agent prompt 不完整
**文件**: `/Users/kamilxiao/code/forge-plugin/skills/forge-review/SKILL.md`
**位置**: 第 42-58 行

**问题**: 
forge-review 声称要将完整的 `$PLAN_CONTENT` 传给 Agent，但实际上是：
```markdown
第42行："Read `plan_path`，将完整内容存为 `$PLAN_CONTENT`"
第44-57行提供的 prompt 中确实包含了 $PLAN_CONTENT
```

但是 **forge-review 声称要派发的 forge-reviewer agent 在实际需要比对 requirement.md** 才能做 Spec Compliance 检查（见 forge-reviewer.md 第 75-76 行）。

**forge-review SKILL.md 的 prompt 中只嵌入了 plan.md，没有嵌入 requirement.md**。

**具体位置**:
- forge-reviewer.md 第 76 行: "需求文档的各场景（含异常路径）是否均有对应处理"
- 但调用时（forge-review.md 第44-57行）没有传 requirement.md

**影响**: forge-reviewer 无法比对需求与实现，Stage 1 审查会不完整。

---

#### 1.4 forge-implement 执行模式选择逻辑重复
**文件**: `/Users/kamilxiao/code/forge-plugin/skills/forge-implement/SKILL.md`
**位置**: 第 66-109 行

**问题**: 
第 3.5 步「执行模式选择」的逻辑与第 4 步「展示执行计划总览」的逻辑不清晰：

- 第 66-83 行：Step 3.5 说要根据步骤数选择 inline 还是 agent
- 第 84-109 行：若选 Agent 模式，构建 prompt 派发
- 第 109 行：若选当前会话模式，"由 forge-executor agent 的执行规范指导本 session 执行"

**矛盾点**: 
- 第 109 行说"当前会话模式"要参考 forge-executor.md，但 forge-executor 是个 Agent，应该只在 Agent 模式下运行
- 实际上当前会话模式应该直接参考本 SKILL.md 中的第 4 步（inline 执行），而不是参考 forge-executor

---

### 2. 流程完整性问题

#### 2.1 forge-clarify 完成后的路由逻辑不清
**文件**: `/Users/kamilxiao/code/forge-plugin/skills/forge-clarify/SKILL.md`
**位置**: 第 146-160 行

**问题**: 
第 8 步说"展示需求文档草稿"，用户"确认，开始方案设计"
第 9 步说"立即调用 forge-plan"

但这里有歧义：
- 如果自动调用，那用户选了"开始方案设计"但接下来没有办法拒绝
- 如果用户选了"需要修改"呢？整个流程会陷入修改循环

**具体缺陷**:
- 第 144 行说修改后"重新执行第 7 步自查，再展示草稿确认，直到用户确认为止"
- 但没有说最多修改几轮，会不会陷入死循环

**建议**: 
- 明确最多允许修改几轮（如 3 轮）
- 超出后，要么保存当前版本让用户手动编辑，要么中止

---

#### 2.2 forge-plan 的"复杂度自判"与后续流程的矛盾
**文件**: `/Users/kamilxiao/code/forge-plugin/skills/forge-plan/SKILL.md`
**位置**: 第 135-142 行

**问题**:
第 135-141 行说"按步骤数决定执行模式"（≤3步inline、4-6步agent、>6步agent+建议拆）

但这是 forge-plan 在 task.md 执行建议节中**记录**的建议，而不是 forge-plan 自己要做的决策。

**实际流程**:
- forge-plan 生成 task.md 并在 task.md 里写入推荐模式
- 然后 forge-implement 根据 task.md 中的推荐模式决定是否使用 agent
- 但 forge-implement 第 3.5 步又说要根据"读取 task.md 中的步骤总数"重新判断

**矛盾**: 是否重复计算模式？forge-plan 写的建议是否被 forge-implement 尊重？

---

#### 2.3 forge-test 的输入依赖未明确
**文件**: `/Users/kamilxiao/code/forge-plugin/skills/forge-test/SKILL.md`
**位置**: 第 19-24 行

**问题**:
输入说"implementer 输出的'实施完成汇总'（变更文件列表）"，但没有说这个汇总的格式是什么，怎么从主 session 获取。

比较 forge-review.md 的处理：
- forge-review 第 31-36 行清晰地说"优先级：传入 vs git diff vs 手动提供"
- forge-test 没有这个说明

**建议**: 
补充第 2 步前置的变更文件列表获取逻辑。

---

#### 2.4 forge-kb /init-kb 完成后没有明确的后续提示
**文件**: `/Users/kamilxiao/code/forge-plugin/skills/forge-kb/SKILL.md`
**位置**: 第 88-102 行

**问题**:
第 5 步说"完成提示"，列出已完成的三项，然后说"下一步可以"：
```
- /plan <需求描述> — 开始你的第一个功能
- /onboard <模块名> — 深入了解某个模块
```

但这两者的调用方式不同：
- `/plan` 需要先 `/clarify` 生成 requirement.md（这里跳过了）
- 这里直接建议 `/plan`，会失败

**建议**: 
改为建议用户 `/clarify` 或 `/go`，而不是直接 `/plan`。

---

### 3. 引用不存在的文件

#### 3.1 ask-user-question-protocol.md 被广泛引用且存在✓
**状态**: ✓ 文件存在，无问题

---

#### 3.2 forge-reviewer.md 在 agents/ 下但 AGENTS.md 引用错位置
**文件**: `AGENTS.md` 第 7-16 行
**问题**: 
```markdown
AGENTS.md 第 11 行说：
"详细的 Agent prompt 存放在 `skills/forge/references/agent-prompts/` 目录"

但实际上：
- agents/forge-executor.md 实际存在
- agents/forge-reviewer.md 实际存在

路径不对。应该是 agents/ 不是 skills/forge/references/agent-prompts/
```

**建议**: 更新 AGENTS.md 的路径说明。

---

#### 3.3 forge-deposit.SKILL.md 在 skills/_inactive/ 中被停用
**文件**: `/Users/kamilxiao/code/forge-plugin/skills/_inactive/forge-deposit.SKILL.md`
**问题**: 
forge-deposit 在 _inactive 下（已停用），但：
- AGENTS.md 第 15 行仍然引用 "depositor" Agent
- forge-executor.md 第 105 行汇总格式说"建议运行 /deposit 沉淀"

如果 forge-deposit 已停用，这两处引用就是死链。

---

### 4. 工具边界声明不完整

#### 4.1 forge-clarify 的工具边界声明过于简略
**文件**: `/Users/kamilxiao/code/forge-plugin/skills/forge-clarify/SKILL.md`
**位置**: 第 17 行

**问题**:
```
**工具边界**：Read / Glob / Grep（只读，用于理解现有功能上下文）+ Write（只写 `<plugin-root>/work/`）
```

缺少重要工具声明：
- 没有提到需要使用 `AskUserQuestion`
- 没有明确说 `Write` 的完整范围（是只写 requirement.md，还是可以写其他文件？）

**建议**: 补充：
```
**工具边界**：Read / Glob / Grep（只读）+ Write（只写 `<plugin-root>/work/<project>/`）+ AskUserQuestion
```

---

#### 4.2 forge-plan 的工具边界声明缺少 AskUserQuestion
**文件**: `/Users/kamilxiao/code/forge-plugin/skills/forge-plan/SKILL.md`
**位置**: 第 18 行

**问题**: 
```
**工具边界**：Read / Glob / Grep（只读）+ Write（只写 `<plugin-root>/work/` 下的文档）
```

但在第 107 行调用了 `AskUserQuestion`，工具边界声明中没有。

**建议**: 补充 `+ AskUserQuestion`

---

#### 4.3 forge-implement 的工具边界声明缺少 AskUserQuestion
**文件**: `/Users/kamilxiao/code/forge-plugin/skills/forge-implement/SKILL.md`
**位置**: 第 15 行

**问题**: 
```
**工具边界**：Read / Write / Edit / Bash / Glob / Grep（完整读写权限）
```

但在多个地方调用了 `AskUserQuestion`，工具边界声明中没有。

---

### 5. 结构缺陷

#### 5.1 /go 路由表与实际 skill 描述不一致
**文件**: `/Users/kamilxiao/code/forge-plugin/skills/forge/SKILL.md`
**位置**: 第 20-30 行（命令速查表）vs 各 skill description

**问题**:
```markdown
forge/SKILL.md 第 20-30 行的表格说：

| 命令 | 对应 Skill | 功能 |
|------|-----------|------|
| `/go <需求>` | forge（本文件）| 万能入口，自动路由 |
| `/clarify <需求>` | forge-clarify | 多轮对话厘清需求，生成需求文档 |
...

但是 forge/SKILL.md 本身的第 4-5 行说：
"本 skill 负责 /go 路由和 /onboard 模块速览；其余命令（/clarify /plan /implement /review /test /init-kb /update-kb）
由各自独立的 skill 处理，不经过本 skill。"

这里的表述有歧义：
- "由各自独立的 skill 处理"意思是 forge-clarify skill 处理 /clarify 吗？
- 还是说主 forge skill 内部处理？

表格看起来是说 forge 本身处理 /go 和 /onboard，其他交给各 skill。
但是否需要更明确地说"在 forge skill 中调用对应的 skill"？
```

**建议**: 
在表格下补充说明："表中命令由 forge skill 通过 Skill() 工具调用对应 skill，或由用户直接运行对应 skill"

---

#### 5.2 forge/SKILL.md 的 /go 路由规则与实际工具类型不对应
**文件**: `/Users/kamilxiao/code/forge-plugin/skills/forge/SKILL.md`
**位置**: 第 52-61 行

**问题**:
```markdown
第 54-61 行的路由表说：

| 评估结果 | 路由路径 |
|---------|---------|
| **简单** | 输出一句话方案，调用 `AskUserQuestion` 询问「直接做」还是「走完整流程」 |
| **复杂 + 需求模糊** | 调用 forge-clarify skill |
| **复杂 + 需求清晰** | 调用 forge-plan skill |
| "review"、"检查"、"看一下代码" | 调用 forge-review skill |
| "写测试"、"test" | 调用 forge-test skill |
| "初始化知识库" | 调用 forge-kb skill |

缺少：
- /go 的 simple path 用户选择了"直接做"以后的处理？它调用什么来执行编码？
- 没有 /go 跳转到 /implement 的路由，但用户可能描述的就是已有计划需要执行的情况
```

**建议**: 
补充"用户选择'直接做'后"的处理逻辑。

---

#### 5.3 structured-step-output.md 中"汇总格式"缺少返修建议的说明
**文件**: `/Users/kamilxiao/code/forge-plugin/references/structured-step-output.md`
**位置**: 第 34-61 行

**问题**:
汇总格式的"已知风险 / 建议检查点"节说：
```
**已知风险 / 建议检查点**：
- <风险 1>
- <风险 2>（无则删除本节）
```

但是 forge-executor.md 的 Scope Guard（第 77-80 行）说执行过程中可能会有"计划外改动"需要在汇总中标注。

**矛盾**: 
- structured-step-output.md 没有"偏差记录"节
- 但 forge-executor.md 第 79 行说要"在汇总'偏差记录'节标注"

**位置对照**:
- structured-step-output.md 第 52 行："已知风险 / 建议检查点"
- forge-executor.md 第 111 行："汇总中标记"偏差记录"节"

**建议**: 
在 structured-step-output.md 的汇总格式中补充"偏差记录"节。

---

### 6. 边缘情况处理不完整

#### 6.1 forge-implement 的"状态异常"处理不清晰
**文件**: `/Users/kamilxiao/code/forge-plugin/skills/forge-implement/SKILL.md`
**位置**: 第 47-60 行

**问题**:
第 2 步说若 status 不是 `confirmed`，调用 `AskUserQuestion` 询问是否继续。

但如果用户选"停止"，forge-implement 应该做什么？
- 是否需要更新 task.md 的状态？
- 是否需要通知主 session？

没有明确说。

---

#### 6.2 forge-clarify 修改循环无限制
**文件**: `/Users/kamilxiao/code/forge-plugin/skills/forge-clarify/SKILL.md`
**位置**: 第 144 行

**问题**:
```
若用户选择「需要修改」或在 Other 中输入反馈，更新对应节后重新执行第 7 步自查，
再展示草稿确认，直到用户确认为止。
```

没有说最多修改几轮。会不会出现用户一直选"需要修改"导致死循环？

**建议**: 
补充"最多修改 N 轮"的限制。

---

#### 6.3 forge-executor 的 Scope Guard 逻辑允许"越界"
**文件**: `/Users/kamilxiao/code/forge-plugin/agents/forge-executor.md`
**位置**: 第 77-80 行

**问题**:
```
若需要额外修改计划外的文件 → **先说明原因**，再继续；并在汇总"偏差记录"节标注
若准备修改与本步骤完全无关的模块 → **停止并在汇总中标记**，不要静默越界
```

这给了两种不同处理方式（"继续+标注" vs "停止+标记"），但标准是什么？
- "需要额外修改"和"完全无关的模块"怎么区分？
- 由谁判断？有没有客观标准？

---

#### 6.4 forge-reviewer 的"返修指令"格式模糊
**文件**: `/Users/kamilxiao/code/forge-plugin/agents/forge-reviewer.md`
**位置**: 第 167-179 行

**问题**:
返修指令说：
```
问题 X：
- 文件：`<path>`，位置：<行号/方法名>
- 问题：<具体描述>
- 要求：<具体的修复要求，精确到改什么>
```

"精确到改什么"是什么意思？是不是要给出伪代码？如果返修指令本身不清楚，implementer 怎么修复？

**建议**: 
补充示例，让格式更清晰。

---

### 7. 文档内部引用不一致

#### 7.1 knowledge-load-protocol.md 的路径引用与脚本实际位置不符
**文件**: `/Users/kamilxiao/code/forge-plugin/references/knowledge-load-protocol.md`
**位置**: 第 29-30 行、第 49 行

**问题**:
```markdown
脚本调用说：
  bash <plugin-root>/scripts/kb-load.sh \
    --tier always \
    --kb-path <project-root>/.forge-kb

但实际脚本在 /scripts/kb-load.sh 是否存在？
```

现在让我检查一下脚本。

---

#### 7.2 forge-KB SKILL.md 引用的脚本路径
**文件**: `/Users/kamilxiao/code/forge-plugin/skills/forge-kb/SKILL.md`
**位置**: 第 26 行（/init-kb）

**问题**:
```
bash <plugin-root>/scripts/init-kb.sh --path <project-root>
```

脚本是否真的有 `--path` 参数？

---

## 综合优先级排序

### 🔴 严重级（必须修复）
1. **forge-clarify 边界约定与第9步自相矛盾** — 影响流程设计原则
2. **forge-review 派发 Agent 时没传 requirement.md** — 导致代码审查不完整
3. **forge-executor 汇总格式与 structured-step-output 不一致** — 输出格式冲突

### 🟠 高级（应该修复）
1. forge-implement 对"当前会话模式"的参考指向错误（第109行）
2. forge-plan 与 forge-implement 对执行模式建议的重复判断
3. AGENTS.md 路径说明与实际位置不符
4. forge-deposit 被停用但文档仍引用

### 🟡 中级（建议修复）
1. 各 skill 的工具边界声明缺少 AskUserQuestion
2. forge-test 的输入变更文件列表获取逻辑不明确
3. forge-kb 完成后的后续提示不准确（建议 /plan 但需要先 /clarify）
4. forge/SKILL.md 的 /go 简单路径处理逻辑不清
5. forge-clarify 修改循环无限制

### 🔵 低级（可以改进）
1. 各处文档说明的一致性和清晰度
2. 返修指令格式的示例补充
3. Scope Guard 的越界判断标准

---

## 8. 脚本参数验证结果

### 8.1 init-kb.sh 参数验证✓
**文件**: `/Users/kamilxiao/code/forge-plugin/scripts/init-kb.sh`
**验证结果**: ✓ 正确

脚本确实支持 `--path` 参数（第 31-33 行），forge-kb SKILL.md 第 26 行的调用是正确的。

### 8.2 kb-load.sh 参数验证✓
**文件**: `/Users/kamilxiao/code/forge-plugin/scripts/kb-load.sh`
**验证结果**: ✓ 正确

脚本支持所有必要参数：`--tier`、`--modules`、`--keywords`、`--kb-path`，knowledge-load-protocol.md 中的调用方式正确。

---

## 9. 额外发现的严重问题

### 9.1 forge-review/forge-reviewer 之间对文件的处理不对等
**文件**: 
  - `/Users/kamilxiao/code/forge-plugin/skills/forge-review/SKILL.md` 第 42-57 行
  - `/Users/kamilxiao/code/forge-plugin/agents/forge-reviewer.md` 第 52-60 行

**问题**:
forge-review 派发 forge-reviewer 时：
```
prompt = """
你是 forge-reviewer...

=== plan.md ===
$PLAN_CONTENT

=== 路径参数 ===
...
"""
```

但 forge-reviewer.md 第 52-60 行说：
```
### 第 2 步：读取方案文档

若为方式 A，使用传入的 `plan_content`；否则 Read `plan_path`。

提取：
- 需求描述（验收标准来源）
- 设计决策（判断实现是否背离计划）
- 实现步骤和边界与约定（判断有无越界）

**Read 所有 `changed_files`**，为两个审查阶段做准备。
```

而 forge-reviewer 要做 Spec Compliance 检查（第 75-76 行）：
```
| **功能完整性** | plan.md 实现步骤中的每个改动点是否都已落地 |
| **边界条件** | 需求文档的各场景（含异常路径）是否均有对应处理 |
```

**关键矛盾**：
- "需求文档的各场景"指的是 requirement.md 中的场景
- 但 forge-review 派发时没有传 requirement.md，只传了 plan.md
- forge-reviewer 无法比对需求中的"各场景"与实现是否对应
- **这导致 Stage 1 审查不完整**

**建议修复**:
forge-review SKILL.md 第 42-57 行需要补充：
```
1. Read `plan_path` 同目录的 `requirement.md`，将文件完整内容存为 `$REQUIREMENT_CONTENT`
2. 将 $REQUIREMENT_CONTENT 也嵌入到 prompt 中
3. 更新 prompt 格式：

=== requirement.md ===
$REQUIREMENT_CONTENT

=== plan.md ===
$PLAN_CONTENT
```

---

## 最终问题列表（按严重程度排列）

### 🔴 严重级问题（P0 - 必须立即修复）

**1. forge-clarify 边界约定与第9步自相矛盾**
- 文件: `/Users/kamilxiao/code/forge-plugin/skills/forge-clarify/SKILL.md`
- 位置: 第 160 行 vs 第 227 行
- 问题: "立即调用 forge-plan" vs "不自动触发"
- 影响: 流程设计原则不清
- 修复难度: 低

**2. forge-review 派发 Agent 时没传 requirement.md**
- 文件: `/Users/kamilxiao/code/forge-plugin/skills/forge-review/SKILL.md`
- 位置: 第 42-57 行（派发 prompt）vs `/Users/kamilxiao/code/forge-plugin/agents/forge-reviewer.md` 第 75-76 行（Stage 1 需要 requirement）
- 问题: Spec Compliance 检查无法比对需求中的场景
- 影响: 代码审查不完整，可能遗漏需求不符的bug
- 修复难度: 中等

**3. forge-executor 汇总格式与 structured-step-output 不一致**
- 文件: `/Users/kamilxiao/code/forge-plugin/agents/forge-executor.md` 第 111 行 vs `/Users/kamilxiao/code/forge-plugin/references/structured-step-output.md` 第 34-61 行
- 问题: 要求"偏差记录"节但模板中没有定义
- 影响: 输出格式冲突，implementer 不知道怎么输出
- 修复难度: 低

---

### 🟠 高级问题（P1 - 应该修复）

**4. forge-implement 对"当前会话模式"的参考指向错误**
- 文件: `/Users/kamilxiao/code/forge-plugin/skills/forge-implement/SKILL.md`
- 位置: 第 109 行
- 问题: "参考 forge-executor.md" 但 forge-executor 是 Agent 模式，inline 模式不应该参考它
- 影响: 混淆 inline 和 agent 执行方式
- 修复难度: 低

**5. forge-plan 与 forge-implement 对执行模式建议的判断重复**
- 文件: `/Users/kamilxiao/code/forge-plugin/skills/forge-plan/SKILL.md` 第 135-142 行 vs `/Users/kamilxiao/code/forge-plugin/skills/forge-implement/SKILL.md` 第 66-71 行
- 问题: forge-plan 在 task.md 写推荐模式，forge-implement 又根据步骤数重新判断
- 影响: 推荐模式可能被忽视，或重复计算
- 修复难度: 中等

**6. AGENTS.md 路径说明与实际位置不符**
- 文件: `/Users/kamilxiao/code/forge-plugin/AGENTS.md`
- 位置: 第 11 行
- 问题: "skills/forge/references/agent-prompts/" 但实际是 "agents/"
- 影响: 文档维护者找错位置
- 修复难度: 低

**7. forge-deposit 被停用但文档仍引用**
- 文件: `/Users/kamilxiao/code/forge-plugin/skills/_inactive/forge-deposit.SKILL.md` vs `/Users/kamilxiao/code/forge-plugin/AGENTS.md` 第 15 行、`/Users/kamilxiao/code/forge-plugin/agents/forge-executor.md` 第 105 行
- 问题: 死链、混淆用户
- 影响: 用户看到 "/deposit" 建议但运行失败
- 修复难度: 低

---

### 🟡 中级问题（P2 - 建议修复）

**8. forge-clarify 工具边界声明缺少 AskUserQuestion**
- 文件: `/Users/kamilxiao/code/forge-plugin/skills/forge-clarify/SKILL.md` 第 17 行
- 问题: 声明里没提 AskUserQuestion，但全文广泛使用
- 影响: 权限管理不清
- 修复难度: 低

**9. forge-plan 工具边界声明缺少 AskUserQuestion**
- 文件: `/Users/kamilxiao/code/forge-plugin/skills/forge-plan/SKILL.md` 第 18 行
- 问题: 同上
- 修复难度: 低

**10. forge-implement 工具边界声明缺少 AskUserQuestion**
- 文件: `/Users/kamilxiao/code/forge-plugin/skills/forge-implement/SKILL.md` 第 15 行
- 问题: 同上
- 修复难度: 低

**11. forge-test 的输入变更文件列表获取逻辑不明确**
- 文件: `/Users/kamilxiao/code/forge-plugin/skills/forge-test/SKILL.md` 第 19-24 行
- 问题: 没有像 forge-review 那样说"优先级：传入 vs git diff vs 手动"
- 影响: 不清楚怎么从 implementer 获取变更文件列表
- 修复难度: 中等

**12. forge-kb /init-kb 完成后后续提示不准确**
- 文件: `/Users/kamilxiao/code/forge-plugin/skills/forge-kb/SKILL.md` 第 88-102 行
- 问题: 建议用户直接 /plan，但需要先 /clarify 生成 requirement.md
- 影响: 用户按提示操作会失败
- 修复难度: 低

**13. forge/SKILL.md 的 /go 简单路径处理逻辑不清**
- 文件: `/Users/kamilxiao/code/forge-plugin/skills/forge/SKILL.md` 第 52-77 行
- 问题: 用户选择"直接做"后没有说调用什么来执行编码
- 影响: 路由逻辑不完整
- 修复难度: 中等

**14. forge-clarify 修改循环无最大轮次限制**
- 文件: `/Users/kamilxiao/code/forge-plugin/skills/forge-clarify/SKILL.md` 第 144 行
- 问题: "直到用户确认为止"可能陷入死循环
- 影响: 用户体验不佳
- 修复难度: 低

---

### 🔵 低级问题（P3 - 可以改进）

**15. structured-step-output.md 汇总格式缺少"偏差记录"节定义**
- 文件: `/Users/kamilxiao/code/forge-plugin/references/structured-step-output.md` 第 34-61 行
- 问题: forge-executor.md 说要标注偏差，但模板中没有这一节
- 修复难度: 低

**16. forge-executor 的 Scope Guard 越界判断标准不清**
- 文件: `/Users/kamilxiao/code/forge-plugin/agents/forge-executor.md` 第 77-80 行
- 问题: "需要额外修改" vs "完全无关"的区分标准模糊
- 修复难度: 中等

**17. forge-reviewer 的返修指令格式示例不足**
- 文件: `/Users/kamilxiao/code/forge-plugin/agents/forge-reviewer.md` 第 167-179 行
- 问题: "精确到改什么"的含义不清，没有具体示例
- 修复难度: 低

**18. /go 路由表说明不够清晰**
- 文件: `/Users/kamilxiao/code/forge-plugin/skills/forge/SKILL.md` 第 20-30 行
- 问题: 表格与文本描述之间有歧义
- 修复难度: 低

---

## 审查总结

**总计发现 18 个问题**：
- 🔴 严重级（必须修）：3 个
- 🟠 高级（应该修）：4 个  
- 🟡 中级（建议修）：7 个
- 🔵 低级（可改进）：4 个

**最紧迫的三个修复**（按优先级）：
1. **forge-review 需传 requirement.md** — 直接影响代码审查的准确性，影响大
2. **forge-clarify 边界约定矛盾** — 涉及流程设计原则，需要高层决策
3. **forge-executor 汇总格式** — 影响实现输出的结构，需要立即对齐

