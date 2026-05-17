# 聊天列表 Repeat 替代 LazyForEach 迁移方案

**状态**: 设计阶段 (未实施)  
**优先级**: P1 (中期性能优化)  
**前置条件**: 已完成 @ReusableV2 回退 (commit xxx),消息顺序错位 bug 已修复  
**目标**: 用 ArkUI V2 官方推荐的 Repeat 组件替代 LazyForEach,消除手动 DataSource 维护成本,利用内置复用机制提升长会话滚动性能

---

## 一、背景与动机

### 1.1 当前架构 (LazyForEach + 手动 DataSource)

```
ChatPage
  └─ ChatMessageListSection (519 行)
       ├─ messageRowDataSource: ChatMessageListDataSource (297 行, 实现 IDataSource)
       ├─ messageRows: ChatMessageRowData[] (手动维护 existingRowMap 复用)
       ├─ syncMessageRows() — 全量 diff + setItems(nextRows, forceReload, changedIndexes)
       ├─ syncSingleMessageRow() — 单条优化路径 (编辑态 inputText 变化)
       └─ LazyForEach(messageRowDataSource, ...) 
            └─ ChatMessageListItem (122 行, 纯 @ComponentV2 wrapper)
                 └─ MessageBubble (3200+ 行, markdown/reasoning/tool timeline)
```

**核心问题**:
1. **手动 DataSource 维护成本高** — `ChatMessageListDataSource` 需实现 `totalCount/getData/registerDataChangeListener/notifyDataChanged/notifyDataReloaded`,流式追加时走 `syncVersion+1 → syncMessageRows → setItems → notifyDataChanged(changedIndexes)` 补丁路径
2. **@ReusableV2 复用时机不可控** — LazyForEach 的 `onDataChange(idx)` 触发"原地更新"时不走 `aboutToReuse`,导致 `boundMessageId` 兜底失效,AI 消息内容串到错位气泡 (已通过回退 @ReusableV2 修复,但放弃了组件级复用性能)
3. **长会话快速 fling 掉帧** — 无组件复用时每次滚出 cachedCount 都要重建 MessageBubble (new MarkdownController x3 + configureMarkdownStyles 30+ 颜色),用户感知"重复加载"

### 1.2 Repeat 优势 (官方回答总结)

| 维度 | LazyForEach | Repeat (virtualScroll) |
|------|-------------|------------------------|
| **数据源** | 必须实现 IDataSource 接口 | 普通 `@Local Array<T>`,自动响应变化 |
| **局部刷新** | 手动 `notifyDataChanged(idx)` | 直接修改 `arr[idx].field`,框架自动 diff |
| **复用机制** | 需配合 @Reusable 手动管理 | 内置模板级缓存池,按 templateId 自动复用 |
| **流式追加** | 补丁路径 syncVersion+1 | `arr[idx].content += delta` 触发精确更新 |
| **滚动定位** | scroller.scrollToIndex | 同左,但数据更新 + 滚动同帧需修正索引 |

**关键警告** (官方文档):
> "Repeat 会一直复用子组件,即使键值不同,Repeat 也会复用上次多余的组件,仅刷新 UI" — 如果组件内部有未重置的局部状态,仍会残留旧内容。**必须纯数据驱动** (所有 UI 来自 `obj.item`),或用 @ReusableV2 + aboutToReuse 主动清理。

---

## 二、迁移路径设计

### 2.1 Phase 1: 数据层改造 (保持 LazyForEach 不动)

**目标**: 把 `ChatMessageRowData[]` 改为 `@ObservedV2` 类 + `@Trace` 字段,验证流式追加时精确订阅是否生效。

#### 2.1.1 改造 ChatMessageRowData

```typescript
// entry/src/main/ets/components/chat/ChatMessageListDataSource.ets

@ObservedV2
export class ChatMessageRowData {
  @Trace message: ChatMessage  // 已是 @ObservedV2
  @Trace showDateDivider: boolean
  @Trace showHeader: boolean
  @Trace isSelected: boolean
  @Trace isEditing: boolean
  @Trace isDimmed: boolean
  @Trace renderSignature: string
  @Trace contentRenderSignature: string
  @Trace assistantAvatarSymbol: string
  @Trace assistantAvatarColor: string
  @Trace assistantAvatarCacheKey: number

  // 删除 constructor,改用 V2 默认初始化
  // 保留 get key() / get stableId() 用于 LazyForEach keyGenerator
}
```

