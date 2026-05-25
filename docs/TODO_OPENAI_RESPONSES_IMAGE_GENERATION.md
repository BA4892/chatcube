# TODO: OpenAI Responses 内置生图 (image_generation) 适配复盘

## 背景

把 OpenAI Responses API 的 hosted `image_generation` tool 接入主路径
(对话模型 + 内置生图工具, 由 OpenAI 服务端调度 gpt-image-2 完成实际生图,
区别于本地走独立生图路由的 IMAGE_GENERATION 输出图模型)。

2026-05-23 实测复现了 1 次 ArkTS 引擎 OutOfMemoryError 崩溃 (gpt-5.5 +
Responses transport + 中转 https://icoe.pp.ua/v1, 推理 = AUTO, 内置搜索 +
内置生图同时开)、以及多个 UX 问题。本文档汇总根因、已止血改动与后续优化点。

关联 commit: `8dad3c9 feat: 接入 OpenAI Responses 内置生图 tool 主路径`。

## 同类产品做法

- OpenAI 官方 ChatGPT: hosted `image_generation` 走 Responses, `partial_images`
  在网页端是逐步覆盖式渲染, 最终图 inline 嵌入消息体, 用户感知是 "图在画" →
  "图完成"。生图阶段没有 typing dots, 而是一个进度状态。
- RikkaHub: 模型能力矩阵区分 `IMAGE_GENERATION` (模型本身输出图) 和
  hosted image_generation tool, 本仓库 ability registry 参考此设计。

## 非目标

- 不适配 Chat Completions 上的图像生成 (官方仅 Responses 路径支持 hosted
  image_generation, Chat Completions 没有等价工具)。
- 不替换现有 `IMAGE_GENERATION` 输出图模型路径
  (`ImageGenerationCapabilityResolver` 链路)。
- 不在 partial 阶段渲染中间预览到 UI (历史也没渲染过, 详见问题 5)。

## 已识别的问题清单

### 1. GPT-5 系列没有 `IMAGE_GEN_TOOL` 能力标记

#### 现象

非 GPT-5 系列在 Responses transport 下也会展示生图 chip, 实际请求会被 OpenAI
端拒绝; 同时不区分 "对话模型 + 工具" 与 "模型本身输出图"。

#### 根因

`ModelAbilityRegistry` 早期只有 `IMAGE_GENERATION` 一种能力, 用于标记输出图模型
(gpt-image / dall-e / imagen 等)。hosted image_generation tool 是"对话模型 +
服务端工具", 语义不同, 没有对应能力位。

#### 已采取的止血

- 新增枚举 `ModelAbility.IMAGE_GEN_TOOL` (`ModelAbilityRegistry.ets:20`)。
- 在 6 个 GPT-5 def (gpt-5 / gpt-5.1 / 5.2 / 5.3 / 5.4 / 5.5) 上打上 `IMG_TOOL`。
- 暴露 `modelSupportsImageGenerationTool(modelId)` 公开 API。
- `ChatPage.isOpenAIBuiltinImageGenAvailableForCurrentProvider()` 改为
  `transport === RESPONSES && modelSupportsImageGenerationTool(currentModelId)`
  双重判定。

#### 后续优化

- [ ] `gpt-5-chat` / `gpt-5.1-chat-latest` 等 ChatGPT 网页变体目前会被
  token 子序列错误识别为支持 `IMG_TOOL` (实际它们不支持工具调用)。需要在
  gpt-5.1 / 5.2 / 5.4 / 5.5 def 上补 `notTokens: [...,'chat']`。
- [ ] `gpt-5.3` 这一档 OpenAI 实际只发布了 `gpt-5.3-codex`, 没有 base 版,
  规则上"过宽"无副作用, 但能在 README/comment 注明清楚。
- [ ] gpt-5.3 def 的 abilities 历史只有 `[TOOL]`, 缺 `REASON` (其余 5.x 都有);
  待确认 gpt-5.3-codex 推理控件是否需要可用, 决定是否补回。

### 2. 推理级别 = AUTO 时拿不到推理摘要

#### 现象

用户把推理设为"自动", gpt-5.5 实际推理了 (服务端有 reasoning items), 但前端
完全收不到 `response.reasoning_summary_text.delta` 事件, UI 看不到任何深度
思考内容。

#### 根因

`AIApiService.ets:2030-2046` 旧逻辑:

```ts
if (effort !== undefined) {
  responsesBody.reasoning = { effort: effort }
  if (normalizedReasoningLevel !== ReasoningLevel.OFF) {
    responsesBody.reasoning.summary = 'auto'
  }
}
```

