---
feature: example-feature
status: draft           # draft | confirmed | in-progress | done
created_at: 2025-01-01
author: kamilxiao
related_modules: [channel, feed]
---

> [!auto-generated] 生成于 2025-01-01
> 本文件由 /plan 命令生成，设计决策部分需人工补充。

# 示例功能：频道消息角标清零

## 需求背景

<!-- 为什么要做这个，用户痛点或业务目标 -->

用户进入频道后，Tab 上的未读角标没有自动归零，导致误认为仍有未读消息。
PM 需求：进入频道时立即清零该频道的未读计数。

## 需求描述

<!-- 功能边界，用"当…时，…"的格式描述 -->

- 当用户进入任意频道详情页时，调用后端接口将该频道未读计数置 0
- 当接口调用成功后，本地立即更新 ChannelViewModel 中对应频道的 unreadCount 字段
- 当用户处于频道详情页期间收到新消息时，不增加 unreadCount（实时清零）
- 网络失败时静默，不弹错误 toast（降级：用户重进一次会再次触发）

## 涉及模块

<!-- 列出所有受影响的模块，说明影响范围 -->

| 模块 | 变更类型 | 说明 |
|------|---------|------|
| channel | 修改 | ChannelViewModel 新增 clearUnread() 方法 |
| feed | 只读影响 | FeedList 角标 UI 观察 ChannelViewModel，无需直接修改 |
| network | 新增接口 | POST /channel/read — 已有类似接口，参考 MessageReadApi |

## 设计决策

<!-- 记录 why，不只是 what。这是知识库最核心的价值所在 -->

1. **不在 ChannelRepository 中处理**：clearUnread 是 UI 行为（进入页面触发），
   不是数据层的职责。放在 ViewModel 中更符合单向数据流，且方便测试。

2. **接口失败时静默**：用户对"角标清零失败"的感知低，重试逻辑会增加复杂度。
   与 PM 确认后采用 fire-and-forget 模式。

3. **实时清零通过 Flow 实现**：ChannelViewModel 持有 `unreadCount: MutableStateFlow<Int>`，
   进入页面时 emit(0) 即可，无需另开监听器。

## 实现步骤

<!-- 编号，每步应该是独立可验证的 -->

1. `ChannelApi.kt` — 新增 `suspend fun clearUnread(channelId: String): Result<Unit>`
2. `ChannelViewModel.kt` — 新增 `fun clearUnread()` 调用 Api，成功后 `_unreadCount.emit(0)`
3. `ChannelDetailFragment.kt` — `onResume()` 调用 `viewModel.clearUnread()`
4. `ChannelDetailFragment.kt` — 在活跃时收到消息推送，拦截 unreadCount 增加（在 ChannelDispatcher 层加 activeChannelId 判断）

## 边界与约定

- 只清零当前用户自己的 unreadCount，不影响其他人
- `clearUnread()` 不应在后台 Service 中调用（无 ViewModel 生命周期保证）
- 接口幂等，重复调用无副作用

## 待确认项

<!-- 阻塞实现的问题，需要 PM/后端/设计 确认 -->

- [ ] 后端 `/channel/read` 接口是否已存在？（目前假设仿照 `/message/read`，待后端确认）
- [ ] 折叠屏多窗口场景：用户同时开两个频道详情，两个都清零是否符合预期？