#### 2.1.2 ChatMessageListSection 改用 @Local

```typescript
@ComponentV2
export struct ChatMessageListSection {
  @Local private messageRows: ChatMessageRowData[] = []
  // 保留 messageRowDataSource 用于 LazyForEach,但 setItems 改为直接赋值 this.messageRows
  
  private syncMessageRows(forceReload: boolean = false, changedMessageId: string = ''): void {
    // ... 原逻辑构造 nextRows
    this.messageRows = nextRows  // V2 自动 diff
    this.messageRowDataSource.setItems(nextRows, forceReload, changedIndexes)  // 兼容 LazyForEach
  }
}
```

**验证点**: 流式追加时 `this.messageRows[idx].message.content += delta` 是否触发 LazyForEach 局部刷新 (通过 notifyDataChanged 补丁)。

---

### 2.2 Phase 2: 替换为 Repeat (核心迁移)

#### 2.2.1 删除 ChatMessageListDataSource

整个 `ChatMessageListDataSource` 类 (297 行) 可删除,`totalCount/getData/registerDataChangeListener` 全部由 Repeat 内置处理。

#### 2.2.2 ChatMessageListSection build() 改写

**迁移前** (LazyForEach):
```typescript
List({ scroller: this.scroller }) {
  ListItem() { Column().height(this.topInsetHeight) }
  
  LazyForEach(this.messageRowDataSource, (item: ChatMessageRowData, _index: number) => {
    ListItem({ style: ListItemStyle.NONE }) {
      ChatMessageListItem({ message: item.message, ... })
        .width('100%')
    }
  }, (item: ChatMessageRowData): string => item.key)
  
  // ... DraftPreviewBubble + bottomPadding
}
```

**迁移后** (Repeat):
```typescript
List({ scroller: this.scroller }) {
  ListItem() { Column().height(this.topInsetHeight) }
  
  Repeat<ChatMessageRowData>(this.messageRows)
    .each((obj: RepeatItem<ChatMessageRowData>) => {
      ListItem({ style: ListItemStyle.NONE }) {
        ChatMessageListItem({
          message: obj.item.message,
          showDateDivider: obj.item.showDateDivider,
          showHeader: obj.item.showHeader,
          // ... 其他 @Param 全部从 obj.item 取
        })
          .width('100%')
      }
    })
    .key((item: ChatMessageRowData, index: number): string => item.key)
    .virtualScroll({ totalCount: this.messageRows.length })
  
  // ... DraftPreviewBubble + bottomPadding
}
```

**关键点**:
- `.key()` 仍用 `item.key` (即 `message.id`),保证唯一性
- `.virtualScroll()` 启用懒加载,`totalCount` 绑定 `messageRows.length`
- 暂不用 `.template()` 分桶 (user/assistant),先验证基础功能

#### 2.2.3 流式追加适配

**原路径** (syncVersion 补丁):
```typescript
// ChatPage.ets onSyncMessages 回调
this.messageListSyncVersion += 1
this.messageListSyncMessageId = changedMessageId
// → ChatMessageListSection @Monitor('syncVersion') 
// → syncMessageRows(false, syncMessageId)
// → setItems(nextRows, false, [changedIndex])
// → notifyDataChanged([changedIndex])
```

**新路径** (直接修改数组):
```typescript
// ChatPage.ets onSyncMessages 回调
const idx = this.messages.findIndex(m => m.id === changedMessageId)
if (idx >= 0) {
  // messageRows[idx] 已绑定到 messages[idx],ChatMessage 是 @ObservedV2
  // 流式追加时 ChatViewModel 已修改 messages[idx].content,框架自动 diff
  // 无需手动 syncVersion+1
}
```

**风险**: 如果 `ChatMessageRowData` 的 derived 字段 (如 `renderSignature`) 没有自动更新,需要在 `@Monitor('message')` 里手动重算。

---

