import { util } from '@kit.ArkTS'
import { AttachmentType, MessageAttachment } from '../models/ChatModels'

const NO_TEXT_EXTRACTOR_ID = ''
const PLAIN_TEXT_EXTRACTOR_ID = 'plain-text'

export class AttachmentTextExtractionResult {
  text: string
  truncated: boolean
  sourceLength: number

  constructor(text: string, truncated: boolean, sourceLength: number) {
    this.text = text
    this.truncated = truncated
    this.sourceLength = sourceLength
  }
}

export interface AttachmentTextExtractor {
  extract(attachment: MessageAttachment, maxChars: number): AttachmentTextExtractionResult | null
}

class AttachmentTextExtractorDefinition {
  id: string
  extractor: AttachmentTextExtractor

  constructor(id: string, extractor: AttachmentTextExtractor) {
    this.id = id
    this.extractor = extractor
  }
}

class PlainTextAttachmentExtractor implements AttachmentTextExtractor {
  extract(attachment: MessageAttachment, maxChars: number): AttachmentTextExtractionResult | null {
    if (attachment.base64Data === '') {
      return null
    }
    const decodedContent = this.decodeUtf8TextAttachment(attachment)
    if (decodedContent === '') {
      return null
    }
    if (decodedContent.length <= maxChars) {
      return new AttachmentTextExtractionResult(decodedContent, false, decodedContent.length)
    }
    return new AttachmentTextExtractionResult(
      decodedContent.substring(0, maxChars),
      true,
      decodedContent.length
    )
  }

  private decodeUtf8TextAttachment(attachment: MessageAttachment): string {
    try {
      const base64Helper = new util.Base64Helper()
      const data = base64Helper.decodeSync(attachment.base64Data)
      const decoder = util.TextDecoder.create('utf-8')
      return decoder.decodeToString(data, { stream: false })
    } catch (error) {
      console.error('AttachmentContentService',
        `Failed to decode text attachment ${attachment.id}: ${JSON.stringify(error)}`)
      return ''
    }
  }
}

export class AttachmentFileTypeDefinition {
  extensions: string[]
  mimeType: string
  textExtractorId: string
  selectableAsDocument: boolean

  constructor(
    extensions: string[],
    mimeType: string,
    textExtractorId: string = NO_TEXT_EXTRACTOR_ID,
    selectableAsDocument: boolean = true
  ) {
    this.extensions = extensions
    this.mimeType = mimeType
    this.textExtractorId = textExtractorId
    this.selectableAsDocument = selectableAsDocument
  }
}

const DOCUMENT_FILE_TYPES: AttachmentFileTypeDefinition[] = [
  new AttachmentFileTypeDefinition(['.pdf'], 'application/pdf'),
  new AttachmentFileTypeDefinition(['.doc'], 'application/msword'),
  new AttachmentFileTypeDefinition(
    ['.docx'],
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
  ),
  new AttachmentFileTypeDefinition(['.txt'], 'text/plain', PLAIN_TEXT_EXTRACTOR_ID),
  new AttachmentFileTypeDefinition(['.md', '.markdown', '.mdx'], 'text/markdown', PLAIN_TEXT_EXTRACTOR_ID),
  new AttachmentFileTypeDefinition(['.csv'], 'text/csv', PLAIN_TEXT_EXTRACTOR_ID),
  new AttachmentFileTypeDefinition(['.json'], 'application/json', PLAIN_TEXT_EXTRACTOR_ID),
  new AttachmentFileTypeDefinition(['.js', '.mjs', '.cjs'], 'application/javascript', PLAIN_TEXT_EXTRACTOR_ID),
  new AttachmentFileTypeDefinition(['.ts'], 'text/typescript', PLAIN_TEXT_EXTRACTOR_ID),
  new AttachmentFileTypeDefinition(['.tsx'], 'text/tsx', PLAIN_TEXT_EXTRACTOR_ID),
  new AttachmentFileTypeDefinition(['.html', '.htm'], 'text/html', PLAIN_TEXT_EXTRACTOR_ID),
  new AttachmentFileTypeDefinition(['.xml'], 'application/xml', PLAIN_TEXT_EXTRACTOR_ID),
  new AttachmentFileTypeDefinition(['.yaml', '.yml'], 'application/x-yaml', PLAIN_TEXT_EXTRACTOR_ID),
  new AttachmentFileTypeDefinition(['.log'], 'text/plain', PLAIN_TEXT_EXTRACTOR_ID),
  new AttachmentFileTypeDefinition(['.py'], 'text/x-python', PLAIN_TEXT_EXTRACTOR_ID),
  new AttachmentFileTypeDefinition(['.java'], 'text/x-java-source', PLAIN_TEXT_EXTRACTOR_ID),
  new AttachmentFileTypeDefinition(['.kt', '.kts'], 'text/x-kotlin', PLAIN_TEXT_EXTRACTOR_ID),
  new AttachmentFileTypeDefinition(['.dart'], 'text/x-dart', PLAIN_TEXT_EXTRACTOR_ID),
  new AttachmentFileTypeDefinition(['.c', '.h'], 'text/x-c', PLAIN_TEXT_EXTRACTOR_ID),
  new AttachmentFileTypeDefinition(['.cc', '.cpp', '.cxx', '.hpp', '.hxx'], 'text/x-c++', PLAIN_TEXT_EXTRACTOR_ID),
  new AttachmentFileTypeDefinition(['.cs'], 'text/x-csharp', PLAIN_TEXT_EXTRACTOR_ID),
  new AttachmentFileTypeDefinition(['.go'], 'text/x-go', PLAIN_TEXT_EXTRACTOR_ID),
  new AttachmentFileTypeDefinition(['.rs'], 'text/x-rust', PLAIN_TEXT_EXTRACTOR_ID),
  new AttachmentFileTypeDefinition(['.sql'], 'application/sql', PLAIN_TEXT_EXTRACTOR_ID),
  new AttachmentFileTypeDefinition(['.sh'], 'application/x-sh', PLAIN_TEXT_EXTRACTOR_ID),
  new AttachmentFileTypeDefinition(['.bat', '.cmd'], 'application/x-bat', PLAIN_TEXT_EXTRACTOR_ID),
  new AttachmentFileTypeDefinition(['.ps1'], 'application/x-powershell', PLAIN_TEXT_EXTRACTOR_ID),
  new AttachmentFileTypeDefinition(['.toml'], 'application/toml', PLAIN_TEXT_EXTRACTOR_ID),
  new AttachmentFileTypeDefinition(['.ini', '.properties'], 'text/plain', PLAIN_TEXT_EXTRACTOR_ID)
]

