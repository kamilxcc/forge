---
name: forge-review
description: >
  当实现完成、用户需要代码审查时触发，例如运行 /review、"审查一下"、"看看代码有没有问题"。
  执行两阶段审查：第一阶段检查规格合规（代码是否符合 plan.md）；第二阶段检查代码质量（架构、内存、线程）。
  输出四值判定：DONE / DONE_WITH_CONCERNS / NEEDS_CONTEXT / BLOCKED。
  工具严格限制：只有 Read / Glob / Grep，不写代码、不执行命令。
---

# forge-review — 代码审查

## 你的角色

forge-review 是审查入口。你负责定位变更文件、派发审查 Agent，并在收到 BLOCK 判定后处理返修流程。

**工具边界**：Read / Glob / Grep（只读）

---

## 执行流程

### 第 0.5 步：-l Flag 检测（按需）

若用户命令包含 `-l` flag（如 `/review -l`）：

1. 运行 `bash <plugin-root>/scripts/list-features.sh --project-name <project-name> --plugin-root <plugin-root>`
2. 按 `<plugin-root>/references/feature-selector.md` 展示选择器，得到 `active_slug`
3. 后续所有从 `.current-feature` 读取 `dated-slug` 的地方，**统一替换为 `active_slug`**

若命令不含 `-l`，跳过本步。

---

### 第 1 步：定位路径

1. 获取 `<project-name>`：使用当前工作目录的最后一段路径名
2. Read `<plugin-root>/work/<project-name>/.current-feature` 获取 `<dated-slug>`
3. 确认以下路径：
   - `plan_path`：`<plugin-root>/work/<project-name>/<dated-slug>/plan.md`
   - `requirement_path`：`<plugin-root>/work/<project-name>/<dated-slug>/requirement.md`

### 第 2 步：获取变更文件列表

优先级：
1. 若调用方（implementer 汇总）传入了变更文件列表 → 直接使用
2. 否则，请求主 Claude 执行 `git diff HEAD --name-only` 获取
3. 若无法获取 → 请用户提供文件路径列表

### 第 3 步：派发审查 Agent

**上下文隔离原则**：子 Agent 不能依赖当前会话历史，所有必要内容必须内嵌到 prompt 中。

**构建 Agent prompt 步骤**：
1. Read `plan_path`，将完整内容存为 `$PLAN_CONTENT`
2. Read `requirement_path`，将完整内容存为 `$REQUIREMENT_CONTENT`
3. 将以下完整 prompt 传给 Agent：

```
你是 forge-reviewer，执行两阶段代码审查任务。

=== requirement.md ===
$REQUIREMENT_CONTENT

=== plan.md ===
$PLAN_CONTENT

=== 路径参数 ===
plugin_root: <plugin_root>
changed_files: [<文件路径列表>]

审查规范详见 <plugin_root>/agents/forge-reviewer.md，按其中的流程执行。
```

### 第 4 步：处理审查结果

收到 forge-reviewer 的报告后：

**DONE ✅**：直接展示报告，流程结束。

**DONE_WITH_CONCERNS ⚠️**：展示报告（含 WARN 条目），提示用户可选择性跟进，流程结束。

**NEEDS_CONTEXT 🔍**：展示报告，向用户说明缺少哪些上下文，请用户补充后重新运行 `/review`。

**BLOCKED 🚫**：展示报告后，调用 `AskUserQuestion` 询问处理方式：

- `header`：「审查结果」
- `multiSelect: false`
- `options`：
  - `label: 自动返修（推荐）` / `description: 将返修指令交给 /implement 执行，完成后自动重新审查（最多 1 轮）`
  - `label: 手动处理` / `description: 我自己修复，修完后手动运行 /review`

**自动返修流程**：
1. 将报告中的「返修指令」作为输入，调用 forge-implement skill 执行定向返修
2. 返修完成后，重新执行本 skill（第 1 步起）
3. 若第二次审查仍为 BLOCKED：停止自动返修，展示报告，提示用户手动处理

---

## 审查范围说明

- 默认审查 implementer 汇总中的变更文件
- 若用户直接运行 `/review`（无 implementer 汇总），使用 git diff 获取变更文件
- 若指定文件路径（`/review path/to/file.kt`），只审查指定文件
