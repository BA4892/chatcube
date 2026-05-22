<p align="center">
  <img src="AppScope/resources/base/media/foreground.png" width="120" />
</p>

<h1 align="center">Cube Chat</h1>

<p align="center">
  一个面向鸿蒙 6（API 23）的原生 AI 聊天客户端。<br/>
  一个应用，15+ 服务商，联网搜索、MCP 与 ArkTS 原生体验。
</p>

<p align="center">
  <a href="./README_EN.md">English</a> · <a href="./LICENSE">MIT License</a>
</p>

---

## 为什么选 Cube Chat？

- 完全使用 ArkTS 原生开发，不是 WebView 套壳
- 围绕鸿蒙 6（API 23）持续打磨，交互和系统行为适配更完整
- 界面精致，动态模糊、8 种配色主题、高级材质与玻璃质感都安排上了
- 适配手机、平板和大屏设备，布局更合理
- 服务商高度自定义，几秒添加任何 OpenAI / Anthropic / Gemini 兼容服务
- 工具中心支持远端 streamable MCP Server 接入，工具能力可继续扩展
- 简单易上手，填个 API Key 就能开聊
- 桌面小组件，快速发起对话
- 后台任务支持，切到其他应用也不耽误接收回复

## 最新界面预览

以下截图基于当前鸿蒙 6（API 23）版本：

<table>
  <tr>
    <td align="center"><img src="docs/screenshots/chat_new.png" width="200" /><br/><sub>对话</sub></td>
    <td align="center"><img src="docs/screenshots/settings_new.png" width="200" /><br/><sub>设置</sub></td>
    <td align="center"><img src="docs/screenshots/providers_new.jpg" width="200" /><br/><sub>服务商管理</sub></td>
    <td align="center"><img src="docs/screenshots/tool_calling_new.png" width="200" /><br/><sub>工具调用</sub></td>
  </tr>
  <tr>
    <td align="center"><img src="docs/screenshots/color_themes_new.png" width="200" /><br/><sub>配色主题</sub></td>
    <td align="center"><img src="docs/screenshots/blur_preview.png" width="200" /><br/><sub>玻璃质感</sub></td>
    <td align="center"><img src="docs/screenshots/latex_preview_new.png" width="200" /><br/><sub>公式预览</sub></td>
    <td align="center"><img src="docs/screenshots/html_preview_new.png" width="200" /><br/><sub>HTML 预览</sub></td>
  </tr>
</table>

## 1.3.0 版本亮点

本次版本为后续应用市场上架做准备，应用名称以 Cube Chat 为准，并更新图标资源；同时补齐图像生成、文档附件解析、图片预览等能力，并继续打磨聊天页、智感握姿和平板端体验。

### 新增
- 新增图像生成入口、生成页、结果网格、历史图库和模型能力识别
- 图像生成支持参考图、比例选择、生成设置、结果预览与保存
- 新增图像提示词模板库，支持模板管理和一键套用
- 新增 Word、PDF、Excel 等多种文档附件解析能力

### 优化
- 统一聊天图片预览体验，支持聊天图片、草稿图片、编辑消息图片和图像生成结果点击预览
- 缩略图根据图片实际比例自适应展示，减少固定比例裁切
- 优化图片保存、原图预览和图库网格显示
- 优化聊天流式渲染和等待态，保留 3D 加载指示效果
- 改进代码块、HTML 和 Mermaid 的流式预览行为
- 增加聊天页快捷跳转按钮的自动显隐逻辑
- 优化表格内容配色，提升可读性
- 优化工具调用能力探测，减少不支持工具调用模型时的异常体验
- 优化模型请求传参逻辑，提高请求的兼容性
- 扩展智感握姿适配范围，聊天输入栏、发送按钮、返回底部按钮等位置跟随握持偏好调整
- 首页底部 HdsTabs 支持随列表滚动自动隐藏 / 显示
- 优化助手卡片布局，提升卡片密度和视觉层级
- 优化整体布局、主题页、首页、Tab、设置入口等 UI 质感

### 修复
- 修复部分情况下任务结束异常导致状态未清空的问题
- 修复平板分栏空状态下的异常布局

## 功能特性

### 和任何模型对话

内置 15+ AI 服务商，填入 API Key 选个模型就能聊。支持自定义添加任何 OpenAI / Anthropic / Gemini 兼容的服务商，几秒搞定。

### 工具、联网搜索与 MCP

内置联网搜索，支持 Bing(local)、Tavily、Exa。支持 Function Calling 的模型可以自主调用工具获取实时信息，工具中心也支持接入远端 streamable MCP Server，把能力继续往外扩。

### Markdown 及更多