`getOpenAIReasoningEffort` 在 `ReasoningLevel.AUTO` 时返回 `undefined`
(让服务端按默认决策), 进而 `if (effort !== undefined)` 不成立,
`responsesBody.reasoning` 整个对象就**没设**, `summary='auto'` 也没机会写上。
OpenAI Responses API 在没看到 `reasoning.summary` 时, SSE 流默认不下发
`reasoning_summary_text.delta` 事件 — 模型推理了, 客户端看不到。

#### 已采取的止血

新逻辑解耦 effort 和 summary:

```ts
if (normalizedReasoningLevel !== ReasoningLevel.OFF) {
  responsesBody.reasoning = { summary: 'auto' }
  if (effort !== undefined) {
    responsesBody.reasoning.effort = effort
  }
} else if (effort !== undefined) {
  responsesBody.reasoning = { effort: effort }
}
```

加日志 `[Responses] reasoning config: level=, effort=, summary=`,
下次复现一眼能看出请求里这三档值。

#### 后续优化

- [ ] 部分第三方 OpenAI 兼容中转 (尤其使用 cloudflare AI gateway / vercel
  ai-sdk 中转) 会**过滤掉 reasoning summary SSE 事件**, 即使请求里设了
  `summary='auto'` 也不会下发。需要兜底: 拿不到 summary 时, 把
  `response.output_item.done` type=reasoning 里的 `summary` 数组 (一次性
  完整摘要) flush 到前端, 而不是只用于跨轮 encrypted_content 回传。
- [ ] 同款问题在 Chat Completions 路径上不存在 (那条路径没有 summary 概念,
  推理直接走 `delta.reasoning_content`), 但 `requiresMaxCompletionTokens` /
  `getOpenAIReasoningEffort` 这两个匹配是按 modelId 前缀做的, 跟 transport
  无关, 后续如果引入 OpenRouter 类型 effort 字段需要单独串。

### 3. 生图过程中 Bubble Dots 长时间空转

#### 现象

模型在 Responses 流里只生图、不附文字 (gpt-5.5 自身决策), 服务端
`image_generation_completed` 事件后还要继续下发完整图 b64 作为
`response.completed` payload (5+ 秒, 数 MB)。期间客户端 Bubble Dots
("消息输出中" 三点动画) 持续转, 直到整个 stream completed 才停 ──
用户看起来是"图已经画完了但还在等什么, 然后什么也没出来就结束"。

#### 根因

`ChatViewModel.handleHostedResponsesToolEvent` 注释明确写着 "生图事件先打日志,
P2 再串 timeline / partial 预览"。三个 `image_generation_*` 事件全部落到
else 默认分支只打 log, **完全没写 aiMessage.parts**。

`MessageBubble.ets:2002` 渲染 Bubble Dots 的条件是
`parts.length === 0 && (isGenerating || isSearching)`。模型不出 reasoning /
text + 生图事件不建 part → `parts` 全程为空 → Bubble Dots 一直显示。

#### 已采取的止血

`ChatViewModel.ets` 新增:

- `inflightHostedImageGenCalls: Map<msgId, Set<itemKey>>` 计数器, cleanup 一并释放。
- `handleHostedResponsesToolEvent` 加 `IMAGE_GENERATION_STARTED/PARTIAL/COMPLETED`
  分支, 调用 `upsertHostedImageGenPart` 在 `aiMessage.parts` 末尾追加
  `hig_<itemId>` TOOL part (toolName='image_generation', source=BUILTIN)。
- STARTED → status=RUNNING (timeline 显示"OpenAI Image Generation 进行中"),
  COMPLETED → status=SUCCEEDED, parts 始终非空, Bubble Dots 自然隐退。
- 每个事件加详细日志 (含 itemId / output / partial / inflight / partChanged)。

#### 后续优化

- [ ] `hig_<itemId>` part 当前没有专属渲染样式, 走通用 tool step 渲染。可以
  做一个生图专属的 step UI: 进行中显示进度环 / "图已生成"完成态显示缩略图。
- [ ] image_generation_completed 与 stream completed 之间那几秒服务端在
  echo 完整 b64 payload (浪费带宽 + 拖长用户感知时长), 看看能不能在收到
  attachment 后**主动 destroy httpRequest** 提前断流。需要确认 OpenAI 是否会
  因此触发 incomplete response 报错。

### 4. open_page action 把 reasoning 段切断成多块

#### 现象

OpenAI hosted web_search 有两种 action: `search` (输出 query) 和 `open_page`
(输出 URL, 模型读取该页面内容)。后者在 UI timeline 上独立成一行 hosted
search part, 顺序如下:

