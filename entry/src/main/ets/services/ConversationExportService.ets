import {
  AttachmentType,
  ChatMessage,
  MessageAttachment,
  MessageRole,
  SearchReference,
  ToolCall
} from '../models/ChatModels'
import { MessagePart, MessagePartKind, ToolPartStatus } from '../models/MessageParts'
import { getAppUiState } from '../state/AppUiState'
import { common } from '@kit.AbilityKit'
import { fileIo as fs, fileUri } from '@kit.CoreFileKit'
import { util } from '@kit.ArkTS'
import { getAssistantAvatarFallbackText, resolveAssistantAvatarRenderSource } from '../components/AssistantAvatar'
import { buildModelIconRenderData } from '../utils/ModelIconRenderUtils'
import {
  buildMessagePartsFromLegacy,
  groupMessageParts,
  MessagePartBlock,
  MessagePartBlockKind
} from '../utils/ChatMessagePartsHelper'
import {
  buildToolArgumentsPreview,
  buildToolResultPreview,
  ToolPreviewEntry
} from '../utils/ToolPayloadSummaryUtils'
import { buildToolTitle } from '../utils/ToolTitleBuilder'
import { isSearchWebFunctionName } from '../utils/SearchToolIdentityUtils'
import { ColorTheme, getThemeColors, ThemeColorConfig } from '../models/ThemeColors'
import { stripMarkdownForPlainTextExport } from '../utils/MarkdownPlainTextUtil'

const HTML_INLINE_IMAGE_MAX_BYTES: number = 1024 * 1024
const EXPORT_TOOL_ARGUMENT_PREVIEW_MAX_LENGTH: number = 1200
const EXPORT_TOOL_RESULT_PREVIEW_MAX_LENGTH: number = 1800
const EXPORT_BLOCK_KIND_THINKING: string = 'thinking'
const EXPORT_BLOCK_KIND_CONTENT: string = 'content'
const EXPORT_PART_TYPE_TEXT: string = 'text'
const EXPORT_PART_TYPE_MEDIA: string = 'media'
const EXPORT_TIMELINE_TYPE_REASONING: string = 'reasoning'
const EXPORT_TIMELINE_TYPE_TOOL: string = 'tool'
const EXPORT_PROMO_URL: string = 'https://969991.xyz'

interface ConversationExportToolSearchResultItemPayload {
  title?: string
  url?: string
  snippet?: string
}

interface ConversationExportToolSearchResultPayload {
  results?: ConversationExportToolSearchResultItemPayload[]
}

export class ConversationExportAttachment {
  id: string = ''
  type: string = ''
  name: string = ''
  mimeType: string = ''
  size: number = 0
}

class ConversationExportReference {
  title: string = ''
  url: string = ''
  snippet: string = ''
}

class ConversationExportKeyValue {
  label: string = ''
  value: string = ''
}

class ConversationExportContentPart {
  type: string = EXPORT_PART_TYPE_TEXT
  text: string = ''
  mediaLabel: string = ''
  mediaName: string = ''
  mediaUrl: string = ''
}

class ConversationExportTimelineItem {
  type: string = EXPORT_TIMELINE_TYPE_REASONING
  title: string = ''
  text: string = ''
  status: string = ''
  statusLabel: string = ''
  statusTone: string = ''
  sourceLabel: string = ''
  argumentsSummary: string = ''
  resultSummary: string = ''
  argumentEntries: ConversationExportKeyValue[] = []
  resultEntries: ConversationExportKeyValue[] = []
  argumentPreview: string = ''
  resultPreview: string = ''
  argumentTruncated: boolean = false
  resultTruncated: boolean = false
  references: ConversationExportReference[] = []
  isError: boolean = false
}

class ConversationExportBlock {
  kind: string = EXPORT_BLOCK_KIND_CONTENT
  contentParts: ConversationExportContentPart[] = []
  timelineItems: ConversationExportTimelineItem[] = []
}

export class ConversationExportMessage {
  id: string = ''
  role: MessageRole = MessageRole.ASSISTANT
  roleLabel: string = ''
  content: string = ''
  reasoningContent: string = ''
  timestamp: number = 0
  modelName: string = ''
  modelId: string = ''
  avatarImageSource: string = ''
  attachments: ConversationExportAttachment[] = []
  blocks: ConversationExportBlock[] = []
}

export class ConversationExportModel {
  appName: string = 'Cube Chat'
  title: string = '对话记录'
  exportedAt: number = 0
  messages: ConversationExportMessage[] = []
}

class HtmlExportTheme {
  isDarkMode: boolean = false
  chatFontSize: number = 15
  primary: string = '#4E6F9E'
  primaryLight: string = '#D8E2EE'
  background: string = '#FAF8F3'
  surface: string = '#FFFDF8'
  divider: string = '#DED8CC'
  bubbleBorder: string = 'rgba(0, 0, 0, 0.06)'
  textPrimary: string = '#24211C'
  textSecondary: string = '#6F6A60'
  textTertiary: string = '#8A8178'
  userBubble: string = '#52688A'
  userBubbleText: string = '#FFFFFF'
  aiBubble: string = '#FFFDF8'
  markdownText: string = '#3D3830'
  markdownTitle: string = '#24211C'
  markdownLink: string = '#4E6F9E'
  markdownCodeBg: string = '#F3EFE8'
  markdownCodeText: string = '#8F5E45'
  markdownQuoteBg: string = '#F3EFE8'
  markdownTableBg: string = '#FFFDF8'
  markdownTableHeaderBg: string = '#F3EFE8'
  markdownTableAltBg: string = '#FAF7F0'
  markdownTableBorder: string = '#DED8CC'
}

class ConversationHtmlExportData {
  appName: string = 'Cube Chat'
  title: string = '对话记录'
  exportedAt: number = 0
  exportedAtText: string = ''
  promoUrl: string = EXPORT_PROMO_URL
  themeMode: string = 'light'
  assistantAvatarValue: string = 'AI'
  assistantAvatarColor: string = '#4E6F9E'
  assistantAvatarImageSource: string = ''
  theme: HtmlExportTheme = new HtmlExportTheme()
  messages: ConversationExportMessage[] = []
}

export class ConversationExportService {
  buildModel(messages: ChatMessage[], title: string = '', appName: string = 'Cube Chat'): ConversationExportModel {
    const model = new ConversationExportModel()
    model.appName = appName
    model.title = this.resolveModelTitle(title)
    model.exportedAt = Date.now()
    model.messages = []

    for (let i = 0; i < messages.length; i++) {
      model.messages.push(this.buildMessage(messages[i]))
    }
    return model
  }

  private resolveModelTitle(title: string): string {
    const value = title.trim()
    return value !== '' ? value : '对话记录'
  }

  toMarkdown(model: ConversationExportModel): string {
    const lines: string[] = []
    lines.push(`# ${model.title}`)
    lines.push('')
    lines.push(`> 导出时间: ${this.formatDateTime(model.exportedAt)}`)
    lines.push('')
    lines.push('---')
    lines.push('')

    for (let i = 0; i < model.messages.length; i++) {
      const message = model.messages[i]
      const time = this.formatTime(message.timestamp)
      lines.push(`### ${message.roleLabel} · ${time}`)
      lines.push('')

      if (message.content.trim().length > 0) {
        lines.push(message.content)
        lines.push('')
      }

      this.appendMarkdownAttachments(lines, message.attachments)

      if (message.reasoningContent.trim().length > 0) {
        lines.push('<details>')
        lines.push('<summary>思考过程</summary>')
        lines.push('')
        lines.push(message.reasoningContent)
        lines.push('</details>')
        lines.push('')
      }

      lines.push('---')
      lines.push('')
    }
    return lines.join('\n')
  }

  toPlainText(model: ConversationExportModel): string {
    const lines: string[] = []
    lines.push('=== 对话记录 ===')
    lines.push(`导出时间: ${this.formatDateTime(model.exportedAt)}`)
    lines.push('')

    for (let i = 0; i < model.messages.length; i++) {
      const message = model.messages[i]
      lines.push(`[${message.roleLabel}] ${this.formatTime(message.timestamp)}`)

      const plainContent = stripMarkdownForPlainTextExport(message.content)
      if (plainContent.length > 0) {
        lines.push(plainContent)
      }

      this.appendPlainTextAttachments(lines, message.attachments)

      const plainReasoning = stripMarkdownForPlainTextExport(message.reasoningContent)
      if (plainReasoning.length > 0) {
        lines.push('')
        lines.push('[思考过程]')
        lines.push(plainReasoning)
      }

      lines.push('')
      lines.push('---')
      lines.push('')
    }
    return lines.join('\n')
  }

  toHtml(model: ConversationExportModel, assistantAvatarValue: string = 'AI', assistantAvatarColor: string = '',
    currentModelId: string = '', assistantAvatarCacheKey: number = 0,
    context: common.UIAbilityContext | null = null): string {
    const theme = this.getHtmlExportTheme()
    const lightTheme = this.getHtmlExportThemeForMode(false)
    const darkTheme = this.getHtmlExportThemeForMode(true)
    const appIconSource = this.resolveAppIconSource(context)
    const data = new ConversationHtmlExportData()
    data.appName = model.appName
    data.title = model.title
    data.exportedAt = model.exportedAt
    data.exportedAtText = this.formatHtmlExportDateTime(model.exportedAt)
    data.promoUrl = EXPORT_PROMO_URL
    data.themeMode = theme.isDarkMode ? 'dark' : 'light'
    data.assistantAvatarValue = this.resolveAvatarText(assistantAvatarValue)
    data.assistantAvatarColor = assistantAvatarColor.trim() !== '' ? this.toCssColor(assistantAvatarColor, theme.primary) : ''
    data.assistantAvatarImageSource = this.resolveWebImageSource(
      resolveAssistantAvatarRenderSource(assistantAvatarValue, assistantAvatarCacheKey)
    )
    data.theme = theme
    data.messages = this.buildHtmlMessages(model.messages, currentModelId, context)

    const json = this.escapeJsonForScript(JSON.stringify(data))
    const css = this.buildHtmlCss(lightTheme, darkTheme, theme.isDarkMode)

    return [
      '<!doctype html>',
      `<html lang="zh-CN" class="${theme.isDarkMode ? 'theme-dark' : 'theme-light'}">`,
      '<head>',
      '<meta charset="utf-8">',
      '<meta name="viewport" content="width=device-width, initial-scale=1">',
      `<meta name="color-scheme" content="${theme.isDarkMode ? 'dark' : 'only light'}">`,
      `<title>${this.escapeHtml(model.title)} - ${this.escapeHtml(model.appName)}</title>`,
      '<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/katex.min.css">',
      '<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/markdown-it-texmath@1.0.0/css/texmath.min.css">',
      `<link id="highlight-style-light" rel="stylesheet" href="${this.getHighlightStyleUrl(false)}"${theme.isDarkMode ? ' disabled' : ''}>`,
      `<link id="highlight-style-dark" rel="stylesheet" href="${this.getHighlightStyleUrl(true)}"${theme.isDarkMode ? '' : ' disabled'}>`,
      '<style>',
      css,
      '</style>',
      '</head>',
      `<body class="${theme.isDarkMode ? 'theme-dark' : 'theme-light'}">`,
      '<main class="share-shell">',
      '<section class="chat-frame">',
      '<header class="chat-header">',
      '<div class="header-brand">',
      this.buildAppIconHtml(appIconSource),
      '<div class="header-title">',
      `<div class="app-name">${this.escapeHtml(model.appName)}</div>`,
      '<div class="app-subtitle">对话记录</div>',
      '</div>',
      '</div>',
      '<div class="header-conversation">',
      `<div class="conversation-title">${this.escapeHtml(model.title)}</div>`,
      '<div class="conversation-subtitle">会话分享</div>',
      '</div>',
      '<div class="header-actions">',
      '<button id="theme-toggle" class="theme-toggle" type="button" aria-label="切换深浅色主题" title="切换深浅色主题">',
      '<span class="theme-toggle-icon" aria-hidden="true">☾</span>',
      '<span class="theme-toggle-text">深色</span>',
      '</button>',
      `<div class="export-time">${this.escapeHtml(data.exportedAtText)}</div>`,
      '</div>',
      '</header>',
      '<section id="message-list" class="message-list">',
      '<div class="loading-text">正在渲染对话...</div>',
      '</section>',
      '<noscript>',
      `<pre class="noscript-fallback">${this.buildNoScriptFallback(model)}</pre>`,
      '</noscript>',
      '<footer class="chat-footer">',
      '<div class="footer-note">内容由 AI 生成，请注意核验关键信息</div>',
      '<section class="footer-promo" aria-label="Cube Chat 官网">',
      '<div class="footer-promo-copy">',
      '<div class="footer-promo-kicker">Cube Chat</div>',
      '<div class="footer-promo-title">更顺手的 AI 对话助手</div>',
      '<div class="footer-promo-desc">访问官网了解下载、更新与更多功能。</div>',
      `<a class="footer-promo-link" href="${this.escapeHtml(EXPORT_PROMO_URL)}" target="_blank" rel="noopener noreferrer">969991.xyz</a>`,
      '</div>',
      `<a class="footer-qr-link" href="${this.escapeHtml(EXPORT_PROMO_URL)}" target="_blank" rel="noopener noreferrer" aria-label="打开 Cube Chat 官网">`,
      '<div id="promo-qr" class="footer-qr">',
      '<span>969991.xyz</span>',
      '</div>',
      '<div class="footer-qr-caption">扫码访问</div>',
      '</a>',
      '</section>',
      '</footer>',
      '</section>',
      '</main>',
      `<script id="chatcube-export-data" type="application/json">${json}</script>`,
      this.buildVendorScripts(),
      this.buildRenderScript(theme),
      '</body>',
      '</html>'
    ].join('\n')
  }

