import { ChatMessage } from '../models/ChatModels'
import { MessagePart, MessagePartKind } from '../models/MessageParts'
import { stripMarkdownForSummary } from './MarkdownPlainTextUtil'

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
  text = stripMarkdownForSummary(text)
  if (text.length === 0) {
    return EMPTY_PLACEHOLDER
  }
  if (text.length > SUMMARY_MAX_CHARS) {
    return text.substring(0, SUMMARY_MAX_CHARS)
  }
  return text
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
