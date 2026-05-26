/**
 * 附件存储服务
 * 将附件文件保存到应用沙箱目录，便于未来 WebDAV 同步
 */

import { fileIo } from '@kit.CoreFileKit'
import { util } from '@kit.ArkTS'
import { Context } from '@kit.AbilityKit'
import { MessageAttachment, AttachmentType } from '../models/ChatModels'
import { AIGeneratedImageFileResult, AIGeneratedImageFileSink } from '../models/AIGeneratedImageFileModels'
import { AttachmentContentService } from './AttachmentContentService'

// 附件存储目录名
const ATTACHMENTS_DIR = 'attachments'
const IMAGES_DIR = 'images'
const FILES_DIR = 'files'
const BASE64_DECODE_CHUNK_MAX_CHARS = 64 * 1024
const GENERATED_IMAGE_MAX_BYTES = 80 * 1024 * 1024

class AttachmentBase64FileSink implements AIGeneratedImageFileSink {
  private attachmentId: string
  private fileName: string
  private filePath: string
  private mimeType: string
  private file: fileIo.File | null = null
  private base64Helper: util.Base64Helper = new util.Base64Helper()
  private carry: string = ''
  private decodedBytes: number = 0
  private closed: boolean = false
  private paddingSeen: boolean = false

  constructor(attachmentId: string, fileName: string, filePath: string, mimeType: string) {
    this.attachmentId = attachmentId
    this.fileName = fileName
    this.filePath = filePath
    this.mimeType = mimeType
    try {
      this.file = fileIo.openSync(filePath, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY)
    } catch (_error) {
      this.closed = true
      throw new Error('failed to open generated image file')
    }
  }

  appendBase64Chunk(chunk: string): void {
    if (this.closed || this.file === null) {
      throw new Error('image file sink is closed')
    }
    const normalized = this.stripBase64Whitespace(chunk)
    if (normalized === '') {
      return
    }
    if (this.paddingSeen) {
      throw new Error('base64 data received after padding')
    }

    let merged = this.carry + normalized
    let decodableLength = merged.length - (merged.length % 4)
    if (decodableLength <= 0) {
      this.carry = merged
      return
    }

    const payload = merged.substring(0, decodableLength)
    this.carry = merged.substring(decodableLength)
    this.decodeAndWrite(payload)
  }

  complete(itemId: string, outputIndex: number): AIGeneratedImageFileResult {
    if (this.closed || this.file === null) {
      throw new Error('image file sink is closed')
    }
    if (this.carry !== '') {
      let finalPayload = this.carry
      const remainder = finalPayload.length % 4
      if (remainder > 0) {
        finalPayload += '===='.substring(0, 4 - remainder)
      }
      this.carry = ''
      this.decodeAndWrite(finalPayload)
    }
    try {
      fileIo.closeSync(this.file)
    } catch (_error) {
      this.file = null
      this.closed = true
      throw new Error('failed to close generated image file')
    }
    this.file = null
    this.closed = true
    return new AIGeneratedImageFileResult(
      this.attachmentId,
      this.fileName,
      this.filePath,
      this.mimeType,
      this.decodedBytes,
      itemId,
      outputIndex
    )
  }

  abort(): void {
    if (this.file !== null) {
      try {
        fileIo.closeSync(this.file)
      } catch (_e) {
        // ignore cleanup failures
      }
      this.file = null
    }
    this.closed = true
    try {
      if (fileIo.accessSync(this.filePath)) {
        fileIo.unlinkSync(this.filePath)
      }
    } catch (_e) {
      // ignore cleanup failures
    }
  }