  private buildMessage(message: ChatMessage): ConversationExportMessage {
    const parts = buildMessagePartsFromLegacy(message, false)
    const exportMessage = new ConversationExportMessage()
    exportMessage.id = message.id
    exportMessage.role = message.role
    exportMessage.roleLabel = this.getRoleLabel(message.role)
    exportMessage.content = this.resolveMessageContent(message, parts)
    exportMessage.reasoningContent = this.resolveReasoningContent(message, parts)
    exportMessage.timestamp = message.timestamp
    exportMessage.modelName = message.modelName
    exportMessage.modelId = message.modelId
    exportMessage.attachments = this.buildAttachments(message.attachments)
    exportMessage.blocks = this.buildMessageBlocks(message, parts)
    return exportMessage
  }

  private resolveMessageContent(message: ChatMessage, parts: MessagePart[]): string {
    if (parts.length === 0) {
      return message.content
    }

    const textParts: string[] = []
    for (let i = 0; i < parts.length; i++) {
      const part = parts[i]
      if (part.kind === MessagePartKind.TEXT && part.text.trim().length > 0) {
        textParts.push(part.text)
      } else if (this.isMediaPart(part)) {
        const mediaName = part.mediaName !== '' ? part.mediaName : part.mediaUrl
        if (mediaName !== '') {
          textParts.push(`[${this.getMediaPartLabel(part.kind)}: ${mediaName}]`)
        }
      }
    }

    if (textParts.length === 0) {
      return message.content
    }
    return textParts.join('\n\n')
  }

  private resolveReasoningContent(message: ChatMessage, parts: MessagePart[]): string {
    if (parts.length === 0) {
      return message.reasoningContent
    }

    const reasoningParts: string[] = []
    for (let i = 0; i < parts.length; i++) {
      const part = parts[i]
      if (part.kind === MessagePartKind.REASONING && part.text.trim().length > 0) {
        reasoningParts.push(part.text)
      }
    }

    if (reasoningParts.length === 0) {
      return message.reasoningContent
    }
    return reasoningParts.join('\n\n')
  }

  private buildMessageBlocks(message: ChatMessage, parts: MessagePart[]): ConversationExportBlock[] {
    if (parts.length === 0) {
      return this.buildFallbackBlocks(message)
    }

    const result: ConversationExportBlock[] = []
    const blocks = groupMessageParts(parts)
    for (let i = 0; i < blocks.length; i++) {
      const block = this.buildExportBlock(message, blocks[i], parts)
      if (block.contentParts.length > 0 || block.timelineItems.length > 0) {
        result.push(block)
      }
    }
    if (result.length === 0) {
      return this.buildFallbackBlocks(message)
    }
    return result
  }

  private buildFallbackBlocks(message: ChatMessage): ConversationExportBlock[] {
    const result: ConversationExportBlock[] = []
    if (message.content.trim() !== '') {
      const block = new ConversationExportBlock()
      block.kind = EXPORT_BLOCK_KIND_CONTENT
      const part = new ConversationExportContentPart()
      part.type = EXPORT_PART_TYPE_TEXT
      part.text = message.content
      block.contentParts.push(part)
      result.push(block)
    }
    return result
  }

  private buildExportBlock(message: ChatMessage, block: MessagePartBlock,
    allParts: MessagePart[]): ConversationExportBlock {
    const exportBlock = new ConversationExportBlock()
    exportBlock.kind = block.kind === MessagePartBlockKind.THINKING ? EXPORT_BLOCK_KIND_THINKING : EXPORT_BLOCK_KIND_CONTENT
    if (block.kind === MessagePartBlockKind.THINKING) {
      for (let i = 0; i < block.parts.length; i++) {
        const item = this.buildTimelineItem(message, block.parts[i], allParts)
        if (item !== null) {
          exportBlock.timelineItems.push(item)
        }
      }
    } else {
      for (let i = 0; i < block.parts.length; i++) {
        const item = this.buildContentPart(block.parts[i])
        if (item !== null) {
          exportBlock.contentParts.push(item)
        }
      }
    }
    return exportBlock
  }

  private buildContentPart(part: MessagePart): ConversationExportContentPart | null {
    if (part.kind === MessagePartKind.TEXT) {
      if (part.text.trim() === '') {
        return null
      }
      const item = new ConversationExportContentPart()
      item.type = EXPORT_PART_TYPE_TEXT
      item.text = part.text
      return item
    }
    if (this.isMediaPart(part)) {
      const item = new ConversationExportContentPart()
      item.type = EXPORT_PART_TYPE_MEDIA
      item.mediaLabel = this.getMediaPartLabel(part.kind)
      item.mediaName = part.mediaName !== '' ? part.mediaName : part.mediaUrl
      item.mediaUrl = part.mediaUrl
      return item
    }
    return null
  }

  private buildTimelineItem(message: ChatMessage, part: MessagePart,
    allParts: MessagePart[]): ConversationExportTimelineItem | null {
    if (part.kind === MessagePartKind.REASONING) {
      if (part.text.trim() === '') {
        return null
      }
      const item = new ConversationExportTimelineItem()
      item.type = EXPORT_TIMELINE_TYPE_REASONING
      item.title = '思考过程'
      item.text = part.text
      return item
    }
    if (part.kind === MessagePartKind.TOOL) {
      return this.buildToolTimelineItem(message, part, allParts)
    }
    return null
  }

  private buildToolTimelineItem(message: ChatMessage, part: MessagePart,
    allParts: MessagePart[]): ConversationExportTimelineItem {
    const item = new ConversationExportTimelineItem()
    const argumentPreview = buildToolArgumentsPreview(part.toolArguments, 4, EXPORT_TOOL_ARGUMENT_PREVIEW_MAX_LENGTH)
    const resultPreview = buildToolResultPreview(part.toolResult, 4, EXPORT_TOOL_RESULT_PREVIEW_MAX_LENGTH)
    item.type = EXPORT_TIMELINE_TYPE_TOOL
    item.title = this.buildToolStepTitle(part)
    item.status = part.toolStatus
    item.statusLabel = this.buildToolStatusLabel(part)
    item.statusTone = this.buildToolStatusTone(part)
    item.sourceLabel = part.toolSourceLabel
    item.argumentsSummary = argumentPreview.summary
    item.resultSummary = part.toolResult.trim() !== '' ? resultPreview.summary : ''
    item.argumentEntries = this.buildPreviewEntries(argumentPreview.entries)
    item.resultEntries = this.buildPreviewEntries(resultPreview.entries)
    item.argumentPreview = argumentPreview.rawPreview
    item.resultPreview = part.toolResult.trim() !== '' ? resultPreview.rawPreview : ''
    item.argumentTruncated = argumentPreview.rawTruncated
    item.resultTruncated = resultPreview.rawTruncated
    item.references = this.resolveToolStepReferences(message, part, allParts)
    item.isError = part.toolIsError
    return item
  }

  private buildPreviewEntries(entries: ToolPreviewEntry[]): ConversationExportKeyValue[] {
    const result: ConversationExportKeyValue[] = []
    for (let i = 0; i < entries.length; i++) {
      const item = new ConversationExportKeyValue()
      item.label = entries[i].label
      item.value = entries[i].value
      result.push(item)
    }
    return result
  }

  private buildToolStepTitle(part: MessagePart): string {
    if (part.toolDisplayName.trim() !== '' && part.toolDisplayName !== part.toolName) {
      return part.toolDisplayName
    }
    const toolCall = new ToolCall(
      part.toolCallId,
      part.toolName,
      part.toolArguments,
      '',
      part.toolDisplayName,
      part.toolSourceType,
      part.toolSourceLabel,
      part.toolPermissionLevel
    )
    return buildToolTitle(toolCall)
  }

  private buildToolStatusLabel(part: MessagePart): string {
    if (part.toolApprovalState === 'pending') {
      return '待确认'
    }
    if (part.toolStatus === ToolPartStatus.RUNNING) {
      return '进行中'
    }
    if (part.toolStatus === ToolPartStatus.SUCCEEDED) {
      return '完成'
    }
    if (part.toolStatus === ToolPartStatus.FAILED) {
      return '失败'
    }
    if (part.toolStatus === ToolPartStatus.DENIED) {
      return '已拒绝'
    }
    if (part.toolStatus === ToolPartStatus.ANSWERED) {
      return '已回答'
    }
    if (part.toolStatus === ToolPartStatus.PENDING) {
      return '进行中'
    }
    return part.toolStatus
  }

  private buildToolStatusTone(part: MessagePart): string {
    if (part.toolStatus === ToolPartStatus.SUCCEEDED || part.toolStatus === ToolPartStatus.ANSWERED) {
      return 'success'
    }
    if (part.toolStatus === ToolPartStatus.FAILED || part.toolStatus === ToolPartStatus.DENIED || part.toolIsError) {
      return 'error'
    }
    if (part.toolApprovalState === 'pending') {
      return 'pending'
    }
    return 'running'
  }

  private resolveToolStepReferences(message: ChatMessage, part: MessagePart,
    allParts: MessagePart[]): ConversationExportReference[] {
    if (!isSearchWebFunctionName(part.toolName) || !this.isSuccessfulToolStep(part)) {
      return []
    }
    if (part.toolSearchReferences.length > 0) {
      return this.buildReferences(part.toolSearchReferences)
    }
    const refsFromResult = this.buildReferencesFromToolResult(part)
    if (refsFromResult.length > 0) {
      return refsFromResult
    }
    if (this.canUseAggregateSearchReferences(message, part, allParts)) {
      return this.buildReferences(message.searchReferences)
    }
    return []
  }

  private buildReferences(refs: SearchReference[]): ConversationExportReference[] {
    const result: ConversationExportReference[] = []
    for (let i = 0; i < refs.length; i++) {
      const item = new ConversationExportReference()
      item.title = refs[i].title
      item.url = refs[i].url
      item.snippet = refs[i].snippet
      result.push(item)
    }
    return result
  }

