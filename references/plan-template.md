# plan.md 模板

```markdown
---
feature: <slug>
dated_slug: <dated-slug>
requirement_doc: requirement.md   # 模式 B（轻量路径）时改为 inline
status: confirmed
created_at: YYYY-MM-DD
related_modules: [<module1>, <module2>]
---

> [!auto-generated] 生成于 YYYY-MM-DD
> （模式 B：⚠️ 需求来自用户直接描述，未经 /clarify 整理 — 删除此行若使用了 requirement.md）

# <功能名> — 技术方案

## 涉及模块

| 模块 | 变更类型 | 说明 |
|------|---------|------|
| <module> | 新增/修改/只读影响 | <说明> |

## 设计决策

<每个非显而易见的决策，格式：**决策标题**：why>

1. **<决策>**：<为什么这样做，不那样做>
2. **<决策>**：<为什么>

<!-- 示例（写完后删除）
✅ 好的写法：
1. **复用 ChannelListAdapter 而非新建**：新增的卡片类型与现有 item 共享点击事件和滑动手势逻辑；新建 Adapter 会导致两套手势处理分叉，维护成本更高。
2. **不修改 ChannelRepository 接口**：本次只新增展示逻辑，Repository 无需感知；保持接口稳定避免影响其他 5 处调用方。

❌ 不好的写法：
1. **使用现有组件**：复用已有代码。
2. **不改接口**：保持稳定。
-->

## 实现步骤

<!-- 只写高层描述（做什么、为什么这样做），不写文件路径和代码片段，路径/行号/代码由 task.md 承载 -->

1. <做什么> — <为什么这样做，而不是另一种方式>
2. <做什么> — <为什么>
...

## 边界与约定

- <约束 1>
- <约束 2>

## 风险点

- **<风险>**：<说明及应对>
```