```
[深度思考 第1段]
[Web Search ✓]
[Web Search ✓]
[深度思考 第2段]
[https://...tang.org.cn/56360.html]   ← 实际是 open_page 调用
[深度思考 第3段]
[Image Generation ✓]
```

用户期望: 第 2、3 段属于同一段思考, 因为中间夹的 URL 在感知上更像"思考
途中引用了一篇文章", 不像独立的搜索步骤。

#### 根因

`upsertHostedWebSearchPart` 不区分 search / open_page, 一律建 `hws_<id>`
TOOL part, 并调用 `finishTrailingReasoningPart` 把当前 reasoning part 封口
完成。下次 reasoning delta 到来, `pushPartReasoning` 看 last.reasoningFinishedAt
非 0, 创建新 reasoning part → reasoning 被 open_page 切成两段。

#### 已采取的止血

新增 `openPageHostedItemIds: Map<msgId, Set<itemKey>>` 跨事件阶段记忆,
辅以 `isOpenPageRecorded / rememberOpenPageItem / forgetOpenPageItem` 三个
primitive。

`handleHostedResponsesToolEvent` 在 STARTED / SEARCHING / COMPLETED 入口
判定 `query==='' && url!==''`:

- 命中 → 把 url 推到 `aiMessage.searchReferences` (顶部引用卡片照常显示),
  itemId 记入集合, 直接 return; **不创建 hws_ part / 不入 inflight /
  不动 isSearching / 不封口 reasoning**。
- 后续阶段事件查集合走同一快路径。

效果: open_page 不再出现在 timeline 上, reasoning 段保持连续。

#### 后续优化

- [ ] 顶部引用卡片当前对 hosted open_page 的来源标签写死 "OpenAI Web Search"
  (沿用 hosted search 的 source/engine 字段)。如果想跟普通 url_citation
  区分, 可以拆出 `openai_open_page` 单独标签。
- [ ] open_page url 当前 title 字段为空字符串, 卡片显示可能秃。看下能不能
  从 SSE event 里拿到该页面的 title 一起推上。
- [ ] 如果模型在一轮里同时做了 search 和 open_page (混合 action 类型),
  reasoning timeline 上 search 仍然会切, 这是按设计 — 但要确认 open_page
  内部不会被前端误识别为 search 再走错路径。

### 5. ⚠ 生图过程 ArkTS SharedHeap OOM 崩溃

#### 现象

2026-05-23 09:22:16 复现一次, JS_ERROR 事件 (hisysevent AAFWK 域):

```
REASON: OutOfMemoryError
SUMMARY: OutOfMemory when trying to allocate 5255528 bytes
         function name: SharedHeap::AllocateHugeObject, shared heap oom
Stacktrace:
  at anonymous entry (entry/src/main/ets/services/AIApiService.ets:3041:32)
  at anonymous entry (entry/src/main/ets/services/HttpService.ets:634:7)

PROCESS_RSS_MEMINFO: 824381 KB (~805 MB)
PROCESS_LIFETIME: 271s
FAULT_TYPE: 3 (JS_ERROR)
```

应用直接被 ArkTS 引擎 abort, 用户体感是"生图过程中闪退"。

#### 根因

两层叠加:

**根因 A (直接触发)** — `AIApiService.ets:1059-1062` `partial_images` 历史默认
**2**, OpenAI 服务端会在生图阶段下发 2 张渐进预览 + 1 张最终图, 共 **3 帧**
单行 JSON, 每帧把完整 base64 嵌在 `partial_image_b64` / `item.result` 字段里,
**单帧 5+ MB**。

**根因 B (放大效应)** — `AIApiService.ets:3048` `buffer += text` 在 SSE chunk
回调里逐 chunk 拼接成完整 SSE 行。OpenAI image_generation 的 SSE event 内部
**没有换行**, 整张图 b64 是单行 → buffer 临时增长到 5+ MB → ArkTS 走
`AllocateHugeObject` 在 SharedHeap 一次性分配大块连续内存。如果 3 帧累加 +
attachment 已挂载 + WebView 进程占用 + ArkTS 引擎自身, 进程 RSS 撑到 800+ MB,
SharedHeap 触顶 OOM。

#### 已采取的修复

本段已从"仅止血根因 A"推进到同时处理根因 B:

- [x] **请求体对齐 RikkaHub**: hosted `image_generation` 默认只传
  `type=image_generation` 和 `model=gpt-image-2`, 不再主动传
  `partial_images` / `output_format` / `output_compression`; 调用方显式设置时
  仍可透传 0-3 的 `partial_images`。日志里 `partial_images=default` 表示走
  OpenAI 默认值。