  private buildReferencesFromToolResult(part: MessagePart): ConversationExportReference[] {
    const raw = part.toolResult.trim()
    if (raw === '') {
      return []
    }
    try {
      const parsed = JSON.parse(raw) as ConversationExportToolSearchResultPayload
      if (!Array.isArray(parsed.results)) {
        return []
      }
      const result: ConversationExportReference[] = []
      for (let i = 0; i < parsed.results.length; i++) {
        const rawItem = parsed.results[i]
        const item = new ConversationExportReference()
        item.title = typeof rawItem.title === 'string' ? rawItem.title : ''
        item.url = typeof rawItem.url === 'string' ? rawItem.url : ''
        item.snippet = typeof rawItem.snippet === 'string' ? rawItem.snippet : ''
        if (item.title.trim() !== '' || item.url.trim() !== '' || item.snippet.trim() !== '') {
          result.push(item)
        }
      }
      return result
    } catch (_error) {
      return []
    }
  }

  private canUseAggregateSearchReferences(message: ChatMessage, part: MessagePart,
    allParts: MessagePart[]): boolean {
    if (message.searchReferences.length === 0 || !this.isSuccessfulToolStep(part)) {
      return false
    }
    let searchStepCount = 0
    for (let i = 0; i < allParts.length; i++) {
      const item = allParts[i]
      if (item.kind === MessagePartKind.TOOL && isSearchWebFunctionName(item.toolName) &&
        this.isSuccessfulToolStep(item)) {
        searchStepCount += 1
      }
    }
    return searchStepCount === 1
  }

  private isSuccessfulToolStep(part: MessagePart): boolean {
    return part.toolStatus === ToolPartStatus.SUCCEEDED && !part.toolIsError
  }

  private isMediaPart(part: MessagePart): boolean {
    return part.kind === MessagePartKind.IMAGE ||
      part.kind === MessagePartKind.VIDEO ||
      part.kind === MessagePartKind.AUDIO ||
      part.kind === MessagePartKind.DOCUMENT
  }

  private getMediaPartLabel(kind: MessagePartKind): string {
    if (kind === MessagePartKind.IMAGE) {
      return '图片'
    }
    if (kind === MessagePartKind.VIDEO) {
      return '视频'
    }
    if (kind === MessagePartKind.AUDIO) {
      return '音频'
    }
    return '文件'
  }

  private buildAttachments(attachments: MessageAttachment[]): ConversationExportAttachment[] {
    const result: ConversationExportAttachment[] = []
    for (let i = 0; i < attachments.length; i++) {
      const item = new ConversationExportAttachment()
      item.id = attachments[i].id
      item.type = attachments[i].type
      item.name = attachments[i].name
      item.mimeType = attachments[i].mimeType
      item.size = attachments[i].size
      result.push(item)
    }
    return result
  }

  private appendMarkdownAttachments(lines: string[], attachments: ConversationExportAttachment[]): void {
    if (attachments.length === 0) {
      return
    }
    lines.push('**附件**')
    lines.push('')
    for (let i = 0; i < attachments.length; i++) {
      lines.push(`- ${attachments[i].name}${this.formatAttachmentMeta(attachments[i])}`)
    }
    lines.push('')
  }

  private appendPlainTextAttachments(lines: string[], attachments: ConversationExportAttachment[]): void {
    if (attachments.length === 0) {
      return
    }
    lines.push('')
    lines.push('[附件]')
    for (let i = 0; i < attachments.length; i++) {
      lines.push(`- ${attachments[i].name}${this.formatAttachmentMeta(attachments[i])}`)
    }
  }

  private buildNoScriptFallback(model: ConversationExportModel): string {
    const lines: string[] = []
    lines.push(`${model.appName} - ${model.title}`)
    lines.push(`导出时间: ${this.formatDateTime(model.exportedAt)}`)
    lines.push('')
    for (let i = 0; i < model.messages.length; i++) {
      const message = model.messages[i]
      lines.push(`[${message.roleLabel}] ${this.formatTime(message.timestamp)}`)
      if (message.content.trim().length > 0) {
        lines.push(message.content)
      }
      this.appendPlainTextAttachments(lines, message.attachments)
      if (message.reasoningContent.trim().length > 0) {
        lines.push('')
        lines.push('[思考过程]')
        lines.push(message.reasoningContent)
      }
      lines.push('')
      lines.push('---')
      lines.push('')
    }
    return this.escapeHtml(lines.join('\n'))
  }

  private buildHtmlThemeVariables(theme: HtmlExportTheme): string {
    return [
      `  --primary: ${theme.primary};`,
      `  --primary-light: ${theme.primaryLight};`,
      `  --background: ${theme.background};`,
      `  --surface: ${theme.surface};`,
      `  --divider: ${theme.divider};`,
      `  --bubble-border: ${theme.bubbleBorder};`,
      `  --text-primary: ${theme.textPrimary};`,
      `  --text-secondary: ${theme.textSecondary};`,
      `  --text-tertiary: ${theme.textTertiary};`,
      `  --user-bubble: ${theme.userBubble};`,
      `  --user-bubble-text: ${theme.userBubbleText};`,
      `  --ai-bubble: ${theme.aiBubble};`,
      `  --markdown-text: ${theme.markdownText};`,
      `  --markdown-title: ${theme.markdownTitle};`,
      `  --markdown-link: ${theme.markdownLink};`,
      `  --code-bg: ${theme.markdownCodeBg};`,
      `  --code-text: ${theme.markdownCodeText};`,
      `  --quote-bg: ${theme.markdownQuoteBg};`,
      `  --table-bg: ${theme.markdownTableBg};`,
      `  --table-header-bg: ${theme.markdownTableHeaderBg};`,
      `  --table-alt-bg: ${theme.markdownTableAltBg};`,
      `  --table-border: ${theme.markdownTableBorder};`
    ].join('\n')
  }

