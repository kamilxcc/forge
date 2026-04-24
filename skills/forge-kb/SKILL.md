---
name: forge-kb
description: >
  ⚠️ 已废弃（DEPRECATED）：此 skill 不再使用。知识库基础设施（.forge-kb/）已移除，
  项目上下文改由目标项目根目录的 CLAUDE.md 承载，Claude Code 会在 session 启动时自动加载。
  /init-kb 和 /update-kb 命令已停用，无需执行。
---

# forge-kb — 知识库管理（已废弃）

> ⚠️ **此 skill 已废弃，不再使用。**
>
> 知识库基础设施（`.forge-kb/`）已从 forge-plugin 中移除。项目上下文（术语表、模块路径、编码规范）
> 请直接写入目标项目根目录的 `CLAUDE.md`，Claude Code 会在 session 启动时自动加载。
>
> `/init-kb` 和 `/update-kb` 命令已停用，无需执行。

## 你的角色

forge-kb 负责两件事：
1. `/init-kb`：扫描目标项目目录、推断模块结构，**引导用户确认后填充最小存活集**（glossary + project + module-map + modules 骨架）
2. `/update-kb --since=<N>d`：分析最近变更，推断需要更新的知识库文件，展示给用户确认后执行

工具边界：Read / Write / Edit / Glob / Grep / Bash（只用于 git 命令、find 命令和 init-kb.sh）

---

## 执行流程：/init-kb

### 第 0 步：确认目标目录和项目名称

询问用户：
```
请提供两条信息：
1. 目标项目的根目录路径（如 /Users/xxx/code/my-project）
2. 项目名称（如 "my-project"，用于知识库路径记录）
```

收到后，将目标目录记为 `<target-dir>`，项目名称记为 `<project-name>`。

---

### 第 1 步：扫描目录结构，推断模块划分

```bash
find <target-dir> -maxdepth 3 -type d | sort
```

同时扫描关键配置文件，辅助判断模块依赖：
```bash
# Android/Gradle 项目
find <target-dir> -maxdepth 2 -name "build.gradle" -o -name "build.gradle.kts" | head -20
# Node/前端项目
find <target-dir> -maxdepth 2 -name "package.json" | head -10
# 通用：找模块入口
find <target-dir> -maxdepth 4 -name "*.gradle.kts" -o -name "*.gradle" | head -20
```

基于扫描结果，Claude 自动分析并推断：

**推断内容：**
1. **大模块划分**（3-8 个）：识别业务模块/功能模块及对应目录
2. **设计模式**：根据目录命名（`viewmodel/`、`repository/`、`presenter/`、`usecase/` 等）推断
3. **模块依赖关系**：根据目录结构和 gradle/package 配置判断模块间依赖

**向用户展示推断结果并确认：**

```
我分析了你的目录结构，推断如下：

📦 架构模式：MVVM + Repository Pattern
（依据：发现 viewmodel/、repository/、usecase/ 目录）

📂 模块划分：
  - feed       →  feature/feed/          信息流模块
  - chat       →  feature/chat/          聊天模块
  - common     →  lib/common/            公共组件库
  - network    →  lib/network/           网络层

🔗 模块依赖：
  - feed    →  common（公共组件）
  - feed    →  network（网络请求）
  - chat    →  common（公共组件）
  - chat    →  network（网络请求）

是否正确？可以：
1. 直接确认
2. 修改某个模块的名称/路径/描述
3. 增加/删除模块
4. 修改依赖关系
```

等待用户确认或修改，将最终结果记为「确认的模块列表」。

---

### 第 2 步：运行初始化脚本

```bash
bash <plugin-root>/scripts/init-kb.sh \
  --path <target-dir> \
  --project-name <project-name> \
  --plugin-root <plugin-root>
```

若已存在（exit code 1），询问用户是否 `--force`。

---

### 第 3 步：填充 project.yaml

Read `.forge-kb/meta/project.yaml`，然后向用户逐项确认基本字段：

```
我帮你把 project.yaml 的核心字段填好，需要你提供几条信息：

1. **一句话描述**：（如 "腾讯 QQ Android 客户端"）
2. **平台**：android / ios / web / backend / cross-platform
3. **主要语言**：kotlin / java / swift / typescript / python ...
4. **编译命令**：（如 "./gradlew assembleDebug"）
5. **架构特殊点**：（可选，填代码里看不出来的，如"不用 Jetpack Navigation"）
```

收到用户回答后，Edit `.forge-kb/meta/project.yaml`：
- 填入用户提供的基本信息
- 将第 1 步确认的模块列表填入 `architecture.modules`
- 将确认的依赖关系填入 `architecture.dependencies`
- `architecture.pattern` 填入第 1 步推断的设计模式

---

### 第 4 步：引导头脑风暴 glossary.yaml

展示以下提示，然后调用 `AskUserQuestion`：

