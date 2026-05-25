import { webview } from '@kit.ArkWeb'
import { AttachmentProcessState, AttachmentType, MessageAttachment } from '../models/ChatModels'
import { getAttachmentStorageService } from './AttachmentStorageService'

const WEB_PARSER_URL = 'resource://rawfile/document-parser/document-parser.html'
const BASE64_CHUNK_SIZE = 256 * 1024
const WEB_READY_TIMEOUT_MS = 5000
const WEB_PARSE_TIMEOUT_MS = 45000

export class DocumentParseLimits {
  static readonly DOCX_HARD_BYTES: number = 25 * 1024 * 1024
  static readonly EXCEL_HARD_BYTES: number = 20 * 1024 * 1024
  static readonly PDF_HARD_BYTES: number = 30 * 1024 * 1024
  static readonly MAX_EXTRACTED_CHARS: number = 120000
}

export class DocumentParseResult {
  success: boolean = false
  text: string = ''
  engine: string = ''
  error: string = ''
  warning: string = ''
  truncated: boolean = false
}

interface WebDocumentParseResultJson {
  success?: boolean
  text?: string
  engine?: string
  error?: string
  warning?: string
  truncated?: boolean
}

interface WebDocumentParseInput {
  taskId: string
  fileName: string
  mimeType: string
  size: number
  maxChars: number
}

export class DocumentParsePolicy {
  static readonly WEB_PARSER_URL: string = WEB_PARSER_URL

  static isWebParseCandidate(attachment: MessageAttachment): boolean {
    if (attachment.type !== AttachmentType.FILE) {
      return false
    }
    const ext = DocumentParsePolicy.getExtension(attachment.name)
    const mime = attachment.mimeType.toLowerCase()
    return ext === '.xlsx' ||
      ext === '.xls' ||
      ext === '.docx' ||
      ext === '.pdf' ||
      mime === 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' ||
      mime === 'application/vnd.ms-excel' ||
      mime === 'application/vnd.openxmlformats-officedocument.wordprocessingml.document' ||
      mime === 'application/pdf'
  }

  static getHardLimitBytes(attachment: MessageAttachment): number {
    const ext = DocumentParsePolicy.getExtension(attachment.name)
    const mime = attachment.mimeType.toLowerCase()
    if (ext === '.docx' || mime === 'application/vnd.openxmlformats-officedocument.wordprocessingml.document') {
      return DocumentParseLimits.DOCX_HARD_BYTES
    }
    if (ext === '.xlsx' || ext === '.xls' ||
      mime === 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' ||
      mime === 'application/vnd.ms-excel') {
      return DocumentParseLimits.EXCEL_HARD_BYTES
    }
    if (ext === '.pdf' || mime === 'application/pdf') {
      return DocumentParseLimits.PDF_HARD_BYTES
    }
    return 0
  }

  static shouldBlockSend(attachment: MessageAttachment): boolean {
    if (!DocumentParsePolicy.isWebParseCandidate(attachment)) {
      return false
    }
    if (attachment.parsedText !== '') {
      return false
    }
    const state = attachment.processState
    return state === AttachmentProcessState.IDLE ||
      state === AttachmentProcessState.COPYING ||
      state === AttachmentProcessState.QUEUED ||
      state === AttachmentProcessState.PARSING ||
      state === AttachmentProcessState.TOO_LARGE ||
      state === AttachmentProcessState.PASSWORD_REQUIRED ||
      state === AttachmentProcessState.PARSE_FAILED
  }

  static getBlockingReason(attachments: MessageAttachment[]): string {
    for (let i = 0; i < attachments.length; i++) {
      const attachment = attachments[i]
      if (!DocumentParsePolicy.shouldBlockSend(attachment)) {
        continue
      }
      const state = attachment.processState
      if (state === AttachmentProcessState.TOO_LARGE) {
        return `附件过大，暂不支持解析：${attachment.name}`
      }
      if (state === AttachmentProcessState.PARSE_FAILED) {
        const suffix = attachment.parseError !== '' ? `：${attachment.parseError}` : ''
        return `附件解析失败，请移除或更换文件后再发送：${attachment.name}${suffix}`
      }
      if (state === AttachmentProcessState.PASSWORD_REQUIRED) {
        return `加密文件无法解析：${attachment.name}`
      }
      return `附件仍在解析中：${attachment.name}`
    }
    return ''
  }

  static getExtension(fileName: string): string {
    const index = fileName.lastIndexOf('.')
    if (index < 0) {
      return ''
    }
    return fileName.substring(index).toLowerCase()
  }
}

export class WebDocumentParserService {
  cancelChecker: (() => boolean) | null = null
  private controller: webview.WebviewController | null = null
  private isReady: boolean = false

  attachController(controller: webview.WebviewController): void {
    this.controller = controller
  }

  markReady(): void {
    this.isReady = true
  }

  markNotReady(): void {
    this.isReady = false
  }

  async cancelCurrentParse(): Promise<void> {
    if (this.controller === null || !this.isReady) {
      return
    }
    try {
      await this.runScript('window.DocumentParserBridge.cancel()')
    } catch (_error) {
    }
  }

