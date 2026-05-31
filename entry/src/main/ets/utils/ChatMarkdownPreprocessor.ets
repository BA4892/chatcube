export class ChatMarkdownPreprocessor {
  static preprocess(content: string): string {
    if (content.length === 0) {
      return content
    }
    let result = ChatMarkdownPreprocessor.convertTaskListToReadonly(content)
    result = ChatMarkdownPreprocessor.normalizeLatexDelimiters(result)
    result = ChatMarkdownPreprocessor.convertHeadingsWithLatex(result)
    return result
  }

  private static convertTaskListToReadonly(content: string): string {
    let result = content.replace(/^(\s*[-*])\s*\[ \]/gm, '$1 ☐')
    result = result.replace(/^(\s*[-*])\s*\[[xX]\]/gm, '$1 ☑')
    return result
  }

  private static normalizeLatexDelimiters(content: string): string {
    const codeBlocks: string[] = []
    let protectedContent = content.replace(/```[\s\S]*?```|`[^`\n]+`/g, (match: string): string => {
      codeBlocks.push(match)
      return `\u0000CODE${(codeBlocks.length - 1).toString()}\u0000`
    })

    protectedContent = protectedContent.replace(/\\\[([\s\S]*?)\\\]/g, (_match: string, p1: string): string => {
      return `$$${p1}$$`
    })
    protectedContent = protectedContent.replace(/\\\(([\s\S]*?)\\\)/g, (_match: string, p1: string): string => {
      return `$${p1}$`
    })

    protectedContent = protectedContent.replace(/\u0000CODE(\d+)\u0000/g, (_match: string, idx: string): string => {
      return codeBlocks[parseInt(idx)]
    })
    return protectedContent
  }

  private static convertHeadingsWithLatex(content: string): string {
    const codeBlocks: string[] = []
    let result = content.replace(/```[\s\S]*?```/g, (match: string): string => {
      codeBlocks.push(match)
      return `\u0000HCB${(codeBlocks.length - 1).toString()}\u0000`
    })

    result = result.replace(
      /^(#{1,6})\s+(.+)$/gm,
      (match: string, hashes: string, text: string): string => {
        if (!/\$.+?\$/.test(text)) {
          return match
        }
        const firstDollar = text.indexOf('$')
        const headingText = text.substring(0, firstDollar).trimEnd()
        const latexAndRest = text.substring(firstDollar)

        if (headingText.length > 0) {
          return `${hashes} ${headingText}\n\n${latexAndRest}`
        }
        return latexAndRest
      }
    )

    result = result.replace(/\u0000HCB(\d+)\u0000/g, (_match: string, idx: string): string => {
      return codeBlocks[parseInt(idx)]
    })
    return result
  }
}