  private buildHtmlCss(lightTheme: HtmlExportTheme, darkTheme: HtmlExportTheme,
    defaultIsDarkMode: boolean): string {
    const defaultTheme = defaultIsDarkMode ? darkTheme : lightTheme
    const defaultMode = defaultIsDarkMode ? 'dark' : 'light'
    return `
:root {
${this.buildHtmlThemeVariables(defaultTheme)}
  color-scheme: ${defaultMode === 'dark' ? 'dark' : 'only light'};
}
:root.theme-light {
${this.buildHtmlThemeVariables(lightTheme)}
  color-scheme: only light;
}
:root.theme-dark {
${this.buildHtmlThemeVariables(darkTheme)}
  color-scheme: dark;
}
* {
  box-sizing: border-box;
  forced-color-adjust: none;
}
html {
  min-height: 100%;
  background-color: var(--background);
  background: color-mix(in srgb, var(--background) 88%, var(--primary-light));
}
body {
  margin: 0;
  background-color: var(--background);
  background: linear-gradient(180deg,
    color-mix(in srgb, var(--primary-light) 30%, var(--background)) 0,
    var(--background) 260px);
  color: var(--text-primary);
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", "Noto Sans CJK SC", "Microsoft YaHei", sans-serif;
  font-size: ${defaultTheme.chatFontSize}px;
  line-height: 1.6;
  text-size-adjust: 100%;
}
.share-shell {
  width: 100%;
  min-height: 100vh;
  padding: clamp(0px, 3vw, 30px);
}
.chat-frame {
  width: min(980px, 100%);
  min-height: calc(100vh - clamp(0px, 6vw, 60px));
  margin: 0 auto;
  background: var(--background);
  border: 1px solid var(--divider);
  border-radius: 22px;
  box-shadow: 0 18px 54px rgba(18, 24, 38, 0.10);
  overflow: hidden;
}
.chat-header {
  position: sticky;
  top: 0;
  z-index: 10;
  display: grid;
  grid-template-columns: minmax(0, 1fr) minmax(180px, 1.35fr) minmax(0, 1fr);
  align-items: center;
  gap: 16px;
  padding: 15px 20px;
  border-bottom: 1px solid var(--divider);
  background: color-mix(in srgb, var(--surface) 88%, transparent);
  backdrop-filter: blur(18px);
}
.header-brand {
  display: flex;
  align-items: center;
  justify-self: start;
  max-width: 100%;
  min-width: 0;
}
.app-icon {
  flex: none;
  width: 28px;
  height: 28px;
  border-radius: 7px;
  overflow: hidden;
}
.app-icon-image {
  display: block;
  object-fit: contain;
  background: transparent;
}
.app-icon-fallback {
  display: grid;
  place-items: center;
  color: #fff;
  background: var(--primary);
  font-size: 15px;
  font-weight: 700;
}
.header-title {
  min-width: 0;
  margin-left: 10px;
}
.app-name {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  color: var(--text-primary);
  font-size: 15px;
  font-weight: 650;
  line-height: 1.25;
}
.app-subtitle {
  margin-top: 1px;
  color: var(--text-tertiary);
  font-size: 12px;
  line-height: 1.2;
}
.header-conversation {
  min-width: 0;
  text-align: center;
}
.conversation-title {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  color: var(--text-primary);
  font-size: 17px;
  font-weight: 720;
  line-height: 1.25;
}
.conversation-subtitle {
  margin-top: 2px;
  color: var(--text-tertiary);
  font-size: 11px;
  line-height: 1.2;
}
.header-actions {
  min-width: 0;
  max-width: 100%;
  display: flex;
  align-items: center;
  justify-self: end;
  gap: 10px;
}
.theme-toggle {
  flex: none;
  height: 30px;
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 0 10px;
  border: 1px solid var(--bubble-border);
  border-radius: 15px;
  color: var(--text-primary);
  background: color-mix(in srgb, var(--surface) 94%, var(--primary-light));
  font: inherit;
  font-size: 12px;
  line-height: 1;
  cursor: pointer;
}
.theme-toggle:hover {
  border-color: color-mix(in srgb, var(--primary) 45%, var(--bubble-border));
}
.theme-toggle:focus-visible {
  outline: 2px solid var(--primary-light);
  outline-offset: 2px;
}
.theme-toggle-icon {
  width: 14px;
  color: var(--markdown-link);
  font-size: 14px;
  line-height: 1;
  text-align: center;
}
.theme-toggle-text {
  white-space: nowrap;
}
.export-time {
  min-width: 0;
  max-width: 100%;
  overflow: hidden;
  text-overflow: ellipsis;
  color: var(--text-secondary);
  font-size: 12px;
  white-space: nowrap;
}
.message-list {
  padding: 18px 16px 10px;
}
.loading-text {
  padding: 24px 0;
  color: var(--text-secondary);
  text-align: center;
  font-size: 13px;
}
.message {
  display: flex;
  width: 100%;
  margin-bottom: 16px;
  gap: 10px;
}
.message.user {
  justify-content: flex-end;
}
.message.assistant,
.message.system,
.message.tool {
  justify-content: flex-start;
}
.message-main {
  min-width: 0;
}
.message.user .message-main {
  max-width: min(86%, 760px);
}
.message.user.rich .message-main {
  max-width: min(92%, 820px);
}
.message.assistant .message-main,
.message.system .message-main,
.message.tool .message-main {
  flex: 1;
  max-width: min(100%, 880px);
}
.assistant-avatar {
  flex: none;
  width: 30px;
  height: 30px;
  margin-top: 23px;
  border-radius: 8px;
  display: grid;
  place-items: center;
  color: #fff;
  font-size: 13px;
  font-weight: 650;
  overflow: hidden;
}
.assistant-avatar.has-image {
  background: transparent;
}
.assistant-avatar img {
  display: block;
  width: 100%;
  height: 100%;
  border-radius: inherit;
  object-fit: cover;
}
.message-meta {
  display: flex;
  align-items: center;
  gap: 8px;
  max-width: 100%;
  margin-bottom: 6px;
  color: var(--text-secondary);
  font-size: 12px;
  line-height: 1.25;
}
.message.user .message-meta {
  justify-content: flex-end;
}
.message-meta span {
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.bubble {
  overflow-wrap: anywhere;
  word-break: break-word;
}
.message.user .bubble {
  padding: 10px 14px;
  color: var(--user-bubble-text);
  background: var(--user-bubble);
  border: 0.5px solid rgba(255, 255, 255, 0.18);
  border-radius: 20px 20px 6px 20px;
}
.message.user.rich .bubble {
  color: var(--markdown-text);
  background: var(--surface);
  border: 0.5px solid var(--bubble-border);
  border-radius: 16px 16px 6px 16px;
}
.message.assistant .bubble,
.message.system .bubble,
.message.tool .bubble {
  width: 100%;
  padding: 10px 12px;
  color: var(--markdown-text);
  background: var(--ai-bubble);
  border: 0.5px solid var(--bubble-border);
  border-radius: 16px;
}
.message.system .bubble,
.message.tool .bubble {
  color: var(--text-secondary);
  background: var(--surface);
}
.markdown-body {
  font-size: ${Math.max(defaultTheme.chatFontSize - 1, 12)}px;
  line-height: ${Math.max(Math.round((defaultTheme.chatFontSize - 1) * 1.5), 19)}px;
}
.markdown-body p,
.markdown-body ul,
.markdown-body ol,
.markdown-body blockquote,
.markdown-body pre,
.markdown-body .table-wrap,
.markdown-body .math-block,
.markdown-body .mermaid-block {
  margin: 0 0 0.85em;
}
.markdown-body p:last-child,
.markdown-body ul:last-child,
.markdown-body ol:last-child,
.markdown-body blockquote:last-child,
.markdown-body pre:last-child,
.markdown-body .table-wrap:last-child,
.markdown-body .math-block:last-child,
.markdown-body .mermaid-block:last-child {
  margin-bottom: 0;
}
.markdown-body h1,
.markdown-body h2,
.markdown-body h3,
.markdown-body h4,
.markdown-body h5,
.markdown-body h6 {
  margin: 1em 0 0.45em;
  color: var(--markdown-title);
  line-height: 1.35;
  letter-spacing: 0;
}
.message.user:not(.rich) .markdown-body h1,
.message.user:not(.rich) .markdown-body h2,
.message.user:not(.rich) .markdown-body h3,
.message.user:not(.rich) .markdown-body h4,
.message.user:not(.rich) .markdown-body h5,
.message.user:not(.rich) .markdown-body h6 {
  color: var(--user-bubble-text);
}
.markdown-body h1:first-child,
.markdown-body h2:first-child,
.markdown-body h3:first-child,
.markdown-body h4:first-child,
.markdown-body h5:first-child,
.markdown-body h6:first-child {
  margin-top: 0;
}
.markdown-body h1 { font-size: 1.48em; }
.markdown-body h2 { font-size: 1.3em; }
.markdown-body h3 { font-size: 1.16em; }
.markdown-body h4,
.markdown-body h5,
.markdown-body h6 { font-size: 1.04em; }
.markdown-body hr {
  height: 1px;
  border: 0;
  margin: 1em 0;
  background: var(--table-border);
}
.message.user:not(.rich) .markdown-body hr {
  background: rgba(255, 255, 255, 0.5);
}
.markdown-body a {
  color: var(--markdown-link);
  text-decoration: none;
}
.message.user:not(.rich) .markdown-body a {
  color: var(--user-bubble-text);
  text-decoration: underline;
  text-underline-offset: 3px;
}
.markdown-body img {
  display: block;
  max-width: 100%;
  height: auto;
  border-radius: 8px;
}
.markdown-body code {
  padding: 0.12em 0.32em;
  border-radius: 5px;
  color: var(--code-text);
  background: var(--code-bg);
  font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
  font-size: 0.92em;
}
.message.user:not(.rich) .markdown-body code {
  color: var(--user-bubble-text);
  background: rgba(255, 255, 255, 0.16);
}
.code-block {
  overflow-x: auto;
  max-width: 100%;
  padding: 12px;
  border-radius: 8px;
  color: var(--code-text);
  background: var(--code-bg);
  scrollbar-width: thin;
}
.code-block code {
  padding: 0;
  border-radius: 0;
  background: transparent;
  font-size: 0.92em;
  line-height: 1.55;
  white-space: pre;
}
.message.user:not(.rich) .code-block {
  color: var(--user-bubble-text);
  background: rgba(255, 255, 255, 0.14);
}
.markdown-body blockquote {
  padding: 8px 10px;
  border-left: 3px solid var(--markdown-link);
  border-radius: 6px;
  background: var(--quote-bg);
}
.message.user:not(.rich) .markdown-body blockquote {
  border-left-color: rgba(255, 255, 255, 0.75);
  background: rgba(255, 255, 255, 0.14);
}
.markdown-body table {
  width: max-content;
  min-width: 100%;
  border-collapse: separate;
  border-spacing: 0;
  background: var(--table-bg);
  border: 1px solid var(--table-border);
  border-radius: 6px;
  overflow: hidden;
}
.markdown-body table,
.markdown-body .table-wrap {
  max-width: 100%;
}
.markdown-body table {
  display: block;
  overflow-x: auto;
  scrollbar-width: thin;
}
.markdown-body th,
.markdown-body td {
  padding: 8px;
  border-right: 1px solid var(--table-border);
  border-bottom: 1px solid var(--table-border);
  text-align: left;
  vertical-align: top;
}
.markdown-body th:last-child,
.markdown-body td:last-child {
  border-right: none;
}
.markdown-body tr:last-child td {
  border-bottom: none;
}
.markdown-body th {
  background: var(--table-header-bg);
  color: var(--markdown-title);
  font-weight: 650;
}
.markdown-body tbody tr:nth-child(even) td {
  background: var(--table-alt-bg);
}
.message.user:not(.rich) table {
  color: var(--user-bubble-text);
  background: rgba(255, 255, 255, 0.08);
  border-color: rgba(255, 255, 255, 0.32);
}
.message.user:not(.rich) th,
.message.user:not(.rich) td {
  border-color: rgba(255, 255, 255, 0.28);
}
.message.user:not(.rich) th,
.message.user:not(.rich) tbody tr:nth-child(even) td {
  background: rgba(255, 255, 255, 0.14);
  color: var(--user-bubble-text);
}
.markdown-body section,
.markdown-body .katex-display,
.markdown-body .texmath-display {
  overflow-x: auto;
  overflow-y: hidden;
  max-width: 100%;
  margin: 0 0 0.85em;
  padding: 9px 10px;
  border-radius: 8px;
  color: var(--markdown-text);
  background: var(--code-bg);
  scrollbar-width: thin;
}
.markdown-body .katex,
.markdown-body .texmath {
  max-width: 100%;
  overflow-x: auto;
  overflow-y: hidden;
}
.message.user:not(.rich) section,
.message.user:not(.rich) .katex-display,
.message.user:not(.rich) .texmath-display {
  color: var(--user-bubble-text);
  background: rgba(255, 255, 255, 0.14);
}
.mermaid-block {
  overflow-x: auto;
  max-width: 100%;
  padding: 10px;
  border-radius: 8px;
  background: var(--code-bg);
  scrollbar-width: thin;
}
.mermaid {
  min-width: max-content;
  color: var(--markdown-text);
  font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
  white-space: pre;
}
.message.user:not(.rich) .mermaid-block {
  background: rgba(255, 255, 255, 0.14);
}
.message.user:not(.rich) .mermaid {
  color: var(--user-bubble-text);
}
.mermaid svg {
  display: block;
  max-width: none;
}
.attachments {
  padding: 8px 10px;
  border: 1px solid var(--divider);
  border-radius: 8px;
  list-style: none;
}
.attachments li + li {
  margin-top: 6px;
}
.attachments span {
  margin-right: 8px;
  color: var(--text-secondary);
}
.message.user:not(.rich) .attachments {
  border-color: rgba(255, 255, 255, 0.28);
}
.message.user:not(.rich) .attachments span {
  color: rgba(255, 255, 255, 0.72);
}
.content-block + .content-block,
.content-block + .timeline-block,
.timeline-block + .content-block,
.timeline-block + .timeline-block {
  margin-top: 10px;
}
.media-placeholder {
  padding: 9px 10px;
  border: 1px solid var(--divider);
  border-radius: 8px;
  color: var(--text-secondary);
  background: var(--surface);
  font-size: 0.92em;
}
.message.user:not(.rich) .media-placeholder {
  border-color: rgba(255, 255, 255, 0.28);
  color: rgba(255, 255, 255, 0.82);
  background: rgba(255, 255, 255, 0.12);
}
.timeline-block {
  position: relative;
  padding: 7px 10px;
  border: 0.5px solid var(--divider);
  border-radius: 12px;
  background: var(--surface);
}
.timeline-block::before {
  content: "";
  position: absolute;
  left: 21px;
  top: 15px;
  bottom: 15px;
  width: 1px;
  background: var(--divider);
}
.timeline-step {
  position: relative;
  display: block;
  padding: 4px 0;
}
.timeline-step > summary {
  display: grid;
  grid-template-columns: 24px minmax(0, 1fr);
  gap: 10px;
  cursor: pointer;
  list-style: none;
}
.timeline-step > summary::-webkit-details-marker {
  display: none;
}
.timeline-step > summary::marker {
  content: "";
}
.timeline-step > summary:focus-visible {
  outline: 2px solid var(--primary-light);
  outline-offset: 2px;
  border-radius: 8px;
}
.timeline-icon {
  position: relative;
  z-index: 1;
  width: 20px;
  height: 20px;
  margin-top: 2px;
  border-radius: 10px;
  display: grid;
  place-items: center;
  color: var(--text-secondary);
  background: var(--surface);
  border: 1px solid var(--divider);
  font-size: 11px;
  line-height: 1;
}
.timeline-body {
  min-width: 0;
  margin-top: 6px;
  margin-left: 34px;
}
.timeline-title-row {
  display: flex;
  align-items: center;
  gap: 8px;
  min-width: 0;
}
.timeline-title {
  min-width: 0;
  flex: 1;
  color: var(--text-primary);
  font-size: 13px;
  font-weight: 650;
  line-height: 1.35;
  overflow-wrap: anywhere;
}
.timeline-source,
.timeline-summary {
  margin-top: 4px;
  color: var(--text-secondary);
  font-size: 12px;
  line-height: 1.45;
  overflow-wrap: anywhere;
}
.timeline-badge {
  flex: none;
  padding: 2px 6px;
  border-radius: 6px;
  color: var(--text-secondary);
  background: var(--code-bg);
  font-size: 10px;
  line-height: 1.4;
}
.timeline-caret {
  flex: none;
  color: var(--text-tertiary);
  font-size: 13px;
  line-height: 1;
  transition: transform 0.16s ease;
}
.timeline-step[open] .timeline-caret {
  transform: rotate(90deg);
}
.timeline-badge.success {
  color: #168040;
  background: rgba(22, 128, 64, 0.12);
}
.timeline-badge.error {
  color: #B42318;
  background: rgba(180, 35, 24, 0.12);
}
.timeline-badge.pending,
.timeline-badge.running {
  color: var(--markdown-link);
  background: var(--primary-light);
}
.timeline-content {
  margin-top: 6px;
  color: var(--text-secondary);
}
.tool-preview {
  margin-top: 7px;
}
.tool-preview summary {
  cursor: pointer;
  color: var(--text-secondary);
  font-size: 12px;
}
.tool-preview pre {
  max-height: 260px;
  overflow: auto;
  margin: 7px 0 0;
  padding: 9px;
  border-radius: 8px;
  color: var(--code-text);
  background: var(--code-bg);
  font-size: 12px;
  line-height: 1.45;
}
.tool-entry-list {
  display: grid;
  gap: 4px;
  margin-top: 6px;
}
.tool-entry {
  display: grid;
  grid-template-columns: minmax(58px, max-content) minmax(0, 1fr);
  gap: 8px;
  color: var(--text-secondary);
  font-size: 12px;
  line-height: 1.4;
}
.tool-entry-label {
  color: var(--text-tertiary);
}
.tool-references {
  display: grid;
  gap: 6px;
  margin-top: 8px;
}
.tool-reference {
  display: block;
  padding: 8px;
  border-radius: 8px;
  color: var(--text-primary);
  background: var(--code-bg);
  text-decoration: none;
}
.tool-reference-title {
  color: var(--text-primary);
  font-size: 12px;
  font-weight: 650;
  line-height: 1.35;
}
.tool-reference-snippet,
.tool-reference-url {
  margin-top: 3px;
  color: var(--text-secondary);
  font-size: 11px;
  line-height: 1.35;
  overflow-wrap: anywhere;
}
.reasoning {
  margin-top: 10px;
  padding-top: 8px;
  border-top: 1px solid var(--divider);
  color: var(--text-secondary);
}
.reasoning summary {
  cursor: pointer;
  color: var(--text-secondary);
  font-size: 0.92em;
}
.plain-fallback,
.noscript-fallback {
  white-space: pre-wrap;
  overflow-wrap: anywhere;
  margin: 0;
  color: var(--markdown-text);
  font-family: inherit;
}
.chat-footer {
  display: grid;
  justify-items: center;
  gap: 12px;
  margin: 8px 16px 0;
  padding: 18px 0 28px;
  border-top: 1px solid var(--divider);
  color: var(--text-secondary);
  text-align: center;
  font-size: 12px;
}
.footer-note {
  color: var(--text-tertiary);
}
.footer-promo {
  width: min(560px, 100%);
  display: grid;
  grid-template-columns: minmax(0, 1fr) auto;
  align-items: center;
  gap: 16px;
  padding: 14px 16px;
  border: 1px solid var(--bubble-border);
  border-radius: 16px;
  color: var(--text-primary);
  background: color-mix(in srgb, var(--surface) 92%, var(--primary-light));
  box-shadow: 0 10px 28px rgba(18, 24, 38, 0.06);
}
.footer-promo-copy {
  min-width: 0;
  text-align: left;
}
.footer-promo-kicker {
  color: var(--markdown-link);
  font-size: 12px;
  font-weight: 700;
  line-height: 1.25;
}
.footer-promo-title {
  margin-top: 3px;
  color: var(--text-primary);
  font-size: 15px;
  font-weight: 720;
  line-height: 1.35;
}
.footer-promo-desc {
  margin-top: 3px;
  color: var(--text-secondary);
  font-size: 12px;
  line-height: 1.45;
}
.footer-promo-link {
  display: inline-flex;
  align-items: center;
  max-width: 100%;
  margin-top: 8px;
  color: var(--markdown-link);
  font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
  font-size: 12px;
  font-weight: 650;
  overflow-wrap: anywhere;
  text-decoration: none;
}
.footer-promo-link:hover {
  text-decoration: underline;
  text-underline-offset: 3px;
}
.footer-qr-link {
  display: grid;
  justify-items: center;
  gap: 6px;
  color: var(--text-tertiary);
  font-size: 11px;
  line-height: 1.25;
  text-decoration: none;
}
.footer-qr {
  width: 78px;
  height: 78px;
  padding: 7px;
  border: 1px solid rgba(0, 0, 0, 0.08);
  border-radius: 14px;
  display: grid;
  place-items: center;
  color: #1F2937;
  background: #FFFFFF;
  box-shadow: inset 0 0 0 1px rgba(255, 255, 255, 0.75);
}
.footer-qr canvas,
.footer-qr img {
  display: block;
  width: 64px !important;
  height: 64px !important;
}
.footer-qr span {
  max-width: 58px;
  color: #1F2937;
  font-size: 10px;
  font-weight: 700;
  line-height: 1.2;
  overflow-wrap: anywhere;
}
.footer-qr-caption {
  color: var(--text-tertiary);
}
@media (min-width: 1100px) {
  .message-list {
    padding-left: 24px;
    padding-right: 24px;
  }
}
@media (max-width: 700px) {
  .share-shell {
    padding: 0;
  }
  .chat-frame {
    width: 100%;
    min-height: 100vh;
    border: 0;
    border-radius: 0;
    box-shadow: none;
  }
  .chat-header {
    grid-template-columns: minmax(0, 1fr) auto;
    gap: 8px 12px;
    padding: 12px 14px;
  }
  .header-brand {
    grid-column: 1;
  }
  .header-actions {
    grid-column: 2;
    grid-row: 1;
    flex-direction: column;
    align-items: flex-end;
    gap: 4px;
  }
  .theme-toggle {
    height: 28px;
    padding: 0 8px;
  }
  .header-conversation {
    grid-column: 1 / 3;
    grid-row: 2;
    padding-top: 2px;
  }
  .export-time {
    max-width: 128px;
    font-size: 11px;
  }
  .message-list {
    padding: 14px 12px 8px;
  }
  .message {
    gap: 8px;
    margin-bottom: 14px;
  }
  .assistant-avatar {
    width: 28px;
    height: 28px;
    margin-top: 22px;
    border-radius: 7px;
    font-size: 12px;
  }
  .message.user .message-main,
  .message.user.rich .message-main {
    max-width: 88%;
  }
  .message.assistant .bubble {
    padding: 10px 11px;
  }
  .message.user .bubble {
    padding: 10px 13px;
  }
  .markdown-body {
    font-size: ${defaultTheme.chatFontSize}px;
    line-height: ${Math.max(Math.round(defaultTheme.chatFontSize * 1.45), 19)}px;
  }
  .chat-footer {
    margin-left: 12px;
    margin-right: 12px;
    padding-bottom: 22px;
  }
  .footer-promo {
    grid-template-columns: minmax(0, 1fr);
    justify-items: start;
    gap: 12px;
    padding: 13px;
  }
  .footer-qr-link {
    grid-template-columns: auto minmax(0, 1fr);
    align-items: center;
    justify-items: start;
  }
  .footer-qr {
    width: 64px;
    height: 64px;
    padding: 6px;
    border-radius: 12px;
  }
  .footer-qr canvas,
  .footer-qr img {
    width: 52px !important;
    height: 52px !important;
  }
}
@media (max-width: 420px) {
  .message-list {
    padding-left: 10px;
    padding-right: 10px;
  }
  .message.user .message-main,
  .message.user.rich .message-main {
    max-width: 90%;
  }
  .assistant-avatar {
    width: 24px;
    height: 24px;
    margin-top: 23px;
    border-radius: 6px;
    font-size: 11px;
  }
  .theme-toggle {
    width: 30px;
    justify-content: center;
    padding: 0;
  }
  .theme-toggle-text {
    display: none;
  }
}`.trim()
  }

