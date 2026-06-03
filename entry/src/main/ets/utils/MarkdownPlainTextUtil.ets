export enum MarkdownCodeBlockMode {
  Remove = 'remove',
  Unwrap = 'unwrap',
  Keep = 'keep'
}

export enum MarkdownInlineCodeMode {
  Remove = 'remove',
  Unwrap = 'unwrap',
  Keep = 'keep'
}

export enum MarkdownImageMode {
  Remove = 'remove',
  Alt = 'alt'
}

export enum MarkdownMathMode {
  Remove = 'remove',
  Unwrap = 'unwrap',
  Placeholder = 'placeholder'
}

export enum MarkdownTextSpanMode {
  Remove = 'remove',
  Unwrap = 'unwrap'
}

export interface MarkdownPlainTextOptions {
  codeBlockMode?: MarkdownCodeBlockMode
  inlineCodeMode?: MarkdownInlineCodeMode
  imageMode?: MarkdownImageMode
  mathMode?: MarkdownMathMode
  strikethroughMode?: MarkdownTextSpanMode
  collapseWhitespace?: boolean
  preserveParagraphs?: boolean
}

class MarkdownPlainTextResolvedOptions {
  codeBlockMode: MarkdownCodeBlockMode = MarkdownCodeBlockMode.Unwrap
  inlineCodeMode: MarkdownInlineCodeMode = MarkdownInlineCodeMode.Unwrap
  imageMode: MarkdownImageMode = MarkdownImageMode.Alt
  mathMode: MarkdownMathMode = MarkdownMathMode.Unwrap
  strikethroughMode: MarkdownTextSpanMode = MarkdownTextSpanMode.Unwrap
  collapseWhitespace: boolean = false
  preserveParagraphs: boolean = true
}

class MarkdownFenceMarker {
  marker: string = ''
  length: number = 0
}

function resolveOptions(options?: MarkdownPlainTextOptions): MarkdownPlainTextResolvedOptions {
  const resolved = new MarkdownPlainTextResolvedOptions()
  if (!options) {
    return resolved
  }
  if (options.codeBlockMode !== undefined) {
    resolved.codeBlockMode = options.codeBlockMode
  }
  if (options.inlineCodeMode !== undefined) {
    resolved.inlineCodeMode = options.inlineCodeMode
  }
  if (options.imageMode !== undefined) {
    resolved.imageMode = options.imageMode
  }
  if (options.mathMode !== undefined) {
    resolved.mathMode = options.mathMode
  }
  if (options.strikethroughMode !== undefined) {
    resolved.strikethroughMode = options.strikethroughMode
  }
  if (options.collapseWhitespace !== undefined) {
    resolved.collapseWhitespace = options.collapseWhitespace
  }
  if (options.preserveParagraphs !== undefined) {
    resolved.preserveParagraphs = options.preserveParagraphs
  }
  return resolved
}

function normalizeLineEndings(text: string): string {
  return text.split('\r\n').join('\n').split('\r').join('\n')
}

function countFenceLength(fence: string, marker: string): number {
  let length = 0
  while (length < fence.length && fence.charAt(length) === marker) {
    length++
  }
  return length
}

function parseOpeningFence(line: string): MarkdownFenceMarker | null {
  const match = /^[ \t]{0,3}(`{3,}|~{3,})(.*)$/.exec(line)
  if (match === null) {
    return null
  }
  const fence = match[1]
  const marker = fence.charAt(0)
  const info = match[2]
  if (marker === '`' && info.indexOf('`') >= 0) {
    return null
  }
  const result = new MarkdownFenceMarker()
  result.marker = marker
  result.length = fence.length
  return result
}

function isClosingFence(line: string, opening: MarkdownFenceMarker): boolean {
  const match = /^[ \t]{0,3}(`+|~+)[ \t]*$/.exec(line)
  if (match === null) {
    return false
  }
  const fence = match[1]
  if (fence.charAt(0) !== opening.marker) {
    return false
  }
  return countFenceLength(fence, opening.marker) >= opening.length
}

function processFencedCodeBlocks(text: string, mode: MarkdownCodeBlockMode): string {
  if (mode === MarkdownCodeBlockMode.Keep || text.length === 0) {
    return text
  }

  const lines = text.split('\n')
  const result: string[] = []
  let opening: MarkdownFenceMarker | null = null

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i]
    if (opening !== null) {
      if (isClosingFence(line, opening)) {
        opening = null
        continue
      }
      if (mode === MarkdownCodeBlockMode.Unwrap) {
        result.push(line)
      }
      continue
    }

    const nextOpening = parseOpeningFence(line)
    if (nextOpening !== null) {
      opening = nextOpening
      if (mode === MarkdownCodeBlockMode.Remove) {
        result.push('')
      }
      continue
    }

    result.push(line)
  }

  return result.join('\n')
}

function replaceImages(text: string, mode: MarkdownImageMode): string {
  if (mode === MarkdownImageMode.Remove) {
    return text.replace(/!\[([^\]]*)\]\([^)]*\)/g, ' ')
  }
  return text.replace(/!\[([^\]]*)\]\([^)]*\)/g, '$1')
}

