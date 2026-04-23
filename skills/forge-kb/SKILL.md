---
name: forge-kb
description: >
  Forge 知识库管理能力。负责初始化和更新目标项目的 .forge-kb/ 知识库。
  触发命令：/init-kb 或 /update-kb --since=<N>d。
  /init-kb：引导用户填充最小存活集（project.yaml + glossary.yaml + module-map.yaml）。
  /update-kb：分析最近变更，推断需要更新的知识库文件，展示给用户确认后执行。
---

# forge-kb — 知识库管理

## 你的角色

forge-kb 负责两件事：
1. `/init-kb`：在 `init-kb.sh` 创建好目录结构后，**引导用户填充最小存活集**（glossary + project + module-map）
2. `/update-kb --since=<N>d`：分析最近变更，推断需要更新的知识库文件，展示给用户确认后执行

工具边界：Read / Write / Edit / Glob / Grep / Bash（只用于 git 命令和 init-kb.sh）

---

## 执行流程：/init-kb

### 第 1 步：运行初始化脚本

```bash
bash <plugin-root>/scripts/init-kb.sh --path <project-root>
```

若已存在（exit code 1），询问用户是否 `--force`。

### 第 2 步：引导填充 meta/project.yaml

Read `.forge-kb/meta/project.yaml`，然后向用户逐项确认：

```
我帮你把 project.yaml 的核心字段填好，需要你提供几条信息：

1. **项目名称**：（如 "AndroidQQ"）
2. **一句话描述**：（如 "腾讯 QQ Android 客户端"）
3. **平台**：android / ios / web / backend / cross-platform
4. **主要语言**：kotlin / java / swift / typescript / python ...
5. **编译命令**：（如 "./gradlew assembleDebug"）
6. **架构特殊点**：（可选，填代码里看不出来的，如"不用 Jetpack Navigation"）
```

收到用户回答后，Edit `.forge-kb/meta/project.yaml` 填入信息。

### 第 3 步：引导头脑风暴 glossary.yaml

展示以下提示，帮助用户快速启动：

```
现在最重要的一步：填 glossary.yaml（术语表）。

这是整个知识库里 ROI 最高的文件——几百 tokens 消灭 80% AI 幻觉。

启动方法（选一种）：
A. 你来说黑话，我来填格式。
   直接说："消息频道叫 ChannelManager，小世界叫 MiniWorldFragment，..."
   
B. 你贴一段代码或包名列表，我来推断术语映射。

C. 跳过，先用空的，以后再填。（不推荐，但可以）

你选哪种？
```

根据用户输入，向 `.forge-kb/meta/glossary.yaml` 添加条目。
每添加一批，展示已填内容让用户确认，再继续。

目标：让用户在 10-20 分钟内完成 10-20 条核心术语。

### 第 4 步：登记 module-map.yaml

```
最后一步：在 module-map.yaml 里登记 2-3 个核心模块的路径。

这让 Forge 在执行任务时自动加载对应模块的知识，不用每次手动指定。

示例格式：
  feed-square:
    paths: ["**/feedsquare/**"]
    description: "频道帖子广场"

你们项目里，最常改的 2-3 个模块叫什么，代码在哪个目录下？
```

收到用户回答后，Edit `.forge-kb/meta/module-map.yaml` 添加条目。

### 第 5 步：完成提示

```
✅ 知识库最小存活集初始化完成！

已填写：
- meta/project.yaml — 项目元信息
- meta/glossary.yaml — N 条术语映射
- meta/module-map.yaml — N 个模块

下一步可以：
- /plan <需求描述> — 开始你的第一个功能
- /onboard <模块名> — 深入了解某个模块

后续随时可以运行 /deposit 沉淀经验，或 /update-kb 更新模块文档。
```

---

## 执行流程：/update-kb

### 第 1 步：确定变更范围

```bash
# 解析 --since 参数，转换为 git commit 数
# --since=7d → 过去 7 天的 commit 数（用 git log 估算）
# --since=N → 过去 N 天
git log --oneline --since="N days ago" | wc -l
git diff --name-only HEAD~<N>
```

展示变更文件列表给用户。

### 第 2 步：用 module-map.yaml 匹配受影响模块

Read `.forge-kb/meta/module-map.yaml`，将变更文件路径与各模块的 `paths` 做 glob 匹配。

```
检测到以下模块受到影响：
- channel（匹配 3 个文件）
- feed（匹配 5 个文件）

对应的知识库文件：
- modules/channel/index.md
- modules/feed/index.md
```

### 第 3 步：展示建议更新点，等待用户确认

对每个受影响的模块，Read 对应的 `index.md`，与变更文件做对比分析，生成建议：

```
以下知识库内容可能需要更新：

**modules/channel/index.md**
- 检测到 ChannelDispatcher.kt 有较大改动，"架构总览"节可能需要更新
- 新增了 ChannelSubscriberV2.kt，"关键类速查"节缺少这个类

确认后我来更新，或你可以指定只更新某个模块：
[全部更新] [仅 channel] [仅 feed] [取消]
```

### 第 4 步：执行更新

用户确认后，逐模块更新：
- **auto 区域**（`> [!auto-generated]`）：可直接覆盖
- **human-maintained 区域**（`> [!human-maintained]`）：**只追加，不覆盖**，并在末尾标注「需人工审核」

每个文件更新后，展示 diff 让用户确认。

---

## 重要约束

- **不得修改 `.forge-kb/` 以外的任何文件**
- **human-maintained 块不可覆盖**，若需修改，展示建议内容后由用户决定
- `/update-kb` 的自动分析是参考，不是 ground truth——最终内容由用户确认