  async parseAttachment(attachment: MessageAttachment): Promise<DocumentParseResult> {
    const shouldCancel = this.cancelChecker
    const result = new DocumentParseResult()
    if (!DocumentParsePolicy.isWebParseCandidate(attachment)) {
      result.success = false
      result.error = 'unsupported_file_type'
      return result
    }
    const hardLimit = DocumentParsePolicy.getHardLimitBytes(attachment)
    if (hardLimit > 0 && attachment.size > hardLimit) {
      result.success = false
      result.error = 'file_too_large'
      return result
    }
    this.throwIfCanceled(shouldCancel)
    await this.waitUntilReady(shouldCancel)
    this.throwIfCanceled(shouldCancel)
    const base64Data = await this.loadBase64Data(attachment)
    this.throwIfCanceled(shouldCancel)
    if (base64Data === '') {
      result.success = false
      result.error = 'empty_file_data'
      return result
    }
    return this.parseBase64(attachment, base64Data, shouldCancel)
  }

  private async waitUntilReady(shouldCancel: (() => boolean) | null): Promise<void> {
    const start = Date.now()
    while (!this.isReady) {
      this.throwIfCanceled(shouldCancel)
      if (Date.now() - start > WEB_READY_TIMEOUT_MS) {
        throw new Error('document_parser_not_ready')
      }
      await new Promise<void>((resolve) => setTimeout(resolve, 80))
    }
  }

  private async loadBase64Data(attachment: MessageAttachment): Promise<string> {
    if (attachment.base64Data !== '') {
      return attachment.base64Data
    }
    if (attachment.filePath === '') {
      return ''
    }
    return getAttachmentStorageService().readAsBase64(attachment.filePath)
  }

  private async parseBase64(
    attachment: MessageAttachment,
    base64Data: string,
    shouldCancel: (() => boolean) | null
  ): Promise<DocumentParseResult> {
    const taskId = `doc_${Date.now()}_${Math.floor(Math.random() * 100000)}`
    const input: WebDocumentParseInput = {
      taskId: taskId,
      fileName: attachment.name,
      mimeType: attachment.mimeType,
      size: attachment.size,
      maxChars: DocumentParseLimits.MAX_EXTRACTED_CHARS
    }
    this.throwIfCanceled(shouldCancel)
    await this.runScript(`window.DocumentParserBridge.start(${JSON.stringify(input)})`)
    for (let offset = 0; offset < base64Data.length; offset += BASE64_CHUNK_SIZE) {
      this.throwIfCanceled(shouldCancel)
      const chunk = base64Data.substring(offset, Math.min(offset + BASE64_CHUNK_SIZE, base64Data.length))
      await this.runScript(`window.DocumentParserBridge.append(${JSON.stringify(chunk)})`)
    }
    const initialResult = await this.runScript('window.DocumentParserBridge.finish()')
    const rawResult = await this.waitForWebParseResult(initialResult, shouldCancel)
    return this.parseWebResult(rawResult)
  }

  private async waitForWebParseResult(
    initialResult: string,
    shouldCancel: (() => boolean) | null
  ): Promise<string> {
    if (this.isWebParseJsonResult(initialResult)) {
      return initialResult
    }
    const start = Date.now()
    while (Date.now() - start <= WEB_PARSE_TIMEOUT_MS) {
      if (this.isCanceled(shouldCancel)) {
        await this.cancelCurrentParse()
        throw new Error('document_parser_canceled')
      }
      const rawResult = await this.runScript('window.DocumentParserBridge.getResult()')
      if (this.isWebParseJsonResult(rawResult)) {
        return rawResult
      }
      await new Promise<void>((resolve) => setTimeout(resolve, 80))
    }
    throw new Error('document_parser_timeout')
  }

  private isWebParseJsonResult(value: string): boolean {
    const normalized = value.trim()
    return normalized.startsWith('{') && normalized.endsWith('}')
  }

  private isCanceled(shouldCancel: (() => boolean) | null): boolean {
    return shouldCancel !== null && shouldCancel()
  }

  private throwIfCanceled(shouldCancel: (() => boolean) | null): void {
    if (this.isCanceled(shouldCancel)) {
      throw new Error('document_parser_canceled')
    }
  }

  private async runScript(script: string): Promise<string> {
    if (this.controller === null) {
      throw new Error('document_parser_controller_missing')
    }
    try {
      const value = await this.controller.runJavaScript(script)
      if (value === undefined || value === null) {
        return ''
      }
      return this.normalizeRunJavaScriptResult(value.toString())
    } catch (error) {
      throw new Error(`document_parser_script_failed: ${JSON.stringify(error)}`)
    }
  }

  private normalizeRunJavaScriptResult(value: string): string {
    let normalized = value.trim()
    for (let i = 0; i < 2; i++) {
      if (!((normalized.startsWith('"') && normalized.endsWith('"')) ||
        (normalized.startsWith("'") && normalized.endsWith("'")))) {
        return normalized
      }
      try {
        const parsed = JSON.parse(normalized) as string
        if (typeof parsed !== 'string') {
          return normalized
        }
        normalized = parsed.trim()
      } catch (_error) {
        return normalized
      }
    }
    return normalized
  }

  private parseWebResult(raw: string): DocumentParseResult {
    const result = new DocumentParseResult()
    try {
      const json = JSON.parse(raw) as WebDocumentParseResultJson
      result.success = json.success === true
      result.text = json.text ?? ''
      result.engine = json.engine ?? ''
      result.error = json.error ?? ''
      result.warning = json.warning ?? ''
      result.truncated = json.truncated === true
      return result
    } catch (error) {
      result.success = false
      result.error = `invalid_parser_result: ${JSON.stringify(error)}`
      return result
    }
  }
}
