export const CODE_PREVIEW_PLUGIN_KEY: string = 'cube_code_preview'
export const CODE_PREVIEW_PLUGIN_PATTERN: string = '^\\[\\[cube-chat-preview:([A-Za-z0-9_]+):(html|mermaid):(\\d+)\\]\\]$'

export interface CodePreviewBlock {
  kind: string
  language: string
  code: string
}

export class CodePreviewRegistry {
  private blocksByScope: Map<string, CodePreviewBlock[]> = new Map()

  register(scopeKey: string, blocks: CodePreviewBlock[]): void {
    this.blocksByScope.set(scopeKey, blocks)
  }

  get(scopeKey: string, index: number): CodePreviewBlock | null {
    const blocks = this.blocksByScope.get(scopeKey)
    if (blocks === undefined || index < 0 || index >= blocks.length) {
      return null
    }
    return blocks[index]
  }

  clear(scopeKey: string): void {
    this.blocksByScope.delete(scopeKey)
  }

  clearAll(): void {
    this.blocksByScope.clear()
  }
}

export class CodePreviewMarkerInjector {
  private static readonly MARKER_PREFIX: string = '[[cube-chat-preview:'
  private static readonly MARKER_SUFFIX: string = ']]'

  static inject(content: string, scopeKey: string, registry: CodePreviewRegistry): string {
    const lines = content.split('\n')
    const output: string[] = []
    const blocks: CodePreviewBlock[] = []
    let inFence = false
    let activePreviewIndex = -1

    for (let i = 0; i < lines.length; i++) {
      const line = lines[i]
      const hasTrailingNewline = i < lines.length - 1
      if (!inFence) {
        const info = CodePreviewMarkerInjector.getCodeFenceInfo(line)
        if (info !== null) {
          const language = CodePreviewMarkerInjector.normalizeCodeFenceLanguage(info)
          const kind = CodePreviewMarkerInjector.getCodePreviewKindForLanguage(language)
          activePreviewIndex = -1
          if (kind !== '') {
            activePreviewIndex = blocks.length
            blocks.push({
              kind: kind,
              language: language,
              code: ''
            })
            output.push(CodePreviewMarkerInjector.buildMarker(scopeKey, kind, activePreviewIndex))
          }
          inFence = true
        }
        output.push(line)
        continue
      }

      if (CodePreviewMarkerInjector.isClosingCodeFenceLine(line)) {
        inFence = false
        activePreviewIndex = -1
        output.push(line)
        continue
      }

      CodePreviewMarkerInjector.appendPreviewCodeLine(blocks, activePreviewIndex, line, hasTrailingNewline)
      output.push(line)
    }

    registry.register(scopeKey, blocks)
    return output.join('\n')
  }

  private static buildMarker(scopeKey: string, kind: string, index: number): string {
    return `${CodePreviewMarkerInjector.MARKER_PREFIX}${scopeKey}:${kind}:${index.toString()}${CodePreviewMarkerInjector.MARKER_SUFFIX}`
  }

  private static getCodeFenceInfo(line: string): string | null {
    let cursor = 0
    while (cursor < line.length && line.charAt(cursor) === ' ') {
      cursor++
    }
    if (cursor > 3 || line.substring(cursor, cursor + 3) !== '```') {
      return null
    }
    let fenceEnd = cursor
    while (fenceEnd < line.length && line.charAt(fenceEnd) === '`') {
      fenceEnd++
    }
    return line.substring(fenceEnd)
  }

  private static isClosingCodeFenceLine(line: string): boolean {
    const info = CodePreviewMarkerInjector.getCodeFenceInfo(line)
    return info !== null && info.trim().length === 0
  }

  private static normalizeCodeFenceLanguage(info: string): string {
    const trimmed = info.trim()
    if (trimmed === '') {
      return ''
    }
    const spaceIndex = trimmed.search(/\s/)
    const language = spaceIndex >= 0 ? trimmed.substring(0, spaceIndex) : trimmed
    return language.length > 32 ? language.substring(0, 32) : language
  }

  private static getCodePreviewKindForLanguage(language: string): string {
    const normalized = language.toLowerCase()
    if (normalized === 'html' || normalized === 'htm') {
      return 'html'
    }
    if (normalized === 'mermaid') {
      return 'mermaid'
    }
    return ''
  }

  private static appendPreviewCodeLine(
    blocks: CodePreviewBlock[],
    blockIndex: number,
    line: string,
    hasTrailingNewline: boolean
  ): void {
    if (blockIndex < 0 || blockIndex >= blocks.length) {
      return
    }
    blocks[blockIndex].code += hasTrailingNewline ? line + '\n' : line
  }
}
