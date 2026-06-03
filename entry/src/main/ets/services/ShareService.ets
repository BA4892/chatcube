/**
 * 分享服务
 * 提供消息分享功能：图片分享、Markdown分享、纯文本分享、网页分享
 */
import { systemShare } from '@kit.ShareKit'
import { uniformTypeDescriptor as utd } from '@kit.ArkData'
import { fileUri } from '@kit.CoreFileKit'
import { image } from '@kit.ImageKit'
import { fileIo as fs } from '@kit.CoreFileKit'
import { common } from '@kit.AbilityKit'
import { display, componentSnapshot } from '@kit.ArkUI'
import { ChatMessage } from '../models/ChatModels'
import { getConversationExportService } from './ConversationExportService'

// 分享模式枚举
export enum ShareMode {
  IMAGE = 'image',      // 图片分享（卡片风格）
  MARKDOWN = 'markdown', // Markdown 格式
  TEXT = 'text',        // 纯文本格式
  HTML = 'html'         // 网页文件
}

// 分享结果
export interface ShareResult {
  success: boolean
  errorMessage: string
}

// 滚动截图选项
export interface CaptureScrollableOptions {
  scroller: Scroller
  scrollAreaId: string
  uiContext: UIContext
  totalContentVp: number
  viewportVp: number
  scale: number
}

interface StitchContext {
  pixelMap: image.PixelMap
  widthPx: number
  segHeightPx: number
  totalHeightPx: number
}

export class ShareService {
  private context: common.UIAbilityContext | null = null
  private readonly snapshotRetryCount: number = 5
  private readonly snapshotRetryDelayMs: number = 200
  private readonly scrollSettleMs: number = 120
  private readonly maxScrollSegments: number = 80
  private readonly exportService = getConversationExportService()

  // 初始化服务
  init(context: common.UIAbilityContext): void {
    this.context = context
  }

  // 将消息列表转换为 Markdown 格式
  convertToMarkdown(messages: ChatMessage[], sessionTitle: string = ''): string {
    return this.exportService.toMarkdown(this.exportService.buildModel(messages, sessionTitle))
  }

  // 将消息列表转换为纯文本格式
  convertToPlainText(messages: ChatMessage[], sessionTitle: string = ''): string {
    return this.exportService.toPlainText(this.exportService.buildModel(messages, sessionTitle))
  }

  // 将消息列表转换为 HTML 文件内容
  convertToHtml(messages: ChatMessage[], assistantAvatarValue: string = 'AI',
    assistantAvatarColor: string = '', currentModelId: string = '', assistantAvatarCacheKey: number = 0,
    sessionTitle: string = ''): string {
    return this.exportService.toHtml(
      this.exportService.buildModel(messages, sessionTitle),
      assistantAvatarValue,
      assistantAvatarColor,
      currentModelId,
      assistantAvatarCacheKey,
      this.context
    )
  }

  // 分享文本内容
  async shareText(content: string, title: string = '分享对话'): Promise<ShareResult> {
    if (this.context === null) {
      console.error('ShareService', '[shareText] 服务未初始化')
      return { success: false, errorMessage: '服务未初始化' }
    }

    try {
      console.info('ShareService', `[shareText] 开始分享文本，内容长度: ${content.length}`)
      const shareData = new systemShare.SharedData({
        utd: utd.UniformDataType.PLAIN_TEXT,
        content: content,
        title: title
      })

      const controller = new systemShare.ShareController(shareData)
      console.info('ShareService', '[shareText] 打开分享面板')
      await controller.show(this.context, {
        selectionMode: systemShare.SelectionMode.SINGLE,
        previewMode: systemShare.SharePreviewMode.DETAIL
      })

      console.info('ShareService', '[shareText] 分享面板已关闭')
      return { success: true, errorMessage: '' }
    } catch (error) {
      console.error('ShareService', `[shareText] 分享文本失败: ${JSON.stringify(error)}`)
      return { success: false, errorMessage: `分享失败: ${error}` }
    }
  }

