---
name: forge-deposit
description: >
  Forge 经验沉淀能力。从本次会话的代码修改中提炼可复用经验，写入知识库。
  触发命令：/deposit 或 /deposit <描述>。
  输入：.forge-kb/.state/modified-files.txt（由 PostToolUse Hook 记录）。
  输出：.forge-kb/experience/rules/ 或 experience/cases/ 下的新条目。
---

# forge-deposit — 经验沉淀

## 你的角色

forge-deposit 从本次会话的代码修改中，提炼可复用的经验，写入知识库的 `experience/` 目录。

<WRITE-SCOPE>
严格限制：你只能写入 `.forge-kb/` 目录下的文件。
绝对禁止修改任何业务代码文件。
</WRITE-SCOPE>

**工具边界**：Read / Write / Edit / Glob / Grep（业务代码只读，`.forge-kb/` 可写）

---

## 输入

- `.forge-kb/.state/modified-files.txt`（由 PostToolUse Hook 记录的本次修改文件列表）
- 用户描述（可选，`/deposit <描述>` 时传入）
- `.forge-kb/` 知识库上下文

---

## 执行流程

### 第 1 步：读取修改文件列表

```
Read .forge-kb/.state/modified-files.txt
```

若文件不存在或为空：
- 若用户提供了 `/deposit <描述>`，提示：
  ```
  ⚠️  modified-files.txt 为空或不存在，无法自动推断变更范围。
      请告诉我：本次主要修改了哪些文件或模块？
      （或者直接描述踩到的坑/学到的经验，我来帮你整理成规则）
  ```
  等待用户回复后继续。
- 若用户没有提供描述，输出提示后停止。

### 第 2 步：加载知识库上下文

按 `<plugin-root>/references/knowledge-load-protocol.md` 执行 Always-On 层加载。

### 第 3 步：分析修改，识别经验信号

逐一 Read `modified-files.txt` 中的文件（跳过不存在的文件）。

识别以下类型的经验信号：

| 信号类型 | 识别方式 | 对应规则类型 |
|---------|---------|------------|
| 踩坑/绕坑 | 注释中有 "// NOTE:"、"// FIXME:"、"// HACK:"、"// workaround:" 或代码里有不直观的绕开逻辑 | risk |
| 隐性约束 | 代码中存在"不能在 X 时调用"、"必须先…才能…"的逻辑 | risk |
| 推荐模式 | 新增了统一的工具方法/封装，值得推广 | pattern |
| 设计背景 | Feature 文档中的"设计决策"节有记录 | context |

同时关注：
- 是否有废弃的旧 API 被替换（→ glossary 更新建议）
- 是否有新的跨模块协作路径（→ modules 文档更新建议）

### 第 4 步：生成候选经验条目

将识别到的经验信号整理成 YAML 格式的候选条目（见模板）。

**一次性展示所有候选条目**，等待用户一键确认：

```
📋 从本次修改中发现以下可沉淀的经验，请确认：

---
候选 1（来源：ChannelDispatcher.kt）：

  id: channel-003
  type: risk
  level: warn
  module: channel
  keywords: [ChannelDispatcher, async, await]
  alert: "dispatch() 已改为异步，调用方必须 .await()"
  body: |
    2024-12 dispatch() 从同步改为异步，返回 Deferred<Boolean>。
    旧的同步调用会编译失败，需要在协程作用域中 .await()。

---
候选 2（来源：设计决策）：

  id: channel-004
  type: context
  level: info
  ...

---

全部确认写入？[全部] [选择] [取消]
（选择时输入序号，如：1 3）
```

### 第 5 步：写入知识库

用户确认后，将选中的条目写入对应的 rules 文件。

**文件选择规则**：
- 按 `module` 字段，写入 `.forge-kb/experience/rules/<module>-rules.yaml`
- 若文件不存在，新建（加文件头注释说明格式）
- 若已存在，在 `rules:` 列表末尾追加，不覆盖现有内容

追加格式：

```yaml
  # [Forge auto-generated] deposited on YYYY-MM-DD
  - id: <id>
    type: <type>
    level: <level>
    module: <module>
    keywords: [<kw1>, <kw2>]
    alert: "<alert>"
    body: |
      <body>
    source: auto
    created_by: forge-depositor
    created_at: YYYY-MM-DD
```

若用户认为某条经验更适合写成详细案例（而非规则），写入 `.forge-kb/experience/cases/<slug>.md`，格式参考 Feature 文档但更侧重踩坑经过和解决方案。

### 第 6 步：清空 modified-files.txt

写入完成后：
```
: > .forge-kb/.state/modified-files.txt
```
（为下次会话准备干净的状态）

### 第 7 步：输出沉淀摘要

```
✅ 经验沉淀完成！

写入位置：
- .forge-kb/experience/rules/channel-rules.yaml — 新增 2 条规则
- .forge-kb/experience/rules/network-rules.yaml — 新增 1 条规则

沉淀内容摘要：
- [channel-003] dispatch() 已改为异步，调用方必须 .await()
- [channel-004] ChannelSubscriberV2 替代旧的 ChannelSubscriber
- [network-002] 上传接口禁用重试，用 Request.tag(NoRetry) 标记

💡 顺带建议：
- glossary.yaml 可新增 "频道订阅 V2" → ChannelSubscriberV2 的映射
- modules/channel/index.md 的"近期重要变更"节可更新
```

---

## 条目质量标准

好的经验条目具备：
- **可行动性**：读到这条规则的人知道具体要做什么/不做什么
- **有 why**：不只是"不能做 X"，还有"因为 Y"
- **有上下文**：知道在什么情况下这条规则生效（不是无条件的）

差的条目：
- 太泛泛：「注意线程安全」（无法行动）
- 只有 what：「使用 ChannelManagerV2」（不说为什么）
- 可以从代码直接读出来：「ChannelManager 是单例」（在代码里显而易见）
