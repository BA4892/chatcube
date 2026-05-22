<p align="center">
  <img src="AppScope/resources/base/media/foreground.png" width="120" />
</p>

<h1 align="center">ChatCube</h1>

<p align="center">
  A native AI chat client for HarmonyOS 6 (API 23).<br/>
  One app, 15+ providers, web search, MCP, and ArkTS-native UX.
</p>

<p align="center">
  <a href="./README.md">简体中文</a> · <a href="./LICENSE">MIT License</a>
</p>

---

## Why ChatCube?

- Built entirely with ArkTS — a true HarmonyOS native app, not a web wrapper
- Continuously refined around HarmonyOS 6 (API 23), with better alignment to current system behavior
- Polished UI with dynamic blur, 8 color themes, advanced materials, and glass-like surfaces
- Adaptive layouts for phones, tablets, and large screens
- Highly customizable providers — add any OpenAI / Anthropic / Gemini compatible service in seconds
- The tools center can connect to remote streamable MCP servers for expandable tool capability
- Simple and intuitive — configure your API key and start chatting
- Home screen widget for quick access
- Background task support — keep receiving replies while multitasking

## Latest Screens

These screenshots reflect the current HarmonyOS 6 (API 23) build:

<table>
  <tr>
    <td align="center"><img src="docs/screenshots/chat_new.png" width="200" /><br/><sub>Chat</sub></td>
    <td align="center"><img src="docs/screenshots/settings_new.png" width="200" /><br/><sub>Settings</sub></td>
    <td align="center"><img src="docs/screenshots/providers_new.jpg" width="200" /><br/><sub>Providers</sub></td>
    <td align="center"><img src="docs/screenshots/tool_calling_new.png" width="200" /><br/><sub>Tool Calling</sub></td>
  </tr>
  <tr>
    <td align="center"><img src="docs/screenshots/color_themes_new.png" width="200" /><br/><sub>Themes</sub></td>
    <td align="center"><img src="docs/screenshots/blur_preview.png" width="200" /><br/><sub>Glass Surface</sub></td>
    <td align="center"><img src="docs/screenshots/latex_preview_new.png" width="200" /><br/><sub>Formula Preview</sub></td>
    <td align="center"><img src="docs/screenshots/html_preview_new.png" width="200" /><br/><sub>HTML Preview</sub></td>
  </tr>
</table>

## Highlights in 1.3.0

This release prepares the app for future marketplace submission, including the app rename and refreshed icon assets. It also adds image generation, document attachment parsing, and unified image preview capabilities, while refining chat streaming, Smart Grip, and tablet details.

### Added
- Added an image generation entry, generation page, result grid, gallery history, and model capability detection
- Image generation now supports reference images, aspect ratio selection, generation settings, result preview, and saving
- Added an image prompt template library with template management and one-tap application
- Added document attachment parsing for Word, PDF, Excel, and more

### Improved
- Unified image preview across chat images, draft images, edited-message images, and image generation results
- Thumbnails now adapt to the actual image aspect ratio, reducing fixed-ratio cropping
- Improved image saving, original-image preview, and gallery grid display
- Improved chat streaming rendering and waiting states while keeping the 3D loading indicator
- Improved streaming preview behavior for code blocks, HTML, and Mermaid
- Added auto show / hide behavior for the chat page quick-jump button
- Improved table color contrast and readability
- Improved tool-calling capability probing to reduce issues with models that do not support tool calling
- Improved model request parameter handling for better compatibility
- Extended Smart Grip adaptation to the chat input bar, send button, and scroll-to-bottom controls
- Bottom HdsTabs on the home page now hide / show automatically while scrolling
- Improved assistant card layout for better density and visual hierarchy
- Refined the overall UI quality across layout, theme pages, home page, tabs, and settings entries

### Fixed
- Fixed task state not being cleared in some abnormal completion cases
- Fixed abnormal layout in the tablet split-view empty state

## Features

### Talk to any model

Connect to 15+ AI providers out of the box. Bring your own API key, pick a model, and start chatting. Add any OpenAI / Anthropic / Gemini compatible provider in seconds.

### Tools, web search, and MCP

Built-in web search supports Bing(local), Tavily, and Exa. When a model supports function calling, it can use tools directly, and the tools center can also connect to remote streamable MCP servers.

### Markdown & beyond

Full markdown rendering — code blocks with syntax highlighting, tables, LaTeX formulas, images. Even raw HTML gets a live preview.

### Looks good, feels good

8 color themes. Dark / Light / System mode. API 23 materials, immersive glass-like effects, and real-time blur are all part of the current visual system. A UI that feels native because it is native.

### Phone & tablet ready

Responsive layouts for phones and HarmonyOS tablets. Chat, settings, and provider management all stay comfortable on larger screens.

### Smart Grip

Detects which hand you're holding the phone with and moves the "New Chat" button to the reachable side. One-handed use, done right.

### Your data, your rules

Export and import everything — conversations, provider configs, preferences. JSON format, no lock-in.

### Stays alive in the background

Switch to another app while waiting for a long response. ChatCube keeps working and notifies you when the reply is ready.

## Supported Providers

| Provider | API Format | Notes |
|----------|-----------|-------|
| OpenAI | OpenAI | GPT-4o, o1, etc. |
| Claude | Anthropic | Claude 4, 3.5, etc. |
| DeepSeek | OpenAI-compatible | DeepSeek-V3, R1, etc. |
| Gemini | Google | Gemini 2.5, etc. |
| Grok | OpenAI-compatible | xAI models |
| Ollama | OpenAI-compatible | Local models |
| OpenRouter | OpenAI-compatible | Multi-provider gateway |
| SiliconFlow | OpenAI-compatible | Chinese AI models |
| Qwen (Alibaba) | OpenAI-compatible | Qwen series |
| Kimi | OpenAI-compatible | Moonshot / Kimi models |
| Zhipu AI | OpenAI-compatible | GLM series |
| Doubao (Volcengine) | OpenAI-compatible | Doubao series |
| MiniMax | OpenAI-compatible | MiniMax models |
| AiHubMix | OpenAI-compatible | Multi-provider gateway |
| MiMo | OpenAI-compatible | Xiaomi MiMo models |

...or add any compatible provider yourself.

## Getting Started

### Requirements

- HarmonyOS 6 (API 23)
- DevEco Studio 5.0+

### Build & Run

```bash
git clone https://github.com/LongLiveY96/ChatCube.git
cd ChatCube
cp build-profile.json5.example build-profile.json5
# Edit build-profile.json5 with your signing config
```

Open in DevEco Studio → Sync → Run.

### Configure providers

In the app: **Settings → Provider Management** → add your API keys.

## Project Structure

```
entry/src/main/ets/
├── components/         # Reusable UI components
├── config/             # App & provider configuration
├── models/             # Data models
├── pages/              # App pages
├── services/           # Business logic
├── viewmodels/         # ViewModels (MVVM)
├── utils/              # Utilities
└── widget/             # Home screen widget
```

## Community

For the Chinese beta test link and community group, see the main Chinese README: [README.md](./README.md).

## License

[MIT](./LICENSE) — do whatever you want with it.