  // 生成并分享 HTML 文件
  async shareHtml(messages: ChatMessage[], title: string = 'conversation.html',
    assistantAvatarValue: string = 'AI', assistantAvatarColor: string = '', currentModelId: string = '',
    assistantAvatarCacheKey: number = 0, sessionTitle: string = ''): Promise<ShareResult> {
    if (this.context === null) {
      console.error('ShareService', '[shareHtml] 服务未初始化')
      return { success: false, errorMessage: '服务未初始化' }
    }

    try {
      const model = this.exportService.buildModel(messages, sessionTitle)
      const html = this.exportService.toHtml(
        model,
        assistantAvatarValue,
        assistantAvatarColor,
        currentModelId,
        assistantAvatarCacheKey,
        this.context
      )
      const fileName = this.buildHtmlShareFileName(model.appName, model.title, model.exportedAt)
      const filePath = this.writeHtmlFile(html, fileName)
      const shareTitle = this.resolveHtmlShareTitle(title, fileName)
      console.info('ShareService', `[shareHtml] HTML 文件已生成: ${filePath}`)
      return await this.shareHtmlFile(filePath, shareTitle)
    } catch (error) {
      console.error('ShareService', `[shareHtml] 分享网页失败: ${JSON.stringify(error)}`)
      return { success: false, errorMessage: `分享失败: ${error}` }
    }
  }

  // 分享 HTML 文件
  async shareHtmlFile(htmlPath: string, title: string = 'conversation.html'): Promise<ShareResult> {
    if (this.context === null) {
      console.error('ShareService', '[shareHtmlFile] 服务未初始化')
      return { success: false, errorMessage: '服务未初始化' }
    }

    try {
      console.info('ShareService', `[shareHtmlFile] 开始分享 HTML: ${htmlPath}`)
      const uri = fileUri.getUriFromPath(htmlPath)
      const shareData = new systemShare.SharedData({
        utd: utd.UniformDataType.HTML,
        uri: uri,
        title: title
      })

      const controller = new systemShare.ShareController(shareData)
      console.info('ShareService', '[shareHtmlFile] 打开分享面板')
      await controller.show(this.context, {
        selectionMode: systemShare.SelectionMode.SINGLE,
        previewMode: systemShare.SharePreviewMode.DETAIL
      })

      console.info('ShareService', '[shareHtmlFile] 分享面板已关闭')
      return { success: true, errorMessage: '' }
    } catch (error) {
      console.error('ShareService', `[shareHtmlFile] 分享 HTML 失败: ${JSON.stringify(error)}`)
      return { success: false, errorMessage: `分享失败: ${error}` }
    }
  }

  // 分享图片
  async shareImage(imagePath: string, title: string = '分享对话'): Promise<ShareResult> {
    if (this.context === null) {
      console.error('ShareService', '[shareImage] 服务未初始化')
      return { success: false, errorMessage: '服务未初始化' }
    }

    try {
      console.info('ShareService', `[shareImage] 开始分享图片: ${imagePath}`)
      const uri = fileUri.getUriFromPath(imagePath)
      const imageUtd = this.resolveImageUtd(imagePath)
      console.info('ShareService', `[shareImage] 文件URI: ${uri}`)

      const shareData = new systemShare.SharedData({
        utd: imageUtd,
        uri: uri,
        title: title
      })

      const controller = new systemShare.ShareController(shareData)
      console.info('ShareService', '[shareImage] 打开分享面板')
      await controller.show(this.context, {
        selectionMode: systemShare.SelectionMode.SINGLE,
        previewMode: systemShare.SharePreviewMode.DETAIL
      })

      console.info('ShareService', '[shareImage] 分享面板已关闭')
      return { success: true, errorMessage: '' }
    } catch (error) {
      console.error('ShareService', `[shareImage] 分享图片失败: ${JSON.stringify(error)}`)
      return { success: false, errorMessage: `分享失败: ${error}` }
    }
  }

  private resolveImageUtd(imagePath: string): string {
    const extension = this.getFileExtension(imagePath)
    if (extension === '') {
      return utd.UniformDataType.IMAGE
    }
    try {
      return utd.getUniformDataTypeByFilenameExtension(extension, utd.UniformDataType.IMAGE)
    } catch (error) {
      console.warn('ShareService', `Resolve image UTD failed: ${JSON.stringify(error)}`)
      return utd.UniformDataType.IMAGE
    }
  }