  private getHtmlExportTheme(): HtmlExportTheme {
    const state = getAppUiState()
    const theme = new HtmlExportTheme()
    theme.isDarkMode = state.isDarkMode
    theme.chatFontSize = state.chatFontSize
    theme.primary = this.toCssColor(state.themePrimary, theme.primary)
    theme.primaryLight = this.toCssColor(state.themePrimaryLight, theme.primaryLight)
    theme.background = this.toCssColor(state.themeBackground, theme.background)
    theme.surface = this.toCssColor(state.themeSurface, theme.surface)
    theme.divider = this.toCssColor(state.themeDivider, theme.divider)
    theme.bubbleBorder = theme.isDarkMode ? 'rgba(255, 255, 255, 0.1)' : 'rgba(0, 0, 0, 0.06)'
    theme.textPrimary = this.toCssColor(state.themeTextPrimary, theme.textPrimary)
    theme.textSecondary = this.toCssColor(state.themeTextSecondary, theme.textSecondary)
    theme.textTertiary = this.toCssColor(state.themeTextTertiary, theme.textTertiary)
    theme.userBubble = this.toCssColor(state.themeUserBubble, theme.userBubble)
    theme.userBubbleText = this.toCssColor(state.themeUserBubbleText, theme.userBubbleText)
    theme.aiBubble = this.toCssColor(state.themeAiBubble, theme.aiBubble)
    theme.markdownText = this.toCssColor(state.themeMarkdownText, theme.markdownText)
    theme.markdownTitle = this.toCssColor(state.themeMarkdownTitle, theme.markdownTitle)
    theme.markdownLink = this.toCssColor(state.themeMarkdownLink, theme.markdownLink)
    theme.markdownCodeBg = this.toCssColor(state.themeMarkdownCodeBg, theme.markdownCodeBg)
    theme.markdownCodeText = this.toCssColor(state.themeMarkdownCodeText, theme.markdownCodeText)
    theme.markdownQuoteBg = this.toCssColor(state.themeMarkdownQuoteBg, theme.markdownQuoteBg)
    theme.markdownTableBg = this.toCssColor(state.themeMarkdownTableBg, theme.markdownTableBg)
    theme.markdownTableHeaderBg = this.toCssColor(state.themeMarkdownTableHeaderBg, theme.markdownTableHeaderBg)
    theme.markdownTableAltBg = this.toCssColor(state.themeMarkdownTableAltBg, theme.markdownTableAltBg)
    theme.markdownTableBorder = this.toCssColor(state.themeMarkdownTableBorder, theme.markdownTableBorder)
    return theme
  }

  private getHtmlExportThemeForMode(isDarkMode: boolean): HtmlExportTheme {
    const state = getAppUiState()
    if (state.isDarkMode === isDarkMode) {
      return this.getHtmlExportTheme()
    }
    const themeId = (state.colorTheme !== '' ? state.colorTheme : ColorTheme.DEFAULT) as ColorTheme
    return this.buildHtmlExportThemeFromColors(getThemeColors(themeId, isDarkMode), isDarkMode, state.chatFontSize)
  }

  private buildHtmlExportThemeFromColors(colors: ThemeColorConfig, isDarkMode: boolean,
    chatFontSize: number): HtmlExportTheme {
    const theme = new HtmlExportTheme()
    theme.isDarkMode = isDarkMode
    theme.chatFontSize = chatFontSize
    theme.primary = this.toCssColor(colors.primary, theme.primary)
    theme.primaryLight = this.toCssColor(colors.primaryLight, theme.primaryLight)
    theme.background = this.toCssColor(colors.background, theme.background)
    theme.surface = this.toCssColor(colors.surface, theme.surface)
    theme.divider = this.toCssColor(colors.divider, theme.divider)
    theme.bubbleBorder = isDarkMode ? 'rgba(255, 255, 255, 0.1)' : 'rgba(0, 0, 0, 0.06)'
    theme.textPrimary = this.toCssColor(colors.textPrimary, theme.textPrimary)
    theme.textSecondary = this.toCssColor(colors.textSecondary, theme.textSecondary)
    theme.textTertiary = this.toCssColor(colors.textTertiary, theme.textTertiary)
    theme.userBubble = this.toCssColor(colors.userBubble, theme.userBubble)
    theme.userBubbleText = this.toCssColor(colors.userBubbleText, theme.userBubbleText)
    theme.aiBubble = this.toCssColor(colors.aiBubble, theme.aiBubble)
    theme.markdownText = this.toCssColor(colors.markdownText, theme.markdownText)
    theme.markdownTitle = this.toCssColor(colors.markdownTitle, theme.markdownTitle)
    theme.markdownLink = this.toCssColor(colors.markdownLink, theme.markdownLink)
    theme.markdownCodeBg = this.toCssColor(colors.markdownCodeBg, theme.markdownCodeBg)
    theme.markdownCodeText = this.toCssColor(colors.markdownCodeText, theme.markdownCodeText)
    theme.markdownQuoteBg = this.toCssColor(colors.markdownQuoteBg, theme.markdownQuoteBg)
    theme.markdownTableBg = this.toCssColor(colors.markdownTableBg, theme.markdownTableBg)
    theme.markdownTableHeaderBg = this.toCssColor(colors.markdownTableHeaderBg, theme.markdownTableHeaderBg)
    theme.markdownTableAltBg = this.toCssColor(colors.markdownTableAltBg, theme.markdownTableAltBg)
    theme.markdownTableBorder = this.toCssColor(colors.markdownTableBorder, theme.markdownTableBorder)
    return theme
  }

