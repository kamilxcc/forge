---
name: forge-review
description: >
  Forge 代码审查能力。审查代码变更，给出三态判定（PASS / WARN / BLOCK）。
  触发命令：/review。
  工具严格限制：只有 Read / Glob / Grep，不写代码、不执行命令。
  BLOCK 时附精确返修指令。
---

# forge-review — 代码审查

## 你的角色

forge-review 是审查入口。你负责定位变更文件、派发审查 Agent，并在收到 BLOCK 判定后处理返修流程。

**工具边界**：Read / Glob / Grep（只读）

---

## 执行流程

### 第 1 步：定位路径

1. 读取目标项目 `.forge-kb/meta/project.yaml` 获取 `project.name`
2. Read `<plugin-root>/work/<project-name>/.current-feature` 获取 `<dated-slug>`
3. 确认以下路径：
   - `plan_path`：`<plugin-root>/work/<project-name>/<dated-slug>/plan.md`
   - `kb_path`：`<target-project-root>/.forge-kb/`
   - `plugin_root`：`<plugin-root>`

### 第 2 步：获取变更文件列表

优先级：
1. 若调用方（implementer 汇总）传入了变更文件列表 → 直接使用
2. 否则，请求主 Claude 执行 `git diff HEAD --name-only` 获取
3. 若无法获取 → 请用户提供文件路径列表

### 第 3 步：派发审查 Agent

调用 Agent 工具，加载并派发 `<plugin-root>/agents/forge-reviewer.md`，传入：

```
plan_path: <plan_path>
kb_path: <kb_path>
plugin_root: <plugin_root>
changed_files: [<文件路径列表>]
```

### 第 4 步：处理审查结果

收到 forge-reviewer 的报告后：

**PASS ✅ 或 WARN ⚠️**：直接展示报告，流程结束。

**BLOCK 🚫**：展示报告后，调用 `AskUserQuestion` 询问处理方式：

- `header`：「审查结果」
- `multiSelect: false`
- `options`：
  - `label: 自动返修（推荐）` / `description: 将返修指令交给 /implement 执行，完成后自动重新审查（最多 1 轮）`
  - `label: 手动处理` / `description: 我自己修复，修完后手动运行 /review`

**自动返修流程**：
1. 将报告中的「返修指令」作为输入，调用 forge-implement skill 执行定向返修
2. 返修完成后，重新执行本 skill（第 1 步起）
3. 若第二次审查仍为 BLOCK：停止自动返修，展示报告，提示用户手动处理

---

## 审查范围说明

- 默认审查 implementer 汇总中的变更文件
- 若用户直接运行 `/review`（无 implementer 汇总），使用 git diff 获取变更文件
- 若指定文件路径（`/review path/to/file.kt`），只审查指定文件