  private getFileExtension(filePath: string): string {
    const queryIndex = filePath.indexOf('?')
    const cleanPath = queryIndex >= 0 ? filePath.substring(0, queryIndex) : filePath
    const dotIndex = cleanPath.lastIndexOf('.')
    if (dotIndex < 0 || dotIndex === cleanPath.length - 1) {
      return ''
    }
    const extension = cleanPath.substring(dotIndex + 1).toLowerCase()
    return extension === 'jpeg' ? 'jpg' : extension
  }

  // 滚动截图并拼接成完整长图。复用预览态 Scroll 内已渲染的 ShareMessageCard,
  // 利用每段 viewport 的 componentSnapshot.get 截取已绘制像素,再按偏移拼接,
  // 绕开 Sheet 父链 clip 与 createFromBuilder 离屏 Markdown 异步未完成的问题。
  async captureScrollableAsImage(opts: CaptureScrollableOptions): Promise<string> {
    if (opts.totalContentVp <= 0 || opts.viewportVp <= 0) {
      throw new Error(`截图失败: 无效尺寸 (content=${opts.totalContentVp}, viewport=${opts.viewportVp})`)
    }

    let stitchContext: StitchContext | null = null

    try {
      const density = display.getDefaultDisplaySync().densityPixels
      const maxScrollVp = Math.max(0, opts.totalContentVp - opts.viewportVp)

      let currentTargetVp = 0
      const stepVp = opts.viewportVp
      let safety = 0
      while (safety < this.maxScrollSegments) {
        safety += 1
        opts.scroller.scrollTo({ xOffset: 0, yOffset: currentTargetVp, animation: false })
        await this.sleep(this.scrollSettleMs)

        const pm = await this.captureScrollSnapshot(opts.uiContext, opts.scrollAreaId, opts.scale)
        try {
          if (stitchContext === null) {
            stitchContext = await this.createStitchContext(pm, opts.totalContentVp, opts.scale, density)
          }
          await this.writeSegmentToStitched(stitchContext, pm, currentTargetVp, opts.scale, density)
        } finally {
          try {
            pm.release()
          } catch (_e) {
            // ignore
          }
        }

        if (currentTargetVp >= maxScrollVp) {
          break
        }
        currentTargetVp = Math.min(currentTargetVp + stepVp, maxScrollVp)
      }

      if (stitchContext === null) {
        throw new Error('截图失败: 未生成任何片段')
      }

      const filePath = await this.writePixelMapToImageFile(stitchContext.pixelMap)
      return filePath
    } catch (e) {
      const msg = `截图失败: ${this.describeError(e)}`
      console.error('ShareService', `[captureScrollableAsImage] ${msg}`)
      throw new Error(msg)
    } finally {
      if (stitchContext !== null) {
        try {
          stitchContext.pixelMap.release()
        } catch (_e) {
          // ignore
        }
      }
      try {
        opts.scroller.scrollTo({ xOffset: 0, yOffset: 0, animation: false })
      } catch (_e) {
        // ignore
      }
    }
  }

  private async captureScrollSnapshot(uiContext: UIContext, id: string, scale: number): Promise<image.PixelMap> {
    const snapshot = uiContext.getComponentSnapshot()
    let lastError: Object | null = null
    for (let attempt = 0; attempt < this.snapshotRetryCount; attempt++) {
      try {
        const options: componentSnapshot.SnapshotOptions = {
          scale: scale,
          waitUntilRenderFinished: true
        }
        return await snapshot.get(id, options)
      } catch (error) {
        lastError = error
        console.error('ShareService',
          `[captureScrollSnapshot] attempt ${(attempt + 1).toString()} failed: ${this.describeError(error)}`)
        if (attempt < this.snapshotRetryCount - 1) {
          await this.sleep(this.snapshotRetryDelayMs)
        }
      }
    }
    throw new Error(`snapshot.get failed: ${this.describeError(lastError)}`)
  }