  private resolveAvatarText(value: string): string {
    const text = getAssistantAvatarFallbackText(value).trim()
    if (text === '') {
      return 'AI'
    }
    return text.length > 2 ? text.substring(0, 2) : text
  }

  private buildHtmlMessages(messages: ConversationExportMessage[], currentModelId: string,
    context: common.UIAbilityContext | null): ConversationExportMessage[] {
    const result: ConversationExportMessage[] = []
    for (let i = 0; i < messages.length; i++) {
      const source = messages[i]
      const item = new ConversationExportMessage()
      item.id = source.id
      item.role = source.role
      item.roleLabel = source.roleLabel
      item.content = source.content
      item.reasoningContent = source.reasoningContent
      item.timestamp = source.timestamp
      item.modelName = source.modelName
      item.modelId = source.modelId
      item.attachments = source.attachments
      item.blocks = source.blocks
      if (source.role !== MessageRole.USER) {
        item.avatarImageSource = this.resolveMessageAvatarImageSource(source, currentModelId, context)
      }
      result.push(item)
    }
    return result
  }

  private resolveMessageAvatarImageSource(message: ConversationExportMessage, currentModelId: string,
    context: common.UIAbilityContext | null): string {
    const modelId = message.modelId !== '' ? message.modelId : currentModelId
    const modelIcon = buildModelIconRenderData(modelId, '', message.modelName)
    if (modelIcon.hasIcon()) {
      if (modelIcon.isRawfile()) {
        return this.resolveRawfileImageSource(context, modelIcon.resourcePath)
      }
      return this.resolveWebImageSource(modelIcon.resourcePath)
    }
    return ''
  }

  private buildAppIconHtml(source: string): string {
    if (source !== '') {
      return `<img class="app-icon app-icon-image" src="${this.escapeHtml(source)}" alt="">`
    }
    return '<div class="app-icon app-icon-fallback">C</div>'
  }

  private resolveAppIconSource(context: common.UIAbilityContext | null): string {
    if (context === null) {
      return ''
    }
    try {
      const bytes = context.resourceManager.getMediaContentSync($r('app.media.startIcon').id)
      return this.buildDataUrl(bytes, 'image/png')
    } catch (error) {
      console.warn('ConversationExportService', `Failed to resolve app icon: ${JSON.stringify(error)}`)
      return ''
    }
  }

  private resolveRawfileImageSource(context: common.UIAbilityContext | null, rawfilePath: string): string {
    if (context === null || rawfilePath === '') {
      return ''
    }
    try {
      const bytes = context.resourceManager.getRawFileContentSync(rawfilePath)
      return this.buildDataUrl(bytes, this.getImageMimeType(rawfilePath, 'image/svg+xml'))
    } catch (error) {
      console.warn('ConversationExportService', `Failed to resolve rawfile icon: ${JSON.stringify(error)}`)
      return ''
    }
  }

  private resolveWebImageSource(source: string): string {
    const value = source.trim()
    if (value === '') {
      return ''
    }
    const lower = value.toLowerCase()
    if (lower.startsWith('data:image/') || lower.startsWith('http://') || lower.startsWith('https://')) {
      return value
    }
    if (lower.startsWith('file://')) {
      return this.resolveLocalImageSource(this.getPathFromFileUri(value))
    }
    if (lower.startsWith('/')) {
      return this.resolveLocalImageSource(value)
    }
    return ''
  }

  private resolveLocalImageSource(path: string): string {
    let file: fs.File | null = null
    try {
      file = fs.openSync(path, fs.OpenMode.READ_ONLY)
      const stat = fs.statSync(file.fd)
      if (stat.size <= 0 || stat.size > HTML_INLINE_IMAGE_MAX_BYTES) {
        return ''
      }
      const buffer = new ArrayBuffer(stat.size)
      fs.readSync(file.fd, buffer)
      return this.buildDataUrl(new Uint8Array(buffer), this.getImageMimeType(path, 'image/jpeg'))
    } catch (error) {
      console.warn('ConversationExportService', `Failed to resolve local image: ${JSON.stringify(error)}`)
      return ''
    } finally {
      if (file !== null) {
        try {
          fs.closeSync(file)
        } catch (error) {
          console.warn('ConversationExportService', `Failed to close local image: ${JSON.stringify(error)}`)
        }
      }
    }
  }

  private getPathFromFileUri(value: string): string {
    let trimmed = value.trim()
    const fragmentIndex = trimmed.indexOf('#')
    if (fragmentIndex >= 0) {
      trimmed = trimmed.substring(0, fragmentIndex)
    }
    const queryIndex = trimmed.indexOf('?')
    if (queryIndex >= 0) {
      trimmed = trimmed.substring(0, queryIndex)
    }
    if (!trimmed.toLowerCase().startsWith('file://')) {
      return trimmed
    }
    try {
      return new fileUri.FileUri(trimmed).path
    } catch (_error) {
      return trimmed.substring(7)
    }
  }

  private buildDataUrl(bytes: Uint8Array, mimeType: string): string {
    if (bytes.length <= 0 || bytes.length > HTML_INLINE_IMAGE_MAX_BYTES) {
      return ''
    }
    const base64Helper = new util.Base64Helper()
    return `data:${mimeType};base64,${base64Helper.encodeToStringSync(bytes)}`
  }

  private getImageMimeType(path: string, fallback: string): string {
    const clean = path.split('?')[0].split('#')[0].toLowerCase()
    if (clean.endsWith('.svg')) {
      return 'image/svg+xml'
    }
    if (clean.endsWith('.png')) {
      return 'image/png'
    }
    if (clean.endsWith('.webp')) {
      return 'image/webp'
    }
    if (clean.endsWith('.gif')) {
      return 'image/gif'
    }
    if (clean.endsWith('.bmp')) {
      return 'image/bmp'
    }
    if (clean.endsWith('.jpg') || clean.endsWith('.jpeg')) {
      return 'image/jpeg'
    }
    return fallback
  }

  private getHighlightStyleUrl(isDarkMode: boolean): string {
    return isDarkMode ?
      'https://cdn.jsdelivr.net/gh/highlightjs/cdn-release@11.9.0/build/styles/github-dark.min.css' :
      'https://cdn.jsdelivr.net/gh/highlightjs/cdn-release@11.9.0/build/styles/github.min.css'
  }

  private buildVendorScripts(): string {
    return [
      '<script src="https://cdn.jsdelivr.net/npm/markdown-it@14.1.0/dist/markdown-it.min.js"></script>',
      '<script src="https://cdn.jsdelivr.net/npm/katex@0.16.11/dist/katex.min.js"></script>',
      '<script src="https://cdn.jsdelivr.net/npm/markdown-it-texmath@1.0.0/texmath.min.js"></script>',
      '<script src="https://cdn.jsdelivr.net/npm/dompurify@3.1.6/dist/purify.min.js"></script>',
      '<script src="https://cdn.jsdelivr.net/gh/highlightjs/cdn-release@11.9.0/build/highlight.min.js"></script>',
      '<script src="https://cdn.jsdelivr.net/npm/mermaid@10.9.1/dist/mermaid.min.js"></script>',
      '<script src="https://cdn.jsdelivr.net/npm/qrcodejs@1.0.0/qrcode.min.js"></script>'
    ].join('\n')
  }

