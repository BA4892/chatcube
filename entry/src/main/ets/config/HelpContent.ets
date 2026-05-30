// 使用帮助内容结构
// 标题与列表摘要沿用字符串资源,正文直接维护中文 Markdown。

export class HelpTopic {
  key: string = ''
  title: ResourceStr = ''
  teaser: ResourceStr = ''
  markdownBody: string = ''
}

export class HelpCategory {
  key: string = ''
  title: ResourceStr = ''
  topics: HelpTopic[] = []
}

export const HELP_CATEGORIES: HelpCategory[] = [
  {
    key: 'start',
    title: $r('app.string.help_cat_start'),
    topics: [
      {
        key: 'add_model',
        title: $r('app.string.help_start_add_model_title'),
        teaser: $r('app.string.help_start_add_model_teaser'),
        markdownBody: `**你需要准备**

- 一个模型服务商账号。
- 服务商提供的 \`API Key\`。
- 服务商接口地址,通常叫 \`Base URL\`。

**配置步骤**

1. 打开 **设置 → 模型与 AI 能力 → 模型管理**。
2. 选择已有服务商,或新增一个服务商。
3. 填入 \`Base URL\` 与 \`API Key\`,然后保存。
4. 在该服务商下添加你要使用的模型。

**配置完成后**

回到聊天页,在模型选择里切换到刚添加的模型即可开始对话。`
      } as HelpTopic,
      {
        key: 'no_key',
        title: $r('app.string.help_start_no_key_title'),
        teaser: $r('app.string.help_start_no_key_teaser'),
        markdownBody: `**先说明**

ChatCube 本身不提供模型服务,需要你先在模型服务商官网注册并申请 \`API Key\`。

**推荐渠道**

- **硅基流动**:提供多种开源与商业模型,适合先用较低门槛体验模型 API。
  注册链接:[https://cloud.siliconflow.cn/i/PphCNUwa](https://cloud.siliconflow.cn/i/PphCNUwa)
- **小米 MiMo 开放平台**:可体验小米顶尖模型 MiMo V2.5 等。通过邀请码注册新用户可得 ¥10 API 体验金。
  邀请码:\`JR2N2R\`
  注册链接:[https://platform.xiaomimimo.com?ref=JR2N2R](https://platform.xiaomimimo.com?ref=JR2N2R)

**MiMo 邀请码填写**

注册后进入控制台,点击左下方入口填入邀请码。体验金有效期 40 天。

**提示**

上面的链接和邀请码为作者邀请渠道,新用户可获得体验额度,邀请人也可能获得奖励。拿到密钥后,回到 **模型管理** 填入 \`Base URL\` 和 \`API Key\`。各服务商的 API 地址以其官方文档为准。`
      } as HelpTopic
    ]
  } as HelpCategory,
  {
    key: 'models',
    title: $r('app.string.help_cat_models'),
    topics: [
      {
        key: 'roles',
        title: $r('app.string.help_models_roles_title'),
        teaser: $r('app.string.help_models_roles_teaser'),
        markdownBody: `**默认模型是什么**

默认模型用于给不同任务指定首选模型。聊天、标题、推荐候选词、翻译、图像生成互不影响。

**5 个角色**

- **聊天**:主对话使用的模型。
- **标题生成**:自动命名会话。
- **推荐候选词**:生成后续问题。
- **翻译**:消息翻译。
- **图像生成**:独立图像生成工作台使用的模型。

**注意事项**

某个角色未配置或模型不可用时,只会影响对应功能。例如推荐候选词未配置,不影响正常聊天。`
      } as HelpTopic,
      {
        key: 'system_prompt',
        title: $r('app.string.help_models_system_prompt_title'),
        teaser: $r('app.string.help_models_system_prompt_teaser'),
        markdownBody: `**它是什么**

系统提示词是发给模型的全局指令,用来设定 AI 的身份、语气和回答规则。

**在哪里设置**

打开 **设置 → 系统提示词**,可以自定义或关闭系统提示词。

**生效范围**

系统提示词会影响之后新建的对话。不同模型对系统提示词的遵循程度可能不同。`
      } as HelpTopic,
      {
        key: 'tools',
        title: $r('app.string.help_models_tools_title'),
        teaser: $r('app.string.help_models_tools_teaser'),
        markdownBody: `**工具中心是什么**

工具中心列出了可供模型调用的内置工具。启用后,模型可以在需要时调用工具补充信息或完成操作。

**联网搜索**

联网搜索需要先选择并配置搜索服务,并填入对应密钥或参数。配置完成后,模型在需要时可以联网检索资料再作答。

**可选择的搜索服务**

- **Exa**:偏 AI 搜索 API,适合给模型补充网页结果与摘要。官网:[https://exa.ai](https://exa.ai)
- **Tavily**:面向 AI Agent 的搜索 API,配置简单,适合通用联网检索。官网:[https://www.tavily.com](https://www.tavily.com)
- **Firecrawl**:偏网页抓取、解析和内容提取,适合需要读取网页正文的场景。官网:[https://www.firecrawl.dev](https://www.firecrawl.dev)
- **秘塔搜索 / Metaso**:适合中文搜索场景,可在搜索 API 控制台申请和查看用量。入口:[https://metaso.cn/search-api/playground](https://metaso.cn/search-api/playground)

这些服务通常都会提供一定免费额度,轻量个人使用一般足够。具体额度、重置周期和计费方式会调整,以服务商控制台和最新价格页为准。

**注意事项**

工具是否可用还取决于当前模型是否支持工具调用。部分模型不支持工具调用时,相关能力可能不可用。`
      } as HelpTopic
    ]
  } as HelpCategory,
  {
    key: 'chat',
    title: $r('app.string.help_cat_chat'),
    topics: [
      {
        key: 'suggestions',
        title: $r('app.string.help_chat_suggestions_title'),
        teaser: $r('app.string.help_chat_suggestions_teaser'),
        markdownBody: `**功能说明**

开启后,AI 每次回复完成会在输入框上方给出最多 3 个推荐的后续问题。

**怎么开启**

打开 **设置 → 聊天输入**,开启 **推荐后续问题**。

**模型来源**

生成候选问题所用的模型在 **默认模型 → 推荐候选词** 中指定。点击候选问题即可快速追问。`
      } as HelpTopic,
      {
        key: 'attachments',
        title: $r('app.string.help_chat_attachments_title'),
        teaser: $r('app.string.help_chat_attachments_teaser'),
        markdownBody: `**怎么发送**

点击输入框旁的附件入口,可以在消息中添加图片或文件一起发送。

**能不能理解附件**

是否能理解图片、读取文件内容,取决于当前选择的模型是否支持相应的多模态或文件能力。`
      } as HelpTopic,
      {
        key: 'image_paths',
        title: $r('app.string.help_chat_image_paths_title'),
        teaser: $r('app.string.help_chat_image_paths_teaser'),
        markdownBody: `**ChatCube 有两种生图方式**

- **对话内生图**:GPT-5 系列等支持 Responses 内置生图能力的模型,可在聊天里直接出图,由工具栏的 **生图** 开关控制。
- **图像生成工作台**:**设置 → AI 创作 → 图像生成** 中的独立文生图、图生图、图库界面,使用 **默认模型 → 图像生成** 配置的模型。

**怎么选择**

想边聊边出图,使用对话内生图。想集中管理提示词、参考图和历史图片,使用图像生成工作台。

**注意事项**

两者相互独立,聊天模型和图像生成模型可以分别配置。`
      } as HelpTopic,
      {
        key: 'share',
        title: $r('app.string.help_chat_share_title'),
        teaser: $r('app.string.help_chat_share_teaser'),
        markdownBody: `**功能说明**

可以把单条或多条消息生成长图卡片,适合保存或分享到其它平台。

**怎么使用**

在消息上通过长按或菜单进入分享操作,选择要导出的消息后生成卡片。`
      } as HelpTopic
    ]
  } as HelpCategory,
  {
    key: 'image',
    title: $r('app.string.help_cat_image'),
    topics: [
      {
        key: 'workspace',
        title: $r('app.string.help_image_workspace_title'),
        teaser: $r('app.string.help_image_workspace_teaser'),
        markdownBody: `**图像生成工作台包含三块能力**

- **文生图**:输入文字描述生成图片。
- **图生图**:上传参考图后再生成。
- **图库**:查看和管理历史生成结果。

**使用前准备**

请先在 **默认模型 → 图像生成** 配置一个具备出图能力的模型。

**建议**

如果你只是想在聊天里临时生成一张图,可以使用对话内生图。如果你需要参考图、历史管理或更完整的生图流程,使用图像生成工作台。`
      } as HelpTopic
    ]
  } as HelpCategory,
  {
    key: 'data',
    title: $r('app.string.help_cat_data'),
    topics: [
      {
        key: 'backup',
        title: $r('app.string.help_data_backup_title'),
        teaser: $r('app.string.help_data_backup_teaser'),
        markdownBody: `**导出数据**

可以把对话、附件与配置打包成一个备份文件。

**导入数据**

在新设备或重装应用后,使用 **导入数据** 从备份文件恢复。

**注意事项**

备份文件可能包含模型服务商配置、搜索服务配置等敏感信息。请只保存到可信位置。`
      } as HelpTopic,
      {
        key: 'webdav',
        title: $r('app.string.help_data_webdav_title'),
        teaser: $r('app.string.help_data_webdav_teaser'),
        markdownBody: `**它能做什么**

配置 WebDAV 后,可以将备份上传到你自己的网盘或服务器。

**典型用法**

1. 在当前设备导出备份并上传到 WebDAV。
2. 在另一台设备下载备份。
3. 使用 **导入数据** 恢复。

**注意事项**

WebDAV 只负责备份文件的上传与下载。跨设备恢复仍以导入备份文件为准。`
      } as HelpTopic
    ]
  } as HelpCategory,
  {
    key: 'personalize',
    title: $r('app.string.help_cat_personalize'),
    topics: [
      {
        key: 'appearance',
        title: $r('app.string.help_personalize_appearance_title'),
        teaser: $r('app.string.help_personalize_appearance_teaser'),
        markdownBody: `**可调整内容**

- 深浅显示模式。
- 主题配色。
- 字体大小。
- 材质效果与材质级别。
- 标签光效等质感选项。

**入口**

打开 **设置 → 显示与外观** 进行调整。`
      } as HelpTopic,
      {
        key: 'input',
        title: $r('app.string.help_personalize_input_title'),
        teaser: $r('app.string.help_personalize_input_teaser'),
        markdownBody: `**可调整内容**

- 键盘回车键是发送消息还是换行。
- 是否开启 **推荐后续问题**。

**入口**

打开 **设置 → 聊天输入** 进行调整。`
      } as HelpTopic,
      {
        key: 'hand',
        title: $r('app.string.help_personalize_hand_title'),
        teaser: $r('app.string.help_personalize_hand_teaser'),
        markdownBody: `**功能说明**

在支持的设备上,智感握姿会识别你的握持手。

**会调整什么**

- 新建对话入口。
- 聊天悬浮按钮。
- 发送按钮位置。

**目的**

根据握持手自动调整常用按钮的位置,提升单手操作的可达性。`
      } as HelpTopic
    ]
  } as HelpCategory
]