  private async createStitchContext(
    firstSegment: image.PixelMap,
    totalContentVp: number,
    scale: number,
    density: number
  ): Promise<StitchContext> {
    const firstInfo = await firstSegment.getImageInfo()
    const widthPx = firstInfo.size.width
    const segHeightPx = firstInfo.size.height
    const stitchPixelFormat = firstInfo.pixelFormat
    // buffer 创建 PixelMap 时源格式默认可能按 BGRA_8888 解释,这里显式声明源/目标格式一致。
    // 分段像素搬运使用 readPixels/writePixels 成对接口,避免 readPixelsToBuffer 与 writePixels
    // 混用时再手动猜测 R/B 通道顺序。
    console.info('ShareService',
      `[stitchSegments] segment pixelFormat=${stitchPixelFormat}, using paired readPixels/writePixels`)

    let totalHeightPx = Math.round(totalContentVp * density * scale)
    if (totalHeightPx <= 0) {
      totalHeightPx = segHeightPx
    }

    const totalBuffer = new ArrayBuffer(widthPx * totalHeightPx * 4)
    const initOpts: image.InitializationOptions = {
      size: { width: widthPx, height: totalHeightPx },
      srcPixelFormat: stitchPixelFormat,
      pixelFormat: stitchPixelFormat,
      alphaType: image.AlphaType.UNPREMUL,
      editable: true
    }
    const pixelMap = image.createPixelMapSync(totalBuffer, initOpts)

    return { pixelMap, widthPx, segHeightPx, totalHeightPx }
  }

  private async writeSegmentToStitched(
    stitchContext: StitchContext,
    segment: image.PixelMap,
    yOffsetVp: number,
    scale: number,
    density: number
  ): Promise<void> {
    let yPx = Math.round(yOffsetVp * density * scale)
    if (yPx < 0) {
      yPx = 0
    }
    if (yPx >= stitchContext.totalHeightPx) {
      return
    }
    // 仅写入落在 [yPx, totalHeightPx) 区间内的行,避免把 Scroll viewport 末尾的空白复制进去。
    const effectiveHeight = Math.min(stitchContext.segHeightPx, stitchContext.totalHeightPx - yPx)
    if (effectiveHeight <= 0) {
      return
    }

    const segBuffer = new ArrayBuffer(stitchContext.widthPx * effectiveHeight * 4)
    const readArea: image.PositionArea = {
      pixels: segBuffer,
      offset: 0,
      stride: stitchContext.widthPx * 4,
      region: {
        size: { width: stitchContext.widthPx, height: effectiveHeight },
        x: 0,
        y: 0
      }
    }
    await segment.readPixels(readArea)

    const area: image.PositionArea = {
      pixels: segBuffer,
      offset: 0,
      stride: stitchContext.widthPx * 4,
      region: {
        size: { width: stitchContext.widthPx, height: effectiveHeight },
        x: 0,
        y: yPx
      }
    }
    await stitchContext.pixelMap.writePixels(area)
  }

  private async writePixelMapToImageFile(pixelMap: image.PixelMap): Promise<string> {
    let packer: image.ImagePacker | null = null
    let file: fs.File | null = null
    try {
      packer = image.createImagePacker()
      const packOpts: image.PackingOption = {
        format: 'image/png',
        quality: 100
      }
      const arrayBuffer = await packer.packToData(pixelMap, packOpts)

      const fileName = `share_${Date.now()}.png`
      const imageDir = this.context?.cacheDir ?? this.context?.tempDir ?? ''
      const filePath = `${imageDir}/${fileName}`

      if (imageDir === '') {
        throw new Error('share image directory unavailable')
      }

      try {
        fs.accessSync(imageDir)
      } catch (_error) {
        fs.mkdirSync(imageDir, true)
      }

      file = fs.openSync(filePath, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY)
      fs.writeSync(file.fd, arrayBuffer)
      return filePath
    } catch (error) {
      console.error('ShareService', `Failed to write share image file: ${JSON.stringify(error)}`)
      throw new Error(`Failed to write share image file: ${JSON.stringify(error)}`)
    } finally {
      if (file !== null) {
        try {
          fs.closeSync(file)
        } catch (error) {
          console.error('ShareService', `Failed to close share image file: ${JSON.stringify(error)}`)
        }
      }
      if (packer !== null) {
        packer.release()
      }
    }
  }