const MEDIA_FILE_TYPES: AttachmentFileTypeDefinition[] = [
  new AttachmentFileTypeDefinition(['.jpg', '.jpeg'], 'image/jpeg', NO_TEXT_EXTRACTOR_ID, false),
  new AttachmentFileTypeDefinition(['.png'], 'image/png', NO_TEXT_EXTRACTOR_ID, false),
  new AttachmentFileTypeDefinition(['.gif'], 'image/gif', NO_TEXT_EXTRACTOR_ID, false),
  new AttachmentFileTypeDefinition(['.webp'], 'image/webp', NO_TEXT_EXTRACTOR_ID, false)
]

const ATTACHMENT_FILE_TYPES: AttachmentFileTypeDefinition[] = [
  ...DOCUMENT_FILE_TYPES,
  ...MEDIA_FILE_TYPES
]

const ATTACHMENT_TEXT_EXTRACTORS: AttachmentTextExtractorDefinition[] = [
  new AttachmentTextExtractorDefinition(PLAIN_TEXT_EXTRACTOR_ID, new PlainTextAttachmentExtractor())
]

export class AttachmentContentService {
  private static readonly MAX_INLINE_TEXT_ATTACHMENT_CHARS: number = 120000

  static registerFileType(definition: AttachmentFileTypeDefinition): void {
    ATTACHMENT_FILE_TYPES.push(definition)
    if (definition.selectableAsDocument) {
      DOCUMENT_FILE_TYPES.push(definition)
    }
  }

  static registerTextExtractor(id: string, extractor: AttachmentTextExtractor): void {
    ATTACHMENT_TEXT_EXTRACTORS.push(new AttachmentTextExtractorDefinition(id, extractor))
  }

  static getDocumentSuffixFilters(): string[] {
    const filters: string[] = []
    for (let i = 0; i < DOCUMENT_FILE_TYPES.length; i++) {
      if (!DOCUMENT_FILE_TYPES[i].selectableAsDocument) {
        continue
      }
      for (let j = 0; j < DOCUMENT_FILE_TYPES[i].extensions.length; j++) {
        const extension = DOCUMENT_FILE_TYPES[i].extensions[j]
        if (!AttachmentContentService.containsString(filters, extension)) {
          filters.push(extension)
        }
      }
    }
    return filters
  }

  static resolveMimeType(fileName: string): string {
    const definition = AttachmentContentService.findDefinitionByFileName(fileName)
    return definition !== null ? definition.mimeType : 'application/octet-stream'
  }

  static resolveExtensionForMimeType(mimeType: string): string {
    const normalizedMime = mimeType.toLowerCase().trim()
    if (normalizedMime === '') {
      return ''
    }
    for (let i = ATTACHMENT_FILE_TYPES.length - 1; i >= 0; i--) {
      if (ATTACHMENT_FILE_TYPES[i].mimeType === normalizedMime &&
        ATTACHMENT_FILE_TYPES[i].extensions.length > 0) {
        return ATTACHMENT_FILE_TYPES[i].extensions[0]
      }
    }
    return ''
  }

  static canExtractInlineText(attachment: MessageAttachment): boolean {
    return AttachmentContentService.findTextExtractorForAttachment(attachment) !== null
  }

  static extractInlineText(attachment: MessageAttachment): AttachmentTextExtractionResult | null {
    if (attachment.base64Data === '') {
      return null
    }
    const extractor = AttachmentContentService.findTextExtractorForAttachment(attachment)
    if (extractor === null) {
      return null
    }
    return extractor.extract(attachment, AttachmentContentService.MAX_INLINE_TEXT_ATTACHMENT_CHARS)
  }