  private decodeAndWrite(payload: string): void {
    if (payload === '') {
      return
    }
    const paddingIndex = payload.indexOf('=')
    if (paddingIndex >= 0) {
      this.paddingSeen = true
    }
    for (let offset = 0; offset < payload.length; offset += BASE64_DECODE_CHUNK_MAX_CHARS) {
      const chunk = payload.substring(offset, Math.min(offset + BASE64_DECODE_CHUNK_MAX_CHARS, payload.length))
      if (chunk === '') {
        continue
      }
      const decoded = this.base64Helper.decodeSync(chunk)
      this.decodedBytes += decoded.byteLength
      if (this.decodedBytes > GENERATED_IMAGE_MAX_BYTES) {
        throw new Error('generated image exceeds maximum allowed size')
      }
      const buffer = decoded.buffer.slice(decoded.byteOffset, decoded.byteOffset + decoded.byteLength)
      const file = this.file
      if (file === null) {
        throw new Error('image file sink is closed')
      }
      try {
        fileIo.writeSync(file.fd, buffer)
      } catch (_error) {
        throw new Error('failed to write generated image file')
      }
    }
  }

  private stripBase64Whitespace(source: string): string {
    let result = ''
    for (let i = 0; i < source.length; i++) {
      const ch = source.charAt(i)
      if (ch !== ' ' && ch !== '\n' && ch !== '\r' && ch !== '\t') {
        result += ch
      }
    }
    return result
  }
}

export class AttachmentStorageService {
  private static instance: AttachmentStorageService | null = null
  private context: Context | null = null
  private baseDir: string = ''
  private isInitialized: boolean = false

  private constructor() {}

  static getInstance(): AttachmentStorageService {
    if (AttachmentStorageService.instance === null) {
      AttachmentStorageService.instance = new AttachmentStorageService()
    }
    return AttachmentStorageService.instance
  }

  // 初始化服务
  async initialize(context: Context): Promise<void> {
    if (this.isInitialized) {
      return
    }
    this.context = context
    this.baseDir = context.filesDir
    await this.ensureDirectories()
    this.isInitialized = true
    console.info('AttachmentStorageService', `Initialized with baseDir: ${this.baseDir}`)
  }

  // 检查是否已初始化
  isReady(): boolean {
    return this.isInitialized && this.baseDir !== ''
  }

  // 确保存储目录存在
  private async ensureDirectories(): Promise<void> {
    const attachmentsPath = `${this.baseDir}/${ATTACHMENTS_DIR}`
    const imagesPath = `${attachmentsPath}/${IMAGES_DIR}`
    const filesPath = `${attachmentsPath}/${FILES_DIR}`

    try {
      fileIo.mkdirSync(attachmentsPath)
    } catch (e) {
      // 目录创建失败或已存在，忽略异常
    }

    try {
      fileIo.mkdirSync(imagesPath)
    } catch (e) {
      // 目录创建失败或已存在，忽略异常
    }

    try {
      fileIo.mkdirSync(filesPath)
    } catch (e) {
      // 目录创建失败或已存在，忽略异常
    }
  }

  // 保存附件到文件系统
  async saveAttachment(attachment: MessageAttachment): Promise<string> {
    if (!this.isInitialized || this.baseDir === '') {
      console.error('AttachmentStorageService', 'Service not initialized, baseDir is empty')
      return ''
    }

    try {
      const filePath = this.buildAttachmentFilePath(attachment)
      console.info('AttachmentStorageService', `Saving to path: ${filePath}`)

      // 如果有 base64 数据，从 base64 写入
      if (attachment.base64Data !== '') {
        const base64Helper = new util.Base64Helper()
        const data = base64Helper.decodeSync(attachment.base64Data)
        console.info('AttachmentStorageService', `Decoded data size: ${data.byteLength}`)
        const file = fileIo.openSync(filePath, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY)
        fileIo.writeSync(file.fd, data.buffer)
        fileIo.closeSync(file)
        console.info('AttachmentStorageService', `File saved successfully: ${filePath}`)
      } else {
        console.warn('AttachmentStorageService', 'No base64 data to save')
      }

      return filePath
    } catch (error) {
      console.error('AttachmentStorageService', `Failed to save attachment: ${JSON.stringify(error)}`)
      return ''
    }
  }