### 2.3 Phase 3: 模板分桶优化 (可选)

用 `.template()` 按 message role 分桶,减少 user/assistant 结构差异导致的复用抖动。

```typescript
Repeat<ChatMessageRowData>(this.messageRows)
  .template('user', (obj: RepeatItem<ChatMessageRowData>) => {
    ListItem({ style: ListItemStyle.NONE }) {
      // user 消息专用布局 (右对齐、蓝色气泡)
      ChatMessageListItem({ message: obj.item.message, ... })
    }
  })
  .template('assistant', (obj: RepeatItem<ChatMessageRowData>) => {
    ListItem({ style: ListItemStyle.NONE }) {
      // assistant 消息专用布局 (左对齐、灰色气泡、markdown)
      ChatMessageListItem({ message: obj.item.message, ... })
    }
  })
  .templateId((item: ChatMessageRowData, index: number): string => {
    return item.message.role === MessageRole.USER ? 'user' : 'assistant'
  })
  .virtualScroll({ totalCount: this.messageRows.length })
```

**收益**: 同 role 的消息复用同一缓存池,避免 user ↔ assistant 切换时的 layout 重建。

---

## 三、风险与缓解

### 3.1 Repeat 复用残留风险 (高危)

**问题**: 官方警告 "Repeat 会复用上次多余的组件,仅刷新 UI",如果 MessageBubble 内部有 `@Local` 状态 (如 `expandedToolStepKeys`、`latexPreviewPixelMap`),复用时可能残留旧消息的状态。

**缓解**:
1. **纯数据驱动** — MessageBubble 的所有 UI 必须来自 `@Param message`,不依赖内部 `@Local` 缓存
2. **@ReusableV2 + aboutToReuse** — 如果必须用 `@Local` (如 latex 预览),给 MessageBubble 加回 @ReusableV2,在 `aboutToReuse()` 里主动清理:
   ```typescript
   @ReusableV2
   @ComponentV2
   export struct MessageBubble {
     aboutToReuse(): void {
       this.boundMessageId = ''  // 强制 syncMessageScopedState 走 reset
       this.latexPreviewPixelMap = null
       this.expandedToolStepKeys = []
       // ... 清理所有 derived cache
     }
   }
   ```
3. **PoC 验证** — 在 Phase 2 完成后,用"数字回复 1~10"用例 + 快速滚动,验证 AI 内容是否串位

### 3.2 滚动定位时机问题 (中危)

**问题**: 官方文档提到 "数据更新 + scrollToIndex 同帧时,索引会基于更新后的新列表计算",MessageMapSheet 跳转时可能定位错误。

**缓解**:
```typescript
// ChatPage.handleJumpToMessage
this.showMessageMapSheet = false
setTimeout(() => {
  // 等 sheet 关闭动画 (120ms)
  this.scroller.scrollToIndex(toListScrollIndexForMessage(messageIndex), ...)
}, 120)
// 如果跳转前有数据插入,需修正索引: scrollToIndex(原索引 + 插入数量)
```

### 3.3 cachedCount 缺失 (低危)

**问题**: Repeat 没有直接的 `cachedCount` 参数,缓存池容量由框架自动管理。

**缓解**: 
- 通过 `.template()` 分桶后,每个 template type 有独立缓存池
- 如果滚动卡顿,可尝试减少 `virtualScroll` 的预加载区域 (API 18+ 支持 `cachedCount` 配置)

### 3.4 回滚路径

如果 Repeat 迁移后出现严重 bug (如内容残留、crash),回滚步骤:
1. `git revert <repeat-migration-commit>`
2. 恢复 `ChatMessageListDataSource.ets` 文件
3. `ChatMessageListSection` 的 `messageRows` 改回 `private`,`build()` 用回 `LazyForEach`
4. 删除 `@ObservedV2` 装饰 (如果 Phase 1 已合并)

---

## 四、验证计划

### 4.1 Phase 1 验证 (数据层)

- [ ] 流式追加 10 条消息,观察 `messageRows[idx]` 变化是否触发 LazyForEach 局部刷新
- [ ] 编辑态 inputText 实时预览,`syncSingleMessageRow` 路径是否仍生效
- [ ] 多选模式切换,`isSelected` 变化是否触发对应行刷新