- [x] **SSE buffer 重构**: `AIApiService.ets` 已引入 `StreamLineAccumulator`,
  `streamChatRequest` / `streamChatRequestWithTools` 均改为在 `Uint8Array`
  层面按 `\n` 切行, 不再用 `buffer: string` + `+=` + `split('\n')`。
- [x] **Responses 大行防御**: 对 `response.completed` 和
  `response.image_generation_call.partial_image` 大行按前缀丢弃; 对最终
  `response.output_item.done` + `image_generation_call` 使用字节级扫描提取
  `result` / `id` / `output_index`, 避免整行 `JSON.parse`。
- [x] **base64 编码循环替换**: `ChatViewModel.downloadImageAsBase64` 已改用
  `util.Base64Helper.encodeToStringSync(Uint8Array)`, 去掉手写
  `base64 += charAt(...)` 的 O(n²) 拼接。
- [x] **落盘后释放 base64**: `saveAIGeneratedImage` 在
  `AttachmentStorageService.saveAttachment` 成功后清空 `attachment.base64Data`,
  消息对象保留 `filePath`。

#### ⚠ 残留风险与后续优化 (重要)

代码侧已去掉原先最危险的字符串累积和整行 JSON parse 路径, 但最终图本身仍会以
base64 字符串交给 `onImageData` / `saveAIGeneratedImage`。如果服务端返回极大的
最终图, 仍需用真机复现确认 ArkTS SharedHeap 峰值是否可接受。后续要做的:

- [x] 复现前采集一份当前进程基线内存: 2026-05-24 已用
  `hdc shell "hidumper --mem 20286"` 保存到
  `.codex_ui/oom_diagnostics/hidumper_mem_20286_20260524.txt`。当时
  `com.longlive.chatcube` PSS Total 约 163 MB, `ark ts heap` 约 38 MB。
- [x] 验证 faultlogger 拉取命令: 2026-05-24 已执行
  `hdc file recv /data/log/faultlog/faultlogger .codex_ui/oom_diagnostics/faultlogger`,
  命令可用; 当前拉到的目录里没有 2026-05-23 09:22 那次
  `com.longlive.chatcube` 的 jscrash, 只有较早的 `aibusiness...` jscrash。
- [ ] 复现时在崩溃前后各拉一份 `hidumper --mem <pid>` 看 ArkTS heap /
  native heap / PSS 变化, 确认 buffer 重构后是否还需要进一步降低图片尺寸或
  增加更早落盘策略。
- [ ] 如果再次出现 JS_ERROR, 立刻拉取
  `/data/log/faultlog/faultlogger/jscrash-<bundle>-<uid>-<timestamp>.log`,
  用完整 ArkTS line/col 和 SharedHeap 信息复核是否还有新的大对象分配点。

## 验证清单 (复现 + 回归)

复现 OOM 用例:

- [ ] Provider: 任意 OpenAI Responses transport 中转或官方
- [ ] 模型: gpt-5.5 (或任意有 IMG_TOOL ability 的 GPT-5 系列)
- [ ] 推理级别: 自动 (AUTO)
- [ ] 内置搜索: 开 + mode=openai_builtin
- [ ] 内置生图: 开
- [ ] Prompt: 触发"先搜索再生图"的需求, e.g. "西安林克古风街景图"
- [ ] 复现路径: 模型走 reasoning → web_search → reasoning → open_page →
  reasoning → image_generation_started → partial × N → completed → 后续

回归验证点:

- [ ] 日志里 `[Responses] image_generation tool: partial_images=default` 出现,
  且整个 stream 期间没有 `image_generation_partial` 事件 (RikkaHub 风格默认
  请求体验证)
- [ ] 日志里 `[Responses] reasoning config: level=auto, effort=unset,
  summary=auto` 出现 (问题 2 验证)
- [ ] timeline 上能看到一个 "OpenAI Image Generation" 步骤, 整个生图阶段
  没有 Bubble Dots 转 (问题 3 验证)
- [ ] open_page 的 URL 出现在顶部 SearchReferenceCard 引用卡片里, 不出现
  在 timeline 主流上 (问题 4 验证)
- [ ] reasoning 段在两次 search 之后是连续一段, 不被 open_page 切断
  (问题 4 验证)

崩溃复现:

- [ ] 显式把 `partial_images` 设为 2, 用 quality=high + 1024×1024
  prompt 触发, 看是否还能稳定 OOM (确认根因 A + B 关系)
- [ ] 默认不传 `partial_images` 但 quality=high, 看最终图单帧是否能触发 OOM
  (确认根因 B 修复后的残留风险)
