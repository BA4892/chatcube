# TODO: OpenAI Responses 内置搜索适配

## 背景

当前聊天里的“联网搜索”走应用侧工具链：`search_web` / `scrape_web`，由工具中心的外部搜索服务执行。模型能力里的 `supportsWebSearch` 应视为“模型/供应商原生搜索能力”，不应该混用为外部搜索服务开关。

本 TODO 只覆盖 OpenAI Responses 的内置搜索适配，不包含 Gemini、Chat Completions 或其他供应商兼容层。

## 同类产品做法

- RikkaHub：模型保存 `BuiltInTools.Search`，OpenAI Responses 请求映射为 `tools: [{ type: "web_search" }]`。
- RikkaHub：启用模型内置搜索时，应用侧搜索服务选择不生效，避免两套搜索链路同时暴露。
- Kelivo：也区分“模型内置搜索”和“应用侧网页搜索”，但主要适配 Gemini；设计原则仍可参考。

## 非目标

- 不适配 Gemini `google_search`。
- 不适配 OpenAI Chat Completions。
- 不把内置搜索伪造成 `search_web` function call。
- 不为内置搜索注入外部搜索工具提示词。
- 不要求模型 `supportsTools` 才能使用 OpenAI 内置搜索。

## 设计原则

- `supportsWebSearch` 只表示模型能力，不直接等同于本轮启用搜索。
- 聊天运行态需要明确区分搜索模式：关闭、OpenAI 内置搜索、外部搜索服务。
- OpenAI 内置搜索走 Responses hosted tool，由 OpenAI 执行，不进入本地 `ToolExecutionService`。
- 内置搜索返回的引用必须进入现有 `SearchReference[]` 展示链路，不能只让模型联网但 UI 看不到来源。

## 任务清单

- [ ] 定义聊天搜索模式
  - 建议新增运行态类型：`none` / `openai_builtin` / `external_engine`。
  - 不复用 `SEARCH_ENGINE` 表示内置搜索；`SEARCH_ENGINE` 继续只保存外部搜索服务。
  - 需要考虑编辑消息、重新生成、会话级偏好恢复。

- [ ] 建模模型内置工具
  - 保留 `ModelCapabilities.supportsWebSearch` 作为“支持内置搜索”的能力标签。
  - 如需持久化“该模型默认启用哪些内置工具”，新增独立字段，例如 `builtInTools: string[]`，首期只支持 `search`。
  - 导入导出、数据库序列化、模型编辑页同步处理。

- [ ] 聊天 UI
  - 当 `provider.apiStyle === OPENAI`、`openaiTransport === RESPONSES`、当前模型 `supportsWebSearch === true` 时，在联网菜单显示“OpenAI 内置搜索”。
  - 外部搜索服务仍从工具中心已启用且配置完整的服务列表读取。
  - 选择“OpenAI 内置搜索”时，当前聊天不要启用 `search_web` / `scrape_web`。
  - 无可用外部服务时，仍允许选择 OpenAI 内置搜索。

- [ ] 发送计划
  - 拆分当前 `ChatSendFlow` 里的 `webSearchConversationEnabled` 语义。
  - 外部搜索：继续添加 `SEARCH_WEB_TOOL_ID` / `SCRAPE_WEB_TOOL_ID`，并要求 function calling。
  - OpenAI 内置搜索：不添加本地搜索工具，不要求 `supportsTools`，只把 native search flag 传给 `AIApiService`。

- [ ] OpenAI Responses 请求层
  - 扩展 `OpenAIResponsesTool` 类型，支持 hosted tool：`{ type: "web_search" }`。
  - 在 Responses 请求 body 的 `tools` 中追加 `web_search`。
  - 仅在 OpenAI Responses 路径启用，其他 transport 直接忽略或报清晰错误。

- [ ] OpenAI Responses 流式解析
  - 识别 `web_search_call` 相关 output item，必要时在 timeline 中显示“OpenAI 内置搜索”步骤。
  - 解析 message content annotations 中的 `url_citation`。
  - 将引用统一转换为 `SearchReference[]`。

- [ ] UI 引用展示
  - 内置搜索引用复用现有 `SearchReferenceCard` / timeline 引用 sheet。
  - 来源标签显示为“OpenAI 内置搜索”，与外部 `search_web` 区分。
  - 多轮/多次搜索时，引用归属不能串到其他 tool step。

- [ ] 兼容和降级
  - 如果当前 provider 不是 OpenAI Responses，不展示 OpenAI 内置搜索入口。
  - 如果模型未标记 `supportsWebSearch`，不展示入口。
  - 如果 OpenAI 返回不支持 `web_search` 的错误，错误文案应提示切换模型或关闭内置搜索。

- [ ] 验证
  - `rg` 确认内置搜索没有走 `SEARCH_ENGINE` 或本地 `search_web` 分支。
  - `check_ets_files` 覆盖修改过的 ETS 文件。
  - `git diff --check`。
  - `build_project entry@default debug`。
  - 真机/模拟器验证：关闭、外部搜索、OpenAI 内置搜索三种模式能正确切换。

## 关键文件

- `entry/src/main/ets/pages/ChatPage.ets`
- `entry/src/main/ets/pages/chat/ChatSendFlow.ets`
- `entry/src/main/ets/services/AIApiService.ets`
- `entry/src/main/ets/models/ChatModels.ets`
- `entry/src/main/ets/models/SearchReference.ets`
- `entry/src/main/ets/components/MessageBubble.ets`
- `entry/src/main/ets/components/ChatToolbar.ets`

