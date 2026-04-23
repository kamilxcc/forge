# forge-plugin

**Forge** 是一个 Claude Code 插件，为大型项目提供 AI 工程化工作流：  
`/plan` → 用户确认 → `/implement` → `/review` → `/test` → `/deposit`

## 安装

### 1. 将插件目录加入 Claude Code

在 `~/.claude/settings.json`（全局）或目标项目的 `.claude/settings.json`（项目级）中添加所有 skill 目录：

```json
{
  "skills": [
    "/path/to/forge-plugin/skills/forge",
    "/path/to/forge-plugin/skills/forge-plan",
    "/path/to/forge-plugin/skills/forge-implement",
    "/path/to/forge-plugin/skills/forge-review",
    "/path/to/forge-plugin/skills/forge-test",
    "/path/to/forge-plugin/skills/forge-deposit",
    "/path/to/forge-plugin/skills/forge-kb"
  ]
}
```

### 2. 挂载 Hooks（可选，但强烈推荐）

在**目标项目**的 `.claude/settings.json` 中配置：

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "bash /path/to/forge-plugin/hooks/post-tool-use.sh"
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash /path/to/forge-plugin/hooks/stop.sh"
          }
        ]
      }
    ]
  }
}
```

> Hook 作用：`post-tool-use.sh` 记录每次文件修改，`stop.sh` 会话结束时提示运行 `/deposit` 沉淀经验。

### 3. 初始化目标项目的知识库

在目标项目根目录运行：

```bash
bash /path/to/forge-plugin/scripts/init-kb.sh
```

按照生成的 `.forge-kb/README.md` 填充最小存活集（`glossary.yaml`、`project.yaml`、`module-map.yaml`）。

## 命令速查

| 命令 | 功能 |
|------|------|
| `/go <需求>` | 万能入口，自动路由 |
| `/plan <需求>` | 生成 Feature 文档 + 执行计划 |
| `/implement` | 按计划执行编码 |
| `/review` | 代码审查（PASS/WARN/BLOCK） |
| `/test` | 生成并运行测试 |
| `/deposit` | 沉淀本次会话经验到知识库 |
| `/onboard <模块>` | 快速了解模块架构 |
| `/init-kb` | 初始化项目知识库 |
| `/update-kb` | 增量更新知识库 |

## 目录结构

```
forge-plugin/
├── hooks/                    # Claude Code Hooks（挂载到目标项目）
│   ├── post-tool-use.sh      # 记录文件修改路径
│   └── stop.sh               # 会话结束提示 /deposit
├── scripts/                  # 工具脚本
│   ├── init-kb.sh            # 初始化知识库
│   └── kb-load.sh            # 加载知识库上下文
├── references/               # 所有 skill 共用的 pattern 片段
│   ├── knowledge-load-protocol.md
│   └── structured-step-output.md
├── agents/                   # 未来扩展
├── commands/                 # 未来扩展
├── docs/                     # 文档
├── tests/                    # 测试
└── skills/
    ├── forge/                # 编排层：/go 路由 + /onboard
    │   └── templates/kb/     # 目标项目 .forge-kb/ 初始模板
    ├── forge-plan/           # /plan：需求规划
    ├── forge-implement/      # /implement：编码执行
    ├── forge-review/         # /review：代码审查
    ├── forge-test/           # /test：测试编写
    ├── forge-deposit/        # /deposit：经验沉淀
    └── forge-kb/             # /init-kb + /update-kb：知识库管理
```