function replaceInlineCode(text: string, mode: MarkdownInlineCodeMode): string {
  if (mode === MarkdownInlineCodeMode.Keep) {
    return text
  }
  if (mode === MarkdownInlineCodeMode.Remove) {
    return text.replace(/`[^`]*`/g, ' ')
  }
  return text.replace(/`([^`]+)`/g, '$1')
}

function replaceMath(text: string, mode: MarkdownMathMode): string {
  if (mode === MarkdownMathMode.Remove) {
    return text
      .replace(/\$\$[\s\S]*?\$\$/g, ' ')
      .replace(/\$[^$\n]*\$/g, ' ')
      .replace(/\\\[[\s\S]*?\\\]/g, ' ')
      .replace(/\\\([\s\S]*?\\\)/g, ' ')
  }
  if (mode === MarkdownMathMode.Placeholder) {
    return text
      .replace(/\$\$[\s\S]*?\$\$/g, '公式')
      .replace(/\$[^$\n]*\$/g, '公式')
      .replace(/\\\[[\s\S]*?\\\]/g, '公式')
      .replace(/\\\([\s\S]*?\\\)/g, '公式')
  }
  return text
    .replace(/\$\$([\s\S]*?)\$\$/g, '$1')
    .replace(/\$([^$\n]+)\$/g, '$1')
    .replace(/\\\[([\s\S]*?)\\\]/g, '$1')
    .replace(/\\\(([\s\S]*?)\\\)/g, '$1')
}

function replaceTextSpans(text: string, strikethroughMode: MarkdownTextSpanMode): string {
  let out = text
  out = out.replace(/\*\*\*([^*\n]+)\*\*\*/g, '$1')
  out = out.replace(/___([^_\n]+)___/g, '$1')
  out = out.replace(/\*\*([^*\n]+)\*\*/g, '$1')
  out = out.replace(/__([^_\n]+)__/g, '$1')
  if (strikethroughMode === MarkdownTextSpanMode.Remove) {
    out = out.replace(/~~([^~]+)~~/g, ' ')
  } else {
    out = out.replace(/~~([^~]+)~~/g, '$1')
  }
  out = out.replace(/(^|[^*])\*([^*\n]+)\*(?!\*)/g, '$1$2')
  out = out.replace(/(^|[^_\w])_([^_\n]+)_(?!_)/g, '$1$2')
  return out
}

function stripBlockMarkers(text: string): string {
  let out = text
  out = out.replace(/^[ \t]{0,3}#{1,6}[ \t]+/gm, '')
  out = out.replace(/^[ \t]{0,3}>+[ \t]?/gm, '')
  out = out.replace(/^[ \t]{0,6}[-+*][ \t]+/gm, '')
  out = out.replace(/^[ \t]{0,6}\d+\.[ \t]+/gm, '')
  out = out.replace(/^[ \t]{0,3}([-*_])[ \t]*\1[ \t]*\1[-*_ \t]*$/gm, ' ')
  return out
}

function collapseBlankLines(text: string): string {
  return text.replace(/[ \t]+\n/g, '\n').replace(/\n{3,}/g, '\n\n')
}

export function removeMarkdownCodeBlocks(markdown: string): string {
  return processFencedCodeBlocks(normalizeLineEndings(markdown), MarkdownCodeBlockMode.Remove)
}

export function markdownToPlainText(markdown: string, options?: MarkdownPlainTextOptions): string {
  if (markdown.length === 0) {
    return ''
  }

  const resolved = resolveOptions(options)
  let out = normalizeLineEndings(markdown)
  out = processFencedCodeBlocks(out, resolved.codeBlockMode)
  out = out.replace(/<!--[\s\S]*?-->/g, ' ')
  out = replaceMath(out, resolved.mathMode)
  out = replaceImages(out, resolved.imageMode)
  out = out.replace(/\[([^\]]+)\]\([^)]*\)/g, '$1')
  out = out.replace(/\[([^\]]+)\]\[[^\]]*]/g, '$1')
  out = replaceInlineCode(out, resolved.inlineCodeMode)
  out = replaceTextSpans(out, resolved.strikethroughMode)
  out = stripBlockMarkers(out)
  out = out.replace(/<\/?[a-zA-Z][a-zA-Z0-9-]*\b[^>]*>/g, ' ')

  if (resolved.collapseWhitespace) {
    return out.replace(/\s+/g, ' ').trim()
  }
  if (resolved.preserveParagraphs) {
    return collapseBlankLines(out).trim()
  }
  return out.trim()
}

export function stripMarkdownForPlainTextExport(markdown: string): string {
  return markdownToPlainText(markdown, {
    codeBlockMode: MarkdownCodeBlockMode.Unwrap,
    inlineCodeMode: MarkdownInlineCodeMode.Unwrap,
    imageMode: MarkdownImageMode.Alt,
    mathMode: MarkdownMathMode.Unwrap,
    strikethroughMode: MarkdownTextSpanMode.Unwrap,
    preserveParagraphs: true
  })
}

export function stripMarkdownForTextSelection(markdown: string): string {
  return stripMarkdownForPlainTextExport(markdown)
}

export function stripMarkdownForSummary(markdown: string): string {
  return markdownToPlainText(markdown, {
    codeBlockMode: MarkdownCodeBlockMode.Remove,
    inlineCodeMode: MarkdownInlineCodeMode.Unwrap,
    imageMode: MarkdownImageMode.Alt,
    mathMode: MarkdownMathMode.Unwrap,
    strikethroughMode: MarkdownTextSpanMode.Unwrap,
    collapseWhitespace: true,
    preserveParagraphs: false
  })
}

export function stripMarkdownForTts(markdown: string): string {
  return markdownToPlainText(markdown, {
    codeBlockMode: MarkdownCodeBlockMode.Remove,
    inlineCodeMode: MarkdownInlineCodeMode.Remove,
    imageMode: MarkdownImageMode.Remove,
    mathMode: MarkdownMathMode.Placeholder,
    strikethroughMode: MarkdownTextSpanMode.Remove,
    preserveParagraphs: true
  })
}