```
现在最重要的一步：填 glossary.yaml（术语表）。

这是整个知识库里 ROI 最高的文件——几百 tokens 消灭 80% AI 幻觉。
```

然后调用 `AskUserQuestion`：

- `header`：「填写方式」
- `multiSelect: false`
- `options`：
  - `label: 直接说黑话` / `description: 你来说术语，我来填格式。如：消息频道叫 ChannelManager，...`
  - `label: 贴代码或包名` / `description: 你贴一段代码或包名列表，我来推断术语映射`
  - `label: 跳过` / `description: 先用空的，以后再填（不推荐）`

根据用户输入，向 `.forge-kb/meta/glossary.yaml` 添加条目。
每添加一批，展示已填内容让用户确认，再继续。

目标：让用户在 10-20 分钟内完成 10-20 条核心术语。

---

### 第 5 步：预填 module-map.yaml，生成 modules 骨架

**5a. 用第 1 步确认的模块列表填充 module-map.yaml：**

Edit `.forge-kb/meta/module-map.yaml`，将示例条目替换为确认的模块：

```yaml
modules:
  <name>:
    paths:
      - "**/<path>/**"
    description: "<desc>"
    owners: []
    kb_files:
      - "modules/<name>/index.md"
```

**5b. 为每个模块生成 modules/<name>/index.md 骨架：**

对「确认的模块列表」中的每个模块，Write `.forge-kb/modules/<name>/index.md`：

```markdown
> [!auto-generated] 生成于 <today-date>

# <name> — <desc>

## 目录位置

- 主目录：`<path>/`
<!-- 扫描 <path>/ 下一级子目录，列出关键目录 -->

## 模块依赖

<!-- 从 project.yaml 的 dependencies 中提取与本模块相关的条目 -->
- 依赖 → `<dep-module>`（<reason>）

## 架构模式

<pattern>

## 关键入口文件

<!-- 扫描 <path>/ 下的顶层文件，列出最可能是入口的 2-4 个文件 -->

## 注意事项

> [!human-maintained]
（留空，由人工补充代码中读不出来的约束、坑点、隐性规范）
```

---

### 第 6 步：完成提示

```
✅ 知识库初始化完成！

已生成：
- meta/project.yaml      — 项目元信息 + 模块架构
- meta/glossary.yaml     — N 条术语映射
- meta/module-map.yaml   — N 个模块路径映射
- modules/*/index.md     — N 个模块骨架（含目录指引和依赖关系）

知识库路径已记录在：
  <plugin-root>/work/<project-name>/.kb-path

下一步可以：
- /clarify <需求描述> — 多轮对话精化需求文档
- /go <需求描述> — 使用智能路由，自动判断执行流程
- /onboard <模块名> — 深入了解某个模块
```

---

## 执行流程：/update-kb

### 第 1 步：定位知识库

读取 `<plugin-root>/work/<project-name>/.kb-path` 获取知识库路径。
若文件不存在，提示用户先运行 `/init-kb`。

### 第 2 步：确定变更范围

```bash
# 解析 --since 参数，转换为 git commit 数
# --since=7d → 过去 7 天的 commit 数（用 git log 估算）
# --since=N → 过去 N 天
git log --oneline --since="N days ago" | wc -l
git diff --name-only HEAD~<N>
```

展示变更文件列表给用户。

### 第 3 步：用 module-map.yaml 匹配受影响模块

Read `.forge-kb/meta/module-map.yaml`，将变更文件路径与各模块的 `paths` 做 glob 匹配。

```
检测到以下模块受到影响：
- channel（匹配 3 个文件）
- feed（匹配 5 个文件）

对应的知识库文件：
- modules/channel/index.md
- modules/feed/index.md
```

### 第 4 步：展示建议更新点，等待用户确认

对每个受影响的模块，Read 对应的 `index.md`，与变更文件做对比分析，生成建议：

```
以下知识库内容可能需要更新：

**modules/channel/index.md**
- 检测到 ChannelDispatcher.kt 有较大改动，"架构总览"节可能需要更新
- 新增了 ChannelSubscriberV2.kt，"关键类速查"节缺少这个类

确认后我来更新，或你可以指定只更新某个模块：
[全部更新] [仅 channel] [仅 feed] [取消]
```

### 第 5 步：执行更新

用户确认后，逐模块更新：
- **auto 区域**（`> [!auto-generated]`）：可直接覆盖
- **human-maintained 区域**（`> [!human-maintained]`）：**只追加，不覆盖**，并在末尾标注「需人工审核」

每个文件更新后，展示 diff 让用户确认。

---

## 重要约束

- **不得修改 `.forge-kb/` 以外的任何文件**（`.kb-path` 状态文件除外）
- **human-maintained 块不可覆盖**，若需修改，展示建议内容后由用户决定
- `/update-kb` 的自动分析是参考，不是 ground truth——最终内容由用户确认
