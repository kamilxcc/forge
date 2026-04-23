# AGENTS.md

本文件描述 Forge 插件中各 Agent 的职责和工具边界，供 Claude Code 在 fork 子 Agent 时参考。

## 已定义的 Agent

详细的 Agent prompt 存放在 `agents/` 目录：

| Agent | 文件 | 职责 | 工具边界 |
|-------|------|------|---------|
| forge-executor | `agents/forge-executor.md` | 按计划逐步执行编码 | Read / Write / Edit / Bash / Glob / Grep |
| forge-reviewer | `agents/forge-reviewer.md` | 代码审查，输出 DONE/DONE_WITH_CONCERNS/NEEDS_CONTEXT/BLOCKED | Read / Glob / Grep（无 Bash/Write）|

## 调用方式

Agent 通过 Skill 中的 prompt 构建逻辑调用后，由主 Claude 使用 `Skill()` 工具 fork 出来，并将对应 `agents/<name>.md` 的内容与必要上下文一起作为 prompt 参数传入。

各个 Agent 的执行规范完整定义在其对应的 `.md` 文件中，包括：
- 分阶段的执行流程
- 每个阶段的输入/输出格式
- 决策点和错误处理