  private buildRenderScript(theme: HtmlExportTheme): string {
    const initialThemeMode = theme.isDarkMode ? 'dark' : 'light'
    return [
      '<script>',
      '(function () {',
      '  var dataNode = document.getElementById("chatcube-export-data");',
      '  var listNode = document.getElementById("message-list");',
      '  var data = dataNode ? JSON.parse(dataNode.textContent || "{}") : {};',
      '  var currentThemeMode = data.themeMode === "dark" ? "dark" : "' + initialThemeMode + '";',
      '',
      '  function escapeHtml(value) {',
      '    return String(value || "")',
      '      .replace(/&/g, "&amp;")',
      '      .replace(/</g, "&lt;")',
      '      .replace(/>/g, "&gt;")',
      '      .replace(/"/g, "&quot;")',
      "      .replace(/'/g, '&#39;');",
      '  }',
      '',
      '  function escapeAttr(value) {',
      '    return String(value || "").replace(/[^a-zA-Z0-9_-]/g, "");',
      '  }',
      '',
      '  function isRichUserContent(text) {',
      '    var value = String(text || "");',
      '    return value.length > 260 || /(^|\\n)\\s*(```|#{1,6}\\s|[-*+]\\s|\\d+\\.\\s|\\|.*\\||>|\\$\\$|\\\\\\[)/.test(value);',
      '  }',
      '',
      '  function setHighlightMode(mode) {',
      '    var lightLink = document.getElementById("highlight-style-light");',
      '    var darkLink = document.getElementById("highlight-style-dark");',
      '    if (lightLink) {',
      '      lightLink.disabled = mode === "dark";',
      '    }',
      '    if (darkLink) {',
      '      darkLink.disabled = mode !== "dark";',
      '    }',
      '  }',
      '',
      '  function setBrowserColorScheme(mode) {',
      '    var meta = document.querySelector(\'meta[name="color-scheme"]\');',
      '    if (meta) {',
      '      meta.setAttribute("content", mode === "dark" ? "dark" : "only light");',
      '    }',
      '  }',
      '',
      '  function updateThemeToggle() {',
      '    var button = document.getElementById("theme-toggle");',
      '    if (!button) {',
      '      return;',
      '    }',
      '    var isDark = currentThemeMode === "dark";',
      '    button.setAttribute("aria-pressed", isDark ? "true" : "false");',
      '    button.setAttribute("title", isDark ? "切换浅色主题" : "切换深色主题");',
      '    var icon = button.querySelector(".theme-toggle-icon");',
      '    var text = button.querySelector(".theme-toggle-text");',
      '    if (icon) {',
      '      icon.textContent = isDark ? "☀" : "☾";',
      '    }',
      '    if (text) {',
      '      text.textContent = isDark ? "浅色" : "深色";',
      '    }',
      '  }',
      '',
      '  function applyThemeMode(mode) {',
      '    currentThemeMode = mode === "dark" ? "dark" : "light";',
      '    var root = document.documentElement;',
      '    if (root && root.classList) {',
      '      root.classList.toggle("theme-dark", currentThemeMode === "dark");',
      '      root.classList.toggle("theme-light", currentThemeMode !== "dark");',
      '    }',
      '    if (document.body && document.body.classList) {',
      '      document.body.classList.toggle("theme-dark", currentThemeMode === "dark");',
      '      document.body.classList.toggle("theme-light", currentThemeMode !== "dark");',
      '    }',
      '    setHighlightMode(currentThemeMode);',
      '    setBrowserColorScheme(currentThemeMode);',
      '    updateThemeToggle();',
      '  }',
      '',
      '  function bindThemeToggle() {',
      '    var button = document.getElementById("theme-toggle");',
      '    if (!button) {',
      '      return;',
      '    }',
      '    button.addEventListener("click", function () {',
      '      applyThemeMode(currentThemeMode === "dark" ? "light" : "dark");',
      '      renderMessages();',
      '      enhanceMermaid();',
      '    });',
      '  }',
      '',
      '  function formatTime(timestamp) {',
      '    var date = new Date(Number(timestamp) || Date.now());',
      '    var hours = date.getHours();',
      '    var minutes = String(date.getMinutes()).padStart(2, "0");',
      '    var period = hours >= 12 ? "PM" : "AM";',
      '    var displayHours = hours % 12 || 12;',
      '    return displayHours + ":" + minutes + " " + period;',
      '  }',
      '',
      '  function createMarkdownRenderer() {',
      '    if (!window.markdownit) {',
      '      return null;',
      '    }',
      '    var md = window.markdownit({',
      '      html: false,',
      '      linkify: false,',
      '      typographer: false,',
      '      breaks: false,',
      '      highlight: function (source, lang) {',
      '        var language = escapeAttr(lang || "");',
      '        if (window.hljs && language !== "" && window.hljs.getLanguage(language)) {',
      '          try {',
      '            var highlighted = window.hljs.highlight(source, { language: language, ignoreIllegals: true }).value;',
      '            return \'<pre class="code-block"><code class="hljs language-\' + language + \'">\' + highlighted + "</code></pre>";',
      '          } catch (error) {',
      '            console.warn("highlight.js failed", error);',
      '          }',
      '        }',
      '        return \'<pre class="code-block"><code class="hljs">\' + escapeHtml(source) + "</code></pre>";',
      '      }',
      '    });',
      '    if (window.texmath && window.katex) {',
      '      md.use(window.texmath, {',
      '        engine: window.katex,',
      '        delimiters: ["dollars", "brackets"],',
      '        katexOptions: { throwOnError: false, output: "htmlAndMathml" }',
      '      });',
      '    }',
      '',
      '    var defaultFence = md.renderer.rules.fence;',
      '    md.renderer.rules.fence = function (tokens, idx, options, env, self) {',
      '      var token = tokens[idx];',
      '      var info = (token.info || "").trim();',
      '      var langName = info.split(/\\s+/)[0].toLowerCase();',
      '      if (langName === "mermaid") {',
      '        return \'<div class="mermaid-block"><pre class="mermaid">\' + escapeHtml(token.content) + "</pre></div>";',
      '      }',
      '      return defaultFence(tokens, idx, options, env, self);',
      '    };',
      '',
      '    var defaultLinkOpen = md.renderer.rules.link_open || function (tokens, idx, options, env, self) {',
      '      return self.renderToken(tokens, idx, options);',
      '    };',
      '    md.renderer.rules.link_open = function (tokens, idx, options, env, self) {',
      '      var token = tokens[idx];',
      '      token.attrSet("target", "_blank");',
      '      token.attrSet("rel", "noopener noreferrer");',
      '      return defaultLinkOpen(tokens, idx, options, env, self);',
      '    };',
      '    return md;',
      '  }',
      '',
      '  var markdown = createMarkdownRenderer();',
      '',
      '  function sanitizeHtml(html) {',
      '    if (!window.DOMPurify) {',
      '      return html;',
      '    }',
      '    return window.DOMPurify.sanitize(html, {',
      '      ADD_ATTR: ["target", "rel", "class"]',
      '    });',
      '  }',
      '',
      '  function shouldSkipAutoLink(node) {',
      '    var current = node.parentElement || node.parentNode;',
      '    while (current && current.nodeType === 1) {',
      '      var tag = current.tagName ? current.tagName.toLowerCase() : "";',
      '      if (tag === "a" || tag === "code" || tag === "pre" || tag === "script" ||',
      '        tag === "style" || tag === "textarea" || tag === "math") {',
      '        return true;',
      '      }',
      '      if (current.classList && (current.classList.contains("katex") ||',
      '        current.classList.contains("texmath") || current.classList.contains("mermaid") ||',
      '        current.classList.contains("hljs") || current.classList.contains("code-block"))) {',
      '        return true;',
      '      }',
      '      current = current.parentElement || current.parentNode;',
      '    }',
      '    return false;',
      '  }',
      '',
      '  function trimAutoLinkUrl(value) {',
      '    var url = String(value || "");',
      '    var trailing = "";',
      '    while (url.length > 0 && /[.,!?;:，。！？；：、）)\\]}》」』]/.test(url.charAt(url.length - 1))) {',
      '      trailing = url.charAt(url.length - 1) + trailing;',
      '      url = url.slice(0, -1);',
      '    }',
      '    return { url: url, trailing: trailing };',
      '  }',
      '',
      '  function linkifyTextNode(node) {',
      '    var text = node.nodeValue || "";',
      '    var pattern = /https?:\\/\\/[A-Za-z0-9\\-._~:/?#\\[\\]@!$&()+,;=%]+/g;',
      '    var match = null;',
      '    var lastIndex = 0;',
      '    var changed = false;',
      '    var fragment = document.createDocumentFragment();',
      '    while ((match = pattern.exec(text)) !== null) {',
      '      var result = trimAutoLinkUrl(match[0]);',
      '      if (result.url === "") {',
      '        continue;',
      '      }',
      '      if (match.index > lastIndex) {',
      '        fragment.appendChild(document.createTextNode(text.slice(lastIndex, match.index)));',
      '      }',
      '      var link = document.createElement("a");',
      '      link.href = result.url;',
      '      link.target = "_blank";',
      '      link.rel = "noopener noreferrer";',
      '      link.textContent = result.url;',
      '      fragment.appendChild(link);',
      '      if (result.trailing !== "") {',
      '        fragment.appendChild(document.createTextNode(result.trailing));',
      '      }',
      '      lastIndex = match.index + match[0].length;',
      '      changed = true;',
      '    }',
      '    if (!changed || !node.parentNode) {',
      '      return;',
      '    }',
      '    if (lastIndex < text.length) {',
      '      fragment.appendChild(document.createTextNode(text.slice(lastIndex)));',
      '    }',
      '    node.parentNode.replaceChild(fragment, node);',
      '  }',
      '',
      '  function linkifyPlainUrls(html) {',
      '    if (!document.createElement || !document.createTreeWalker) {',
      '      return html;',
      '    }',
      '    var root = document.createElement("div");',
      '    root.innerHTML = html;',
      '    var walker = document.createTreeWalker(root, 4, {',
      '      acceptNode: function (node) {',
      '        if (!node.nodeValue || node.nodeValue.indexOf("http") < 0 || shouldSkipAutoLink(node)) {',
      '          return 2;',
      '        }',
      '        return 1;',
      '      }',
      '    });',
      '    var nodes = [];',
      '    while (walker.nextNode()) {',
      '      nodes.push(walker.currentNode);',
      '    }',
      '    nodes.forEach(linkifyTextNode);',
      '    return root.innerHTML;',
      '  }',
      '',
      '  function renderMarkdown(text) {',
      '    var value = String(text || "");',
      '    if (value.trim() === "") {',
      '      return \'<p class="empty-message">(空消息)</p>\';',
      '    }',
      '    if (!markdown) {',
      '      return \'<pre class="plain-fallback">\' + escapeHtml(value) + "</pre>";',
      '    }',
      '    return linkifyPlainUrls(sanitizeHtml(markdown.render(value)));',
      '  }',
      '',
      '  function renderAttachments(attachments) {',
      '    if (!attachments || attachments.length === 0) {',
      '      return "";',
      '    }',
      '    var items = attachments.map(function (item) {',
      '      var typeLabel = item.type === "' + AttachmentType.IMAGE + '" ? "图片" : "文件";',
      '      var meta = [];',
      '      if (item.mimeType) {',
      '        meta.push(item.mimeType);',
      '      }',
      '      if (item.size > 0) {',
      '        meta.push(formatFileSize(item.size));',
      '      }',
      '      return "<li><span>" + escapeHtml(typeLabel) + "</span>" + escapeHtml(item.name || "") +',
      '        (meta.length > 0 ? " (" + escapeHtml(meta.join(", ")) + ")" : "") + "</li>";',
      '    });',
      '    return \'<ul class="attachments">\' + items.join("") + "</ul>";',
      '  }',
      '',
      '  function appendHtml(target, html) {',
      '    if (html && String(html).trim() !== "") {',
      '      target.insertAdjacentHTML("beforeend", html);',
      '    }',
      '  }',
      '',
      '  function createContentBlock(block) {',
      '    var wrapper = document.createElement("div");',
      '    wrapper.className = "content-block";',
      '    var parts = Array.isArray(block.contentParts) ? block.contentParts : [];',
      '    parts.forEach(function (part) {',
      '      if (part.type === "media") {',
      '        var media = document.createElement("div");',
      '        media.className = "media-placeholder";',
      '        var name = part.mediaName || part.mediaUrl || "";',
      '        media.textContent = "[" + (part.mediaLabel || "媒体") + "]" + (name ? " " + name : "");',
      '        wrapper.appendChild(media);',
      '        return;',
      '      }',
      '      appendHtml(wrapper, renderMarkdown(part.text || ""));',
      '    });',
      '    return wrapper;',
      '  }',
      '',
      '  function createEntryList(entries) {',
      '    if (!Array.isArray(entries) || entries.length === 0) {',
      '      return null;',
      '    }',
      '    var list = document.createElement("div");',
      '    list.className = "tool-entry-list";',
      '    entries.forEach(function (entry) {',
      '      var row = document.createElement("div");',
      '      row.className = "tool-entry";',
      '      row.innerHTML = \'<span class="tool-entry-label">\' + escapeHtml(entry.label || "") +',
      '        "</span><span>" + escapeHtml(entry.value || "") + "</span>";',
      '      list.appendChild(row);',
      '    });',
      '    return list;',
      '  }',
      '',
      '  function createToolPreview(title, preview, truncated) {',
      '    var value = String(preview || "");',
      '    if (value.trim() === "") {',
      '      return null;',
      '    }',
      '    var details = document.createElement("details");',
      '    details.className = "tool-preview";',
      '    var summary = document.createElement("summary");',
      '    summary.textContent = title + (truncated ? "（已截断）" : "");',
      '    var pre = document.createElement("pre");',
      '    pre.textContent = value;',
      '    details.appendChild(summary);',
      '    details.appendChild(pre);',
      '    return details;',
      '  }',
      '',
      '  function createReferences(refs) {',
      '    if (!Array.isArray(refs) || refs.length === 0) {',
      '      return null;',
      '    }',
      '    var list = document.createElement("div");',
      '    list.className = "tool-references";',
      '    refs.forEach(function (ref, index) {',
      '      var link = document.createElement(ref.url ? "a" : "div");',
      '      link.className = "tool-reference";',
      '      if (ref.url) {',
      '        link.href = ref.url;',
      '        link.target = "_blank";',
      '        link.rel = "noopener noreferrer";',
      '      }',
      '      link.innerHTML = \'<div class="tool-reference-title">\' + escapeHtml((index + 1) + ". " + (ref.title || ref.url || "来源")) + "</div>" +',
      '        (ref.snippet ? \'<div class="tool-reference-snippet">\' + escapeHtml(ref.snippet) + "</div>" : "") +',
      '        (ref.url ? \'<div class="tool-reference-url">\' + escapeHtml(ref.url) + "</div>" : "");',
      '      list.appendChild(link);',
      '    });',
      '    return list;',
      '  }',
      '',
      '  function createTimelineStep(item) {',
      '    var step = document.createElement("details");',
      '    step.className = "timeline-step " + (item.type || "");',
      '    var summary = document.createElement("summary");',
      '    var icon = document.createElement("div");',
      '    icon.className = "timeline-icon";',
      '    icon.textContent = item.type === "tool" ? "T" : "R";',
      '    var body = document.createElement("div");',
      '    body.className = "timeline-body";',
      '    var titleRow = document.createElement("div");',
      '    titleRow.className = "timeline-title-row";',
      '    var title = document.createElement("div");',
      '    title.className = "timeline-title";',
      '    title.textContent = item.title || (item.type === "tool" ? "工具调用" : "思考过程");',
      '    titleRow.appendChild(title);',
      '    if (item.type === "tool" && item.statusLabel) {',
      '      var badge = document.createElement("span");',
      '      badge.className = "timeline-badge " + (item.statusTone || "");',
      '      badge.textContent = item.statusLabel;',
      '      titleRow.appendChild(badge);',
      '    }',
      '    var caret = document.createElement("span");',
      '    caret.className = "timeline-caret";',
      '    caret.textContent = ">";',
      '    titleRow.appendChild(caret);',
      '    summary.appendChild(icon);',
      '    summary.appendChild(titleRow);',
      '    if (item.sourceLabel) {',
      '      var source = document.createElement("div");',
      '      source.className = "timeline-source";',
      '      source.textContent = item.sourceLabel;',
      '      body.appendChild(source);',
      '    }',
      '    if (item.type === "reasoning") {',
      '      var content = document.createElement("div");',
      '      content.className = "timeline-content";',
      '      appendHtml(content, renderMarkdown(item.text || ""));',
      '      body.appendChild(content);',
      '    } else {',
      '      if (item.argumentsSummary) {',
      '        var argSummary = document.createElement("div");',
      '        argSummary.className = "timeline-summary";',
      '        argSummary.textContent = "参数：" + item.argumentsSummary;',
      '        body.appendChild(argSummary);',
      '      }',
      '      if (item.resultSummary) {',
      '        var resultSummary = document.createElement("div");',
      '        resultSummary.className = "timeline-summary";',
      '        resultSummary.textContent = "结果：" + item.resultSummary;',
      '        body.appendChild(resultSummary);',
      '      }',
      '      var argEntries = createEntryList(item.argumentEntries);',
      '      if (argEntries) {',
      '        body.appendChild(argEntries);',
      '      }',
      '      var resultEntries = createEntryList(item.resultEntries);',
      '      if (resultEntries) {',
      '        body.appendChild(resultEntries);',
      '      }',
      '      var refs = createReferences(item.references);',
      '      if (refs) {',
      '        body.appendChild(refs);',
      '      }',
      '      var argPreview = createToolPreview("参数详情", item.argumentPreview, item.argumentTruncated);',
      '      if (argPreview) {',
      '        body.appendChild(argPreview);',
      '      }',
      '      var resultPreview = createToolPreview("结果详情", item.resultPreview, item.resultTruncated);',
      '      if (resultPreview) {',
      '        body.appendChild(resultPreview);',
      '      }',
      '    }',
      '    step.appendChild(summary);',
      '    step.appendChild(body);',
      '    return step;',
      '  }',
      '',
      '  function createTimelineBlock(block) {',
      '    var wrapper = document.createElement("div");',
      '    wrapper.className = "timeline-block";',
      '    var items = Array.isArray(block.timelineItems) ? block.timelineItems : [];',
      '    items.forEach(function (item) {',
      '      wrapper.appendChild(createTimelineStep(item));',
      '    });',
      '    return wrapper;',
      '  }',
      '',
      '  function renderMessageBlocks(bubble, message) {',
      '    var blocks = Array.isArray(message.blocks) ? message.blocks : [];',
      '    if (blocks.length === 0) {',
      '      return false;',
      '    }',
      '    blocks.forEach(function (block) {',
      '      if (block.kind === "thinking") {',
      '        bubble.appendChild(createTimelineBlock(block));',
      '      } else {',
      '        bubble.appendChild(createContentBlock(block));',
      '      }',
      '    });',
      '    appendHtml(bubble, renderAttachments(message.attachments));',
      '    return true;',
      '  }',
      '',
      '  function renderFallbackMessageContent(bubble, message) {',
      '    if (message.reasoningContent && String(message.reasoningContent).trim() !== "") {',
      '      var details = document.createElement("details");',
      '      details.className = "reasoning";',
      '      details.innerHTML = "<summary>思考过程</summary>" + renderMarkdown(message.reasoningContent);',
      '      bubble.appendChild(details);',
      '    }',
      '    appendHtml(bubble, renderMarkdown(message.content));',
      '    appendHtml(bubble, renderAttachments(message.attachments));',
      '  }',
      '',
      '  function formatFileSize(size) {',
      '    var value = Number(size) || 0;',
      '    if (value < 1024) {',
      '      return value + " B";',
      '    }',
      '    if (value < 1024 * 1024) {',
      '      return (value / 1024).toFixed(1) + " KB";',
      '    }',
      '    return (value / 1024 / 1024).toFixed(1) + " MB";',
      '  }',
      '',
      '  function createMeta(message, isUser) {',
      '    var meta = document.createElement("div");',
      '    meta.className = "message-meta";',
      '    var label = message.role === "assistant" && message.modelName ? message.modelName : message.roleLabel;',
      '    meta.innerHTML = "<span>" + escapeHtml(label) + "</span>";',
      '    return meta;',
      '  }',
      '',
      '  function renderAvatar(avatar, imageSource, fallbackText, fallbackColor) {',
      '    var source = String(imageSource || "");',
      '    if (source !== "") {',
      '      avatar.className = "assistant-avatar has-image";',
      '      var img = document.createElement("img");',
      '      img.alt = "";',
      '      img.src = source;',
      '      avatar.appendChild(img);',
      '      return;',
      '    }',
      '    avatar.style.backgroundColor = fallbackColor || "var(--primary)";',
      '    avatar.textContent = fallbackText || "AI";',
      '  }',
      '',
      '  function createMessage(message) {',
      '    var isUser = message.role === "user";',
      '    var roleClass = isUser ? "user" : (message.role || "assistant");',
      '    var article = document.createElement("article");',
      '    article.className = "message " + roleClass + (isUser && isRichUserContent(message.content) ? " rich" : "");',
      '',
      '    if (!isUser) {',
      '      var avatar = document.createElement("div");',
      '      avatar.className = "assistant-avatar";',
      '      renderAvatar(avatar, message.avatarImageSource || data.assistantAvatarImageSource,',
      '        data.assistantAvatarValue, data.assistantAvatarColor);',
      '      article.appendChild(avatar);',
      '    }',
      '',
      '    var main = document.createElement("div");',
      '    main.className = "message-main";',
      '    main.appendChild(createMeta(message, isUser));',
      '',
      '    var bubble = document.createElement("div");',
      '    bubble.className = "bubble markdown-body";',
      '    if (!renderMessageBlocks(bubble, message)) {',
      '      renderFallbackMessageContent(bubble, message);',
      '    }',
      '',
      '    main.appendChild(bubble);',
      '    article.appendChild(main);',
      '    return article;',
      '  }',
      '',
      '  function renderMessages() {',
      '    if (!listNode) {',
      '      return;',
      '    }',
      '    listNode.innerHTML = "";',
      '    var messages = Array.isArray(data.messages) ? data.messages : [];',
      '    messages.forEach(function (message) {',
      '      listNode.appendChild(createMessage(message));',
      '    });',
      '  }',
      '',
      '  function enhanceMermaid() {',
      '    if (!window.mermaid) {',
      '      return Promise.resolve();',
      '    }',
      '    try {',
      '      window.mermaid.initialize({ startOnLoad: false, theme: currentThemeMode === "dark" ? "dark" : "default", securityLevel: "strict" });',
      '      return window.mermaid.run({ querySelector: ".mermaid" });',
      '    } catch (error) {',
      '      console.warn("Mermaid render failed", error);',
      '      return Promise.resolve();',
      '    }',
      '  }',
      '',
      '  function enhancePromoQr() {',
      '    var node = document.getElementById("promo-qr");',
      '    if (!node || !window.QRCode) {',
      '      return;',
      '    }',
      '    var url = String(data.promoUrl || "' + EXPORT_PROMO_URL + '");',
      '    try {',
      '      node.innerHTML = "";',
      '      var options = {',
      '        text: url,',
      '        width: 64,',
      '        height: 64,',
      '        colorDark: "#1F2937",',
      '        colorLight: "#FFFFFF"',
      '      };',
      '      if (window.QRCode.CorrectLevel) {',
      '        options.correctLevel = window.QRCode.CorrectLevel.M;',
      '      }',
      '      new window.QRCode(node, options);',
      '      node.classList.add("is-rendered");',
      '    } catch (error) {',
      '      console.warn("QR code render failed", error);',
      '      node.innerHTML = "<span>969991.xyz</span>";',
      '    }',
      '  }',
      '',
      '  applyThemeMode(currentThemeMode);',
      '  bindThemeToggle();',
      '  renderMessages();',
      '  enhancePromoQr();',
      '  enhanceMermaid();',
      '}());',
      '</script>'
    ].join('\n')
  }

