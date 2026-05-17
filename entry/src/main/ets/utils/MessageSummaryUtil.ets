import { ChatMessage } from '../models/ChatModels'
import { MessagePart, MessagePartKind } from '../models/MessageParts'

const EMPTY_PLACEHOLDER = '[...]'
const SUMMARY_MAX_CHARS = 240

export function extractMessageSummary(message: ChatMessage): string {
  let text = ''
  const parts: MessagePart[] = message.parts
  if (parts.length > 0) {
    const segs: string[] = []
    for (let i = 0; i < parts.length; i++) {
      const p = parts[i]
      if (p.kind === MessagePartKind.TEXT && p.text.length > 0) {
        segs.push(p.text)
      }
    }
    text = segs.join('\n')
  }
  if (text.length === 0) {
    text = message.content
  }
  text = stripMarkdown(text)
  text = collapseWhitespace(text)
  if (text.length === 0) {
    return EMPTY_PLACEHOLDER
  }
  if (text.length > SUMMARY_MAX_CHARS) {
    return text.substring(0, SUMMARY_MAX_CHARS)
  }
  return text
}

function stripMarkdown(text: string): string {
  if (text.length === 0) {
    return text
  }
  let out = text
  // 1. 围栏代码块 ```lang\n...\n``` 整段移除
  out = out.replace(/```[\s\S]*?```/g, ' ')
  // 2. HTML 注释
  out = out.replace(/<!--[\s\S]*?-->/g, ' ')
  // 3. 图片 ![alt](url) → alt
  out = out.replace(/!\[([^\]]*)\]\([^)]*\)/g, '$1')
  // 4. 链接 [text](url) → text
  out = out.replace(/\[([^\]]+)\]\([^)]*\)/g, '$1')
  // 5. 行内代码 `xxx` → xxx
  out = out.replace(/`([^`]+)`/g, '$1')
  // 6. 粗体 / 斜体 / 删除线 标记符
  out = out.replace(/\*\*([^*]+)\*\*/g, '$1')
  out = out.replace(/__([^_]+)__/g, '$1')
  out = out.replace(/~~([^~]+)~~/g, '$1')
  // 7. 单星号 / 单下划线斜体, 在标识符两侧
  out = out.replace(/(^|[^*])\*([^*\n]+)\*(?!\*)/g, '$1$2')
  out = out.replace(/(^|[^_\w])_([^_\n]+)_(?!_)/g, '$1$2')
  // 8. LaTeX 数学界定符 $$...$$ / $...$ 去掉 $
  out = out.replace(/\$\$([\s\S]*?)\$\$/g, '$1')
  out = out.replace(/\$([^$\n]+)\$/g, '$1')
  // 9. 行首标题 #/##/...
  out = out.replace(/^[ \t]{0,3}#{1,6}[ \t]+/gm, '')
  // 10. 行首引用 >
  out = out.replace(/^[ \t]{0,3}>+[ \t]?/gm, '')
  // 11. 行首列表标记 -/+/* 或 1.
  out = out.replace(/^[ \t]{0,6}[-+*][ \t]+/gm, '')
  out = out.replace(/^[ \t]{0,6}\d+\.[ \t]+/gm, '')
  // 12. 水平分割线
  out = out.replace(/^[ \t]{0,3}([-*_])[ \t]*\1[ \t]*\1[\-*_ \t]*$/gm, ' ')
  // 13. 简单 HTML 标签
  out = out.replace(/<\/?[a-zA-Z][a-zA-Z0-9-]*\b[^>]*>/g, ' ')
  return out
}

function collapseWhitespace(text: string): string {
  if (text.length === 0) {
    return text
  }
  return text.replace(/\s+/g, ' ').trim()
}

export interface HighlightSegment {
  text: string
  hit: boolean
}

export function buildHighlightedSpans(text: string, query: string): HighlightSegment[] {
  if (query.length === 0 || text.length === 0) {
    const single: HighlightSegment = { text, hit: false }
    return [single]
  }
  const lowerText = text.toLowerCase()
  const lowerQuery = query.toLowerCase()
  const result: HighlightSegment[] = []
  let cursor = 0
  while (cursor <= text.length) {
    const idx = lowerText.indexOf(lowerQuery, cursor)
    if (idx < 0) {
      if (cursor < text.length) {
        const tail: HighlightSegment = { text: text.substring(cursor), hit: false }
        result.push(tail)
      }
      break
    }
    if (idx > cursor) {
      const before: HighlightSegment = { text: text.substring(cursor, idx), hit: false }
      result.push(before)
    }
    const hit: HighlightSegment = { text: text.substring(idx, idx + query.length), hit: true }
    result.push(hit)
    cursor = idx + query.length
  }
  if (result.length === 0) {
    const single: HighlightSegment = { text, hit: false }
    return [single]
  }
  return result
}
