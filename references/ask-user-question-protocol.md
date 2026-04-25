# ask-user-question-protocol — AskUserQuestion 使用规范

本片段被所有需要向用户做交互式提问的 skill 引用。
它定义了构造问题和选项时的规范，避免常见的 UI 问题。

---

## 字段规范

### `header`（必填）

该问题所属的语义维度，显示为 chip 标签，≤12 字。

示例：`需求背景`、`功能边界`、`场景覆盖`、`文档确认`、`执行模式`

### `question`（必填）

完整、具体的问句，以问号结尾。

示例：`展示这个卡片时，需要覆盖哪些场景？`

### `multiSelect`

- `true`：多个答案可同时成立时使用（如场景覆盖、功能选项）
- `false`：互斥选项（如确认/修改、继续/停止）

### `options`

每个选项包含：
- `label`：1–5 字，简洁描述该选项
- `description`：说明选择该项意味着什么，或该选项的触发条件/含义

每次调用 `AskUserQuestion` 最多 4 个问题，每个问题最多 4 个选项。

---

## ❌ 禁止手动添加 Other 类选项

`AskUserQuestion` 工具**自动在末尾追加 Other / 自由输入**入口。

禁止在 `options` 中手动添加「其他」「其他遗漏点」「Other」等兜底选项。  
重复添加会导致 UI 出现**两个 Other 入口**（一个是手动加的选项，一个是工具自动追加的），造成截图中的 4+5 冗余问题。

---

## 问题类型构造指南

### 类型 A：有明确候选项

适用场景：已知选项集合，用户从中选择（可补充）。

```
options:
  - label: 选项 1
    description: 说明 1
  - label: 选项 2
    description: 说明 2
multiSelect: true/false  # 按是否可多选决定
```

### 类型 B：开放式问题

适用场景：问题完全开放，没有预设答案（如"背景是什么"）。

做法：提供 2–3 个**典型假设**作为选项，让用户勾选最接近的，再在 Other 补充细节。

```
question: 这个需求的背景是什么？
options:
  - label: 用户反馈高频问题
    description: 用户多次反馈某个痛点，需要修复
  - label: 产品主动规划
    description: 产品方向调整，主动设计新功能
  - label: 数据指标驱动
    description: 某项数据指标下滑，针对性优化
multiSelect: false
```

### 类型 C：确认/修改二选一

适用场景：展示草稿或计划后，等待用户确认。

```
question: <内容名称>是否符合预期？
options:
  - label: 确认，保存
    description: 内容无误，直接保存并进入下一步
  - label: 需要修改
    description: 请在 Other 里说明需要改哪里
multiSelect: false
```

### 类型 D：继续/停止

适用场景：遇到异常状态，询问是否继续。

```
question: <状态说明>，是否继续执行？
options:
  - label: 继续执行
    description: 忽略异常，按当前状态继续
  - label: 停止，我来处理
    description: 停止执行，等待用户手动处理后再继续
multiSelect: false
```

---

## 轮次控制

- 每次调用 `AskUserQuestion`：最多 4 个问题
- 多轮追问时：只问新问题，不重复已确认的内容
- 需求澄清类场景最多 3 轮，第 3 轮后若仍有模糊点记录为「待确认项」，不继续追问