  createAIGeneratedImageFileSink(mimeType: string): AIGeneratedImageFileSink | null {
    if (!this.isInitialized || this.baseDir === '') {
      console.error('AttachmentStorageService', 'Service not initialized, cannot create image sink')
      return null
    }

    const seed = `${Date.now()}_${Math.floor(Math.random() * 1000000)}`
    const attachmentId = `ai_img_${seed}`
    const ext = this.getExtension('', mimeType)
    const fileName = `generated_${seed}${ext}`
    const attachment = new MessageAttachment(
      attachmentId,
      AttachmentType.IMAGE,
      fileName,
      '',
      mimeType,
      0
    )
    const filePath = this.buildAttachmentFilePath(attachment)
    try {
      if (fileIo.accessSync(filePath)) {
        fileIo.unlinkSync(filePath)
      }
    } catch (_e) {
      // 文件不存在时忽略
    }
    try {
      return new AttachmentBase64FileSink(attachmentId, fileName, filePath, mimeType)
    } catch (error) {
      console.error('AttachmentStorageService', `Failed to create generated image sink: ${JSON.stringify(error)}`)
      return null
    }
  }

  async importExistingAttachment(sourcePath: string, attachment: MessageAttachment): Promise<string> {
    if (!this.isInitialized || this.baseDir === '') {
      console.error('AttachmentStorageService', 'Service not initialized, baseDir is empty')
      return ''
    }

    try {
      const filePath = this.buildAttachmentFilePath(attachment)
      try {
        if (fileIo.accessSync(filePath)) {
          fileIo.unlinkSync(filePath)
        }
      } catch (error) {
        console.warn('AttachmentStorageService', `Existing attachment cleanup skipped: ${JSON.stringify(error)}`)
      }
      await fileIo.copyFile(sourcePath, filePath)
      return filePath
    } catch (error) {
      console.error('AttachmentStorageService', `Failed to import existing attachment: ${JSON.stringify(error)}`)
      return ''
    }
  }

  // 从文件路径读取 base64 数据（用于发送 API）
  async readAsBase64(filePath: string): Promise<string> {
    try {
      const file = fileIo.openSync(filePath, fileIo.OpenMode.READ_ONLY)
      const stat = fileIo.statSync(file.fd)
      const buffer = new ArrayBuffer(stat.size)
      fileIo.readSync(file.fd, buffer)
      fileIo.closeSync(file)

      const base64Helper = new util.Base64Helper()
      const uint8Array = new Uint8Array(buffer)
      return base64Helper.encodeToStringSync(uint8Array)
    } catch (error) {
      console.error('AttachmentStorageService', `Failed to read file as base64: ${JSON.stringify(error)}`)
      return ''
    }
  }

  // 删除附件文件
  async deleteAttachment(filePath: string): Promise<void> {
    try {
      if (filePath !== '' && fileIo.accessSync(filePath)) {
        fileIo.unlinkSync(filePath)
      }
    } catch (error) {
      console.error('AttachmentStorageService', `Failed to delete attachment: ${JSON.stringify(error)}`)
    }
  }

  // 检查文件是否存在
  fileExists(filePath: string): boolean {
    try {
      return fileIo.accessSync(filePath)
    } catch (e) {
      return false
    }
  }

  // 获取附件目录路径（用于 WebDAV 同步）
  getAttachmentsDir(): string {
    return `${this.baseDir}/${ATTACHMENTS_DIR}`
  }

  private buildAttachmentFilePath(attachment: MessageAttachment): string {
    const subDir = attachment.type === AttachmentType.IMAGE ? IMAGES_DIR : FILES_DIR
    const ext = this.getExtension(attachment.name, attachment.mimeType)
    const fileName = `${attachment.id}${ext}`
    return `${this.baseDir}/${ATTACHMENTS_DIR}/${subDir}/${fileName}`
  }

  // 获取文件扩展名
  private getExtension(fileName: string, mimeType: string): string {
    // 优先从文件名获取
    const dotIndex = fileName.lastIndexOf('.')
    if (dotIndex > 0) {
      return fileName.substring(dotIndex)
    }

    return AttachmentContentService.resolveExtensionForMimeType(mimeType)
  }
}

// 导出单例获取方法
export function getAttachmentStorageService(): AttachmentStorageService {
  return AttachmentStorageService.getInstance()
}