### 4.2 Phase 2 验证 (Repeat 替换)

- [ ] **顺序正确性** — "数字回复 1~10" 用例,AI 气泡内容严格 1:1 对应 user 气泡
- [ ] **流式追加** — AI 回复时每秒多次 onContent,观察最后一条消息是否实时更新 (不重建全列表)
- [ ] **滚动性能** — 100 条消息快速 fling,观察是否有"重复加载"闪烁 (对比 LazyForEach 基线)
- [ ] **MessageMapSheet 跳转** — 点击地图跳转到第 50 条,验证定位准确 + flash 高亮触发
- [ ] **编辑 + 多选** — 编辑消息时 previewContent 实时预览,多选模式勾选框正确显示

### 4.3 Phase 3 验证 (模板分桶)

- [ ] user/assistant 消息交替滚动,观察复用池是否按 role 分桶 (通过 DevEco Profiler 查看组件创建次数)
- [ ] 长 markdown 消息 (1000+ 行) 滚动,对比 Phase 2 的帧率提升

### 4.4 压力测试

- [ ] 500 条消息列表,快速滚动到底部再回顶部,观察内存占用 (对比 LazyForEach 基线)
- [ ] 连续发送 20 条"请回复 1~20",验证流式追加时无内容串位
- [ ] 设备实测 (真机 + 模拟器),覆盖 HarmonyOS 5.0.0 / 5.0.1

---

## 五、实施时间线

| 阶段 | 工作量 | 依赖 | 产出 |
|------|--------|------|------|
| Phase 1 (数据层) | 2 天 | 无 | ChatMessageRowData @ObservedV2 化 + 验证 |
| Phase 2 (Repeat 替换) | 3 天 | Phase 1 | 删除 DataSource + LazyForEach → Repeat |
| Phase 3 (模板分桶) | 1 天 | Phase 2 | .template('user'/'assistant') 优化 |
| 验证 + 修 bug | 2 天 | Phase 2/3 | 通过全部验证用例 |
| **总计** | **8 天** | | 可合并到 main |

**里程碑**:
- M1 (Phase 1 完成): 数据层 V2 化,LazyForEach 仍可用
- M2 (Phase 2 完成): Repeat 替换完成,通过顺序正确性 + 流式追加验证
- M3 (Phase 3 完成): 模板分桶优化,性能达到或超过 LazyForEach 基线

---

## 六、参考资料

### 6.1 官方文档
- [Repeat 组件 API](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-rendering-control-repeat)
- [状态管理 V2 @ObservedV2/@Trace](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-new-observedV2-and-trace)
- [LazyForEach 迁移到 Repeat](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-rendering-control-lazyforeach-to-repeat)

### 6.2 本仓库相关文件
- `entry/src/main/ets/components/chat/ChatMessageListSection.ets` (519 行) — 当前 LazyForEach 实现
- `entry/src/main/ets/components/chat/ChatMessageListDataSource.ets` (297 行) — 待删除的手动 DataSource
- `entry/src/main/ets/models/ChatModels.ets` — ChatMessage 已是 @ObservedV2
- `entry/src/main/ets/pages/ChatPage.ets` — syncVersion 补丁发起点 (onSyncMessages 回调)

### 6.3 MEMORY 记录
- `feedback_arkts_v2_lazyforeach_reactivity.md` — LazyForEach + 手动 DataSource 下 @Trace 精确订阅失效,必须走 syncVersion 补丁
- `feedback_arkts_v2_reusablev2_listitem.md` — @ReusableV2 在流式场景的时机问题,aboutToReuse 不一定触发

---

## 七、决策记录

**2026-05-17**: 短期立修 — 回退 @ReusableV2 到 199f285 之前,修复 AI 消息顺序错位 bug。中期 PoC — 本文档设计 Repeat 迁移方案,作为独立任务不阻塞当前 bug 修复。

**待决策**: Phase 2 完成后,如果 Repeat 复用残留风险无法完全消除 (即使用 @ReusableV2 + aboutToReuse),是否接受"放弃组件级复用,只用 Repeat 的懒加载"作为折中方案?