  static appendInlineTextAttachments(content: string, attachments: MessageAttachment[]): string {
    const attachmentContent = AttachmentContentService.buildInlineTextAttachmentsContent(attachments)
    if (attachmentContent === '') {
      return content
    }
    return content !== '' ? `${attachmentContent}\n\n${content}` : attachmentContent
  }

  static buildNonInlineFileAttachmentText(attachments: MessageAttachment[]): string {
    const parts: string[] = []
    for (let i = 0; i < attachments.length; i++) {
      const attachment = attachments[i]
      if (attachment.type === AttachmentType.FILE &&
        attachment.base64Data !== '' &&
        !AttachmentContentService.canExtractInlineText(attachment)) {
        parts.push(`[附件无法本地解析: ${attachment.name} (${attachment.mimeType})。当前版本仅支持文本类附件正文读取；该文件会尝试按模型原生附件能力发送，若模型不支持，请改用 Markdown/TXT/CSV，或复制文件正文后再发送。]`)
      }
    }
    return parts.join('\n')
  }

  private static buildInlineTextAttachmentsContent(attachments: MessageAttachment[]): string {
    const sections: string[] = []
    for (let i = 0; i < attachments.length; i++) {
      const attachment = attachments[i]
      if (attachment.base64Data === '') {
        continue
      }
      const extractionResult = AttachmentContentService.extractInlineText(attachment)
      if (extractionResult === null || extractionResult.text === '') {
        continue
      }
      let truncatedText = ''
      if (extractionResult.truncated) {
        truncatedText = `\n[附件内容已截断，仅包含前 ${AttachmentContentService.MAX_INLINE_TEXT_ATTACHMENT_CHARS} 个字符]`
      }
      sections.push(`[附件内容开始: ${attachment.name} (${attachment.mimeType})]\n${extractionResult.text}${truncatedText}\n[附件内容结束: ${attachment.name}]`)
    }
    return sections.join('\n\n')
  }

  private static containsString(values: string[], value: string): boolean {
    for (let i = 0; i < values.length; i++) {
      if (values[i] === value) {
        return true
      }
    }
    return false
  }

  private static findTextExtractorForAttachment(attachment: MessageAttachment): AttachmentTextExtractor | null {
    if (attachment.type !== AttachmentType.FILE) {
      return null
    }

    const definition = AttachmentContentService.findDefinitionByFileName(attachment.name) ||
      AttachmentContentService.findDefinitionByMimeType(attachment.mimeType)
    if (definition !== null && definition.textExtractorId !== NO_TEXT_EXTRACTOR_ID) {
      return AttachmentContentService.findTextExtractorById(definition.textExtractorId)
    }

    if (AttachmentContentService.isFallbackPlainTextMimeType(attachment.mimeType)) {
      return AttachmentContentService.findTextExtractorById(PLAIN_TEXT_EXTRACTOR_ID)
    }

    return null
  }

  private static findTextExtractorById(id: string): AttachmentTextExtractor | null {
    for (let i = ATTACHMENT_TEXT_EXTRACTORS.length - 1; i >= 0; i--) {
      if (ATTACHMENT_TEXT_EXTRACTORS[i].id === id) {
        return ATTACHMENT_TEXT_EXTRACTORS[i].extractor
      }
    }
    return null
  }

  private static findDefinitionByFileName(fileName: string): AttachmentFileTypeDefinition | null {
    const extension = AttachmentContentService.getFileExtension(fileName)
    if (extension === '') {
      return null
    }
    for (let i = ATTACHMENT_FILE_TYPES.length - 1; i >= 0; i--) {
      const definition = ATTACHMENT_FILE_TYPES[i]
      for (let j = 0; j < definition.extensions.length; j++) {
        if (definition.extensions[j] === extension) {
          return definition
        }
      }
    }
    return null
  }

  private static findDefinitionByMimeType(mimeType: string): AttachmentFileTypeDefinition | null {
    const normalizedMime = mimeType.toLowerCase().trim()
    if (normalizedMime === '') {
      return null
    }
    for (let i = ATTACHMENT_FILE_TYPES.length - 1; i >= 0; i--) {
      if (ATTACHMENT_FILE_TYPES[i].mimeType === normalizedMime) {
        return ATTACHMENT_FILE_TYPES[i]
      }
    }
    return null
  }

  private static isFallbackPlainTextMimeType(mimeType: string): boolean {
    const normalizedMime = mimeType.toLowerCase().trim()
    return normalizedMime.startsWith('text/') ||
      normalizedMime === 'application/json' ||
      normalizedMime === 'application/xml' ||
      normalizedMime === 'application/javascript' ||
      normalizedMime === 'application/x-yaml' ||
      normalizedMime === 'application/sql' ||
      normalizedMime === 'application/toml'
  }

  private static getFileExtension(fileName: string): string {
    const dotIndex = fileName.lastIndexOf('.')
    if (dotIndex < 0) {
      return ''
    }
    return fileName.substring(dotIndex).toLowerCase()
  }
}