完整的 Markdown 渲染，支持语法高亮代码块、表格、LaTeX 公式、图片。甚至原始 HTML 也能实时预览。

### 好看，好用

8 种配色主题，深色 / 浅色 / 跟随系统。基于 API 23 的高级材质、沉浸光感和玻璃质感持续打磨。原生 UI 的流畅感，因为它就是原生的。

### 手机、平板都顺手

针对手机、平板和大屏设备做了布局适配。聊天、设置、服务商管理等页面在更大屏幕上也能保持清晰、顺手的使用体验。

### 智感握姿

检测你用哪只手握着手机，自动把「新对话」按钮移到够得着的一侧。单手操作，就该这么简单。

### 数据在你手里

导出和导入一切，对话、服务商配置、偏好设置都能带走。JSON 格式，没有锁定。

### 后台也不掉线

切到其他应用等待长回复？Cube Chat 在后台继续工作，回复完成后通知你。

## 支持的服务商

| 服务商 | API 格式 | 说明 |
|--------|---------|------|
| OpenAI | OpenAI | GPT-4o、o1 等 |
| Claude | Anthropic | Claude 4、3.5 等 |
| DeepSeek | OpenAI 兼容 | DeepSeek-V3、R1 等 |
| Gemini | Google | Gemini 2.5 等 |
| Grok | OpenAI 兼容 | xAI 模型 |
| Ollama | OpenAI 兼容 | 本地模型 |
| OpenRouter | OpenAI 兼容 | 多服务商网关 |
| 硅基流动 | OpenAI 兼容 | 国产 AI 模型 |
| 阿里云百炼 | OpenAI 兼容 | 通义千问系列 |
| Kimi | OpenAI 兼容 | Moonshot / Kimi 模型 |
| 智谱 AI | OpenAI 兼容 | GLM 系列 |
| 火山引擎 | OpenAI 兼容 | 豆包系列 |
| MiniMax | OpenAI 兼容 | MiniMax 模型 |
| AiHubMix | OpenAI 兼容 | 多服务商网关 |
| MiMo | OpenAI 兼容 | 小米 MiMo 模型 |

……或者自己添加任何兼容的服务商。

## 快速开始

### 环境要求

- 鸿蒙 6（API 23）
- DevEco Studio 5.0+

### 构建运行

```bash
git clone https://github.com/LongLiveY96/ChatCube.git
cd ChatCube
cp build-profile.json5.example build-profile.json5
# 编辑 build-profile.json5 填入你的签名配置
```

用 DevEco Studio 打开 → 同步 → 运行。

### 邀请测试

已开启华为应用市场邀测，欢迎体验最新版本：

- 邀测地址（活码,始终指向最新版本）：<https://beta.04160518.xyz/r>

当前邀测版本基于鸿蒙 6（API 23）。

### 配置服务商

在应用中：**设置 → 服务商管理** → 添加你的 API Key。

## 项目结构

```
entry/src/main/ets/
├── components/         # 可复用 UI 组件
├── config/             # 应用和服务商配置
├── models/             # 数据模型
├── pages/              # 应用页面
├── services/           # 业务逻辑服务
├── viewmodels/         # ViewModel（MVVM）
├── utils/              # 工具函数
└── widget/             # 桌面小组件
```

## 交流反馈

欢迎加入 Cube Chat 交流反馈群，一起提建议、聊体验、报问题。

- QQ 群号：`752237762`

<p align="center">
  <img src="assets/qrcode_1772160303793.jpg" width="280" alt="Cube Chat QQ 群二维码" />
</p>

## English README

英文说明请查看：[README_EN.md](./README_EN.md)

## 许可证

[MIT](./LICENSE) — 随便用，开心就好。

## 赞助支持

如果 Cube Chat 对你有帮助,欢迎自愿赞助开发。**赞助完全自愿,不影响应用任何功能的使用,也不会解锁任何隐藏内容。**

### 赞助方式

扫码微信打赏:

<p align="center">
  <img src="assets/wechat-pay.png" width="240" alt="Cube Chat 微信打赏码" />
</p>

> 💡 微信打赏时请在备注里写下 **QQ 号或其他联系方式**,作者会通过 QQ 群联系你并兑现下面的福利。

### 你的支持将用于

- 购买各模型的 API token,联调和测试不同服务商
- 服务器、域名、邀测发布等基础开支
- 持续迭代和打磨 Cube Chat

### 赞助者福利

- **优先响应** —— 你提的需求 / Bug 进入优先处理队列
- **自用 token 分享** —— 不定期分享作者自用的 AI 服务 token,用于个人学习测试

> 交流 QQ 群:`752237762`