  private writeHtmlFile(content: string, fileName: string): string {
    let file: fs.File | null = null
    try {
      const normalizedFileName = this.normalizeHtmlFileName(fileName)
      const htmlDir = this.context?.cacheDir ?? this.context?.tempDir ?? ''
      if (htmlDir === '') {
        throw new Error('share html directory unavailable')
      }

      try {
        fs.accessSync(htmlDir)
      } catch (_error) {
        fs.mkdirSync(htmlDir, true)
      }

      const filePath = this.resolveAvailableFilePath(htmlDir, normalizedFileName)
      file = fs.openSync(filePath, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC)
      fs.writeSync(file.fd, content)
      return filePath
    } catch (error) {
      console.error('ShareService', `Failed to write share html file: ${JSON.stringify(error)}`)
      throw new Error(`Failed to write share html file: ${JSON.stringify(error)}`)
    } finally {
      if (file !== null) {
        try {
          fs.closeSync(file)
        } catch (error) {
          console.error('ShareService', `Failed to close share html file: ${JSON.stringify(error)}`)
        }
      }
    }
  }

  private buildHtmlShareFileName(appName: string, title: string, timestamp: number): string {
    const app = this.sanitizeFileNamePart(appName, 'Cube Chat')
    const conversationTitle = this.sanitizeFileNamePart(title, '对话记录')
    const dateText = this.formatHtmlFileDateTime(timestamp)
    let baseName = `${app} ${conversationTitle} ${dateText}`.trim()
    baseName = this.truncateFileNameBase(baseName, 96)
    return `${baseName}.html`
  }

  private resolveHtmlShareTitle(title: string, fileName: string): string {
    const value = title.trim()
    if (value === '' || value === 'conversation.html') {
      return fileName
    }
    return value
  }

  private normalizeHtmlFileName(fileName: string): string {
    let value = this.sanitizeFileNamePart(fileName, '')
    if (value === '') {
      value = this.buildHtmlShareFileName('Cube Chat', '对话记录', Date.now())
    }
    if (!value.toLowerCase().endsWith('.html')) {
      value += '.html'
    }
    return value
  }

  private sanitizeFileNamePart(value: string, fallback: string): string {
    let result = value
      .replace(/[\\/:*?"<>|\r\n\t]+/g, ' ')
      .replace(/\s+/g, ' ')
      .trim()
    while (result.endsWith('.') || result.endsWith(' ')) {
      result = result.substring(0, result.length - 1).trim()
    }
    if (result === '' || result === '.' || result === '..') {
      return fallback
    }
    return result
  }

  private truncateFileNameBase(value: string, maxLength: number): string {
    if (value.length <= maxLength) {
      return value
    }
    return value.substring(0, maxLength).trim()
  }

  private formatHtmlFileDateTime(timestamp: number): string {
    const date = new Date(timestamp)
    const year = date.getFullYear().toString()
    const month = (date.getMonth() + 1).toString().padStart(2, '0')
    const day = date.getDate().toString().padStart(2, '0')
    const hours = date.getHours().toString().padStart(2, '0')
    const minutes = date.getMinutes().toString().padStart(2, '0')
    return `${year}年${month}月${day}日 ${hours}点${minutes}分`
  }

  private resolveAvailableFilePath(directory: string, fileName: string): string {
    const extension = '.html'
    const lowerName = fileName.toLowerCase()
    const baseName = lowerName.endsWith(extension) ? fileName.substring(0, fileName.length - extension.length) : fileName
    let candidate = `${directory}/${fileName}`
    if (!this.fileExists(candidate)) {
      return candidate
    }
    for (let i = 2; i <= 99; i++) {
      candidate = `${directory}/${baseName} (${i})${extension}`
      if (!this.fileExists(candidate)) {
        return candidate
      }
    }
    return `${directory}/${baseName} ${Date.now()}${extension}`
  }

  private fileExists(path: string): boolean {
    try {
      fs.accessSync(path)
      return true
    } catch (_error) {
      return false
    }
  }

  private async sleep(delayMs: number): Promise<void> {
    await new Promise<void>((resolve) => {
      setTimeout(() => resolve(), delayMs)
    })
  }

  private describeError(error: Object | null): string {
    if (error === null) {
      return 'unknown error'
    }
    const text = `${error}`
    if (text !== '' && text !== '[object Object]') {
      return text
    }
    const json = JSON.stringify(error)
    if (json !== '' && json !== '{}') {
      return json
    }
    return 'unknown error'
  }

}

// 单例实例
let shareServiceInstance: ShareService | null = null

export function getShareService(): ShareService {
  if (shareServiceInstance === null) {
    shareServiceInstance = new ShareService()
  }
  return shareServiceInstance
}
