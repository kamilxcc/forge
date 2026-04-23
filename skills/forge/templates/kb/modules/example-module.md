---
module: example-module
maintained_by: human
last_updated: 2025-01-01
status: active
---

> [!human-maintained]
> 本文件由人工维护，Agent 不得覆盖。

# 模块名称（示例：消息频道系统）

## 概述

<!-- 1-3 句话：这个模块做什么，它在整体架构中的位置 -->

消息频道系统负责管理所有频道的订阅、分发和展示。它是消息流的入口，与推送服务、会话列表、Feed 流三者均有数据交换。

## 架构总览

```
ChannelManager（单例）
  ├── ChannelSubscriber   — 订阅/取消订阅逻辑
  ├── ChannelDispatcher   — 消息分发，按优先级路由
  ├── ChannelRepository   — 数据持久化（Room DB）
  └── ChannelViewModel    — UI 层 ViewModel（生命周期感知）
```

<!-- 关键协作路径（用文字描述跨类调用链，代码里看不出来的） -->

**典型消息接收路径**：
`PushService → ChannelDispatcher.dispatch() → ChannelRepository.save() → ChannelViewModel.observe()`

注意：`dispatch()` 是线程安全的，但 `save()` 必须在 IO 线程调用，否则会触发 StrictMode 违规。

## 关键类速查

| 类名 | 文件路径 | 职责 |
|------|---------|------|
| ChannelManager | `channel/ChannelManager.kt` | 单例入口，对外暴露所有公共 API |
| ChannelDispatcher | `channel/dispatch/ChannelDispatcher.kt` | 消息分发核心，持有优先级队列 |
| ChannelRepository | `channel/data/ChannelRepository.kt` | Room DAO 包装，统一缓存策略 |
| ChannelViewModel | `channel/ui/ChannelViewModel.kt` | UI 层状态持有，不得在 Service 中使用 |

## 注意事项 / 踩坑记录

<!-- 每条一个 bullet，格式：[LEVEL] 描述。LEVEL = CRITICAL/WARN/INFO -->

- **[CRITICAL]** `ChannelManager.init()` 必须在 Application.onCreate() 最早调用，晚于 ContentProvider 初始化则 crash。
- **[WARN]** `ChannelDispatcher` 内部队列上限 1000 条，超出时静默丢弃最老的消息，无任何日志——这是有意为之的降级策略，不要修复它。
- **[WARN]** 不要直接操作 `ChannelRepository` 的 DAO，必须通过 `ChannelManager` 的门面方法，否则缓存失效。
- **[INFO]** 频道 ID 格式：`{type}_{guild_id}_{channel_id}`，其中 type 是两位数字前缀（见 `glossary.yaml` → channel_type）。

## 常见任务索引

<!-- 告诉 Agent"做 X 任务该读哪里" -->

- 新增一种频道类型 → 修改 `ChannelType.kt` + `ChannelDispatcher` 的 `when` 分支 + 更新 glossary.yaml
- 修改订阅逻辑 → 先读 `ChannelSubscriber`，再看 `ChannelManager.subscribe()` 调用链
- 调试消息丢失 → 先检查 `ChannelDispatcher` 队列满没有，再看 `ChannelRepository.save()` 是否在正确线程

## 黑话 / 领域术语

<!-- 仅列本模块特有的，全局术语在 glossary.yaml -->

| 黑话 | 含义 |
|------|------|
| "掉频道" | 频道订阅状态丢失，通常因为进程重启后未调用 re-subscribe |
| "静默降级" | 队列满时丢弃旧消息的行为，区别于抛异常 |
| "冷启动订阅" | App 冷启动后的第一次批量订阅，耗时约 500ms-2s |

## 近期重要变更

<!-- 帮 Agent 避免用旧方案 -->

- 2024-12 **[breaking]** `dispatch()` 从同步改为异步，返回值从 `Boolean` 改为 `Deferred<Boolean>`，旧的调用方需要 `.await()`
- 2024-11 废弃 `ChannelManager.broadcastLegacy()`，统一用 `dispatch()`