  private toCssColor(value: string, fallback: string): string {
    const color = value.trim()
    if (!this.isHexColor(color)) {
      return fallback
    }
    if (color.length === 7) {
      return color
    }
    if (color.length === 9) {
      return `#${color.substring(3)}${color.substring(1, 3)}`
    }
    return fallback
  }

  private isHexColor(color: string): boolean {
    if (!color.startsWith('#') || (color.length !== 7 && color.length !== 9)) {
      return false
    }
    for (let i = 1; i < color.length; i++) {
      const ch = color.charAt(i)
      if (!((ch >= '0' && ch <= '9') || (ch >= 'a' && ch <= 'f') || (ch >= 'A' && ch <= 'F'))) {
        return false
      }
    }
    return true
  }

  private escapeJsonForScript(text: string): string {
    return text
      .replace(/</g, '\\u003C')
      .replace(/>/g, '\\u003E')
      .replace(/&/g, '\\u0026')
      .replace(/\u2028/g, '\\u2028')
      .replace(/\u2029/g, '\\u2029')
  }

  private formatAttachmentMeta(attachment: ConversationExportAttachment): string {
    const parts: string[] = []
    if (attachment.mimeType !== '') {
      parts.push(attachment.mimeType)
    }
    if (attachment.size > 0) {
      parts.push(this.formatFileSize(attachment.size))
    }
    return parts.length > 0 ? ` (${parts.join(', ')})` : ''
  }

  private formatFileSize(size: number): string {
    if (size < 1024) {
      return `${size} B`
    }
    if (size < 1024 * 1024) {
      return `${(size / 1024).toFixed(1)} KB`
    }
    return `${(size / 1024 / 1024).toFixed(1)} MB`
  }

  private getRoleLabel(role: MessageRole): string {
    if (role === MessageRole.USER) {
      return '用户'
    }
    if (role === MessageRole.SYSTEM) {
      return '系统'
    }
    if (role === MessageRole.TOOL) {
      return '工具'
    }
    return 'AI'
  }

  private escapeHtml(text: string): string {
    return text
      .split('&').join('&amp;')
      .split('<').join('&lt;')
      .split('>').join('&gt;')
      .split('"').join('&quot;')
      .split("'").join('&#39;')
  }

  private formatTime(timestamp: number): string {
    const date = new Date(timestamp)
    const hours = date.getHours()
    const minutes = date.getMinutes().toString().padStart(2, '0')
    const period = hours >= 12 ? 'PM' : 'AM'
    const displayHours = hours % 12 || 12
    return `${displayHours}:${minutes} ${period}`
  }

  private formatDateTime(timestamp: number): string {
    const date = new Date(timestamp)
    const year = date.getFullYear()
    const month = (date.getMonth() + 1).toString().padStart(2, '0')
    const day = date.getDate().toString().padStart(2, '0')
    const hours = date.getHours().toString().padStart(2, '0')
    const minutes = date.getMinutes().toString().padStart(2, '0')
    return `${year}-${month}-${day} ${hours}:${minutes}`
  }

  private formatHtmlExportDateTime(timestamp: number): string {
    const date = new Date(timestamp)
    const year = date.getFullYear()
    const month = (date.getMonth() + 1).toString()
    const day = date.getDate().toString()
    const hours = date.getHours().toString().padStart(2, '0')
    const minutes = date.getMinutes().toString().padStart(2, '0')
    return `分享于 ${year}年${month}月${day}日 ${hours}:${minutes}`
  }
}

let conversationExportServiceInstance: ConversationExportService | null = null

export function getConversationExportService(): ConversationExportService {
  if (conversationExportServiceInstance === null) {
    conversationExportServiceInstance = new ConversationExportService()
  }
  return conversationExportServiceInstance
}
