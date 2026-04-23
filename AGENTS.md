# AGENTS.md

本文件描述 Forge 插件中各 Agent 的职责和工具边界，供 Claude Code 在 fork 子 Agent 时参考。

## 已定义的 Agent

详细的 Agent prompt 存放在 `skills/forge/references/agent-prompts/` 目录：

| Agent | 文件 | 职责 | 工具边界 |
|-------|------|------|---------|
| planner | `agent-prompts/planner.md` | 需求分析、Feature 文档、执行计划 | Read / Glob / Grep（只读）|
| implementer | `agent-prompts/implementer.md` | 按计划执行编码 | Read / Write / Edit / Bash / Glob / Grep |
| reviewer | `agent-prompts/reviewer.md` | 代码审查，输出 PASS/WARN/BLOCK | Read / Glob / Grep（无 Bash/Write）|
| test-writer | `agent-prompts/test-writer.md` | 生成并运行测试 | Read / Write / Edit / Bash / Glob / Grep |
| depositor | `agent-prompts/depositor.md` | 沉淀经验到 `.forge-kb/` | Read / Write / Edit（只写 .forge-kb/）|
| kb-builder | `agent-prompts/kb-builder.md` | 初始化和更新知识库 | Read / Write / Edit / Bash / Glob / Grep |

## 调用方式

Agent 通过 SKILL.md 中的 task-router 路由后，由主 Claude 使用 `Agent` tool 的 `subagent_type` fork 出来，并将对应 `agent-prompts/<name>.md` 的内容作为 `prompt` 参数传入。

每个 Agent prompt 顶部都有 `<SUBAGENT-GUARD>` 块，确保被 fork 的子 Agent 跳过路由逻辑、直接执行分配的任务。
