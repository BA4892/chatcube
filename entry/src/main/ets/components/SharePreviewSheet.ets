/**
 * 分享预览弹窗组件
 * 支持三种分享模式：图片、Markdown、纯文本
 */
import { ChatMessage } from '../models/ChatModels'
import { ShareService, ShareMode, getShareService } from '../services/ShareService'
import { ShareMessageCard } from './ShareMessageCard'
import { showToast } from '../utils/ToastUtil'
import { common } from '@kit.AbilityKit'
import { display } from '@kit.ArkUI'
import { getAppUiState } from '../state/AppUiState'
import { preloadModelIcon, resolveShareModelIdentity } from '../utils/ProviderIconUtils'

const SHARE_PREVIEW_SCROLL_ID = 'share_preview_scroll_capture_source'

@ComponentV2
export struct SharePreviewSheet {
  @Param messages: ChatMessage[] = []
  @Param currentModelId: string = ''
  @Param assistantAvatarValue: string = 'AI'
  @Param assistantAvatarColor: string = '#4E6F9E'
  @Param assistantAvatarCacheKey: number = 0
  @Local selectedMode: ShareMode = ShareMode.IMAGE
  @Local isSharing: boolean = false
  @Local previewText: string = ''
  @Local iconRenderVersion: number = 0
  @Local cardContentHeight: number = 0
  @Local cardContentHeightUpdatedAt: number = 0
  @Local scrollViewportHeight: number = 0
  @Local scrollViewportWidth: number = 0
  private previewScroller: Scroller = new Scroller()
  private get themePrimary(): string {
    return getAppUiState().themePrimary
  }
  private get themePrimaryLight(): string {
    return getAppUiState().themePrimaryLight
  }
  @Event onClose: () => void = () => {}

  private shareService: ShareService = getShareService()
  private iconPreloadTask: Promise<void> | null = null

  private showShareToast(message: string | Resource, duration: number = 2000): void {
    showToast(this.getUIContext(), message, duration)
  }

  aboutToAppear(): void {
    console.info('SharePreviewSheet', `[aboutToAppear] 消息数量: ${this.messages.length}, 分享模式: ${this.selectedMode}`)
    // 初始化预览文本
    this.updatePreviewText()
    void this.ensureShareModelIconsReady()
  }

  // 更新预览文本
  private updatePreviewText(): void {
    if (this.selectedMode === ShareMode.MARKDOWN) {
      this.previewText = this.shareService.convertToMarkdown(this.messages)
    } else if (this.selectedMode === ShareMode.TEXT) {
      this.previewText = this.shareService.convertToPlainText(this.messages)
    }
  }

  private extractErrorText(error: Object): string {
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

  build() {
    Column() {
      // 标题栏
      Row() {
        Text($r('app.string.share_title'))
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))

        Blank()

        // 关闭按钮
        Row() {
          SymbolGlyph($r('sys.symbol.xmark'))
            .fontSize(16)
            .fontColor([$r('app.color.text_secondary')])
        }
        .width(32)
        .height(32)
        .borderRadius(16)
        .backgroundColor($r('app.color.divider'))
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          this.onClose()
        })
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 16, bottom: 12 })

      // 分享模式选择
      Row() {
        this.ModeButton($r('app.string.share_mode_image'), ShareMode.IMAGE, $r('sys.symbol.picture'))
        this.ModeButton($r('app.string.share_mode_markdown'), ShareMode.MARKDOWN, $r('sys.symbol.doc_text'))
        this.ModeButton($r('app.string.share_mode_text'), ShareMode.TEXT, $r('sys.symbol.text_alignleft'))
      }
      .width('100%')
      .padding({ left: 20, right: 20 })
      .justifyContent(FlexAlign.SpaceBetween)

      // 预览区域
      Column() {
        if (this.messages.length === 0) {
          // 空状态提示
          Column() {
            SymbolGlyph($r('sys.symbol.exclamationmark_circle'))
              .fontSize(48)
              .fontColor([$r('app.color.text_tertiary')])
              .margin({ bottom: 12 })
            Text($r('app.string.share_no_content'))
              .fontSize(16)
              .fontColor($r('app.color.text_secondary'))
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else if (this.selectedMode === ShareMode.IMAGE) {
          // 截图复用预览态 Scroll 的已渲染像素,避免 Sheet 父链 clip 与 Markdown 离屏 Worker 异步未完成的问题。
          Scroll(this.previewScroller) {
            Column() {
              ShareMessageCard({
                messages: this.messages,
                appName: 'Cube Chat',
                currentModelId: this.currentModelId,
                iconRenderVersion: this.iconRenderVersion,
                assistantAvatarValue: this.assistantAvatarValue,
                assistantAvatarColor: this.assistantAvatarColor,
                assistantAvatarCacheKey: this.assistantAvatarCacheKey
              })
                .margin(16)
                .onAreaChange((_old: Area, newArea: Area) => {
                  const newHeight = newArea.height as number
                  if (newHeight !== this.cardContentHeight) {
                    this.cardContentHeight = newHeight
                    this.cardContentHeightUpdatedAt = Date.now()
                  }
                })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Center)
          }
          .id(SHARE_PREVIEW_SCROLL_ID)
          .width('100%')
          .layoutWeight(1)
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
          .onAreaChange((_old: Area, newArea: Area) => {
            this.scrollViewportHeight = newArea.height as number
            this.scrollViewportWidth = newArea.width as number
          })
        } else {
          // 文本预览
          Scroll() {
            Text(this.previewText)
              .fontSize(13)
              .fontColor($r('app.color.text_primary'))
              .lineHeight(20)
              .width('100%')
              .textAlign(TextAlign.Start)
          }
          .width('100%')
          .layoutWeight(1)
          .padding(16)
          .scrollBar(BarState.Auto)
          .edgeEffect(EdgeEffect.Spring)
          .backgroundColor($r('app.color.surface'))
          .borderRadius(12)
          .margin({ left: 20, right: 20, top: 12 })
        }
      }
      .width('100%')
      .layoutWeight(1)

      // 分享按钮
      Button(this.isSharing ? $r('app.string.sharing') : $r('app.string.share_button'))
        .width('100%')
        .height(48)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .backgroundColor(this.themePrimary)
        .borderRadius(24)
        .margin({ left: 20, right: 20, top: 12, bottom: 20 })
        .enabled(!this.isSharing && this.messages.length > 0)
        .opacity(this.messages.length > 0 ? 1 : 0.5)
        .onClick(() => {
          this.handleShare()
        })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.background'))
  }

  // 总内容高度(vp):ShareMessageCard 自身 + 上下 16 vp margin
  private getTotalContentVp(): number {
    if (this.cardContentHeight <= 0) {
      return 0
    }
    return this.cardContentHeight + 32
  }

  // 计算截图缩放比例:软件 PixelMap 受 128 MB 序列化上限约束(GPU 8192px 限制只针对单帧 componentSnapshot,
  // 不影响拼接成的软件 PixelMap),所以按内存预算反推最大 scale,留出余量到 100 MB。
  // 一般对话 scale=1 保持原始清晰度,极长对话才降级,避免出现 133×8192 这样的过度压扁。
  private getCaptureScale(): number {
    const totalVp = this.getTotalContentVp()
    if (totalVp <= 0 || this.scrollViewportWidth <= 0) {
      return 1
    }
    let density: number = 1
    try {
      density = display.getDefaultDisplaySync().densityPixels
    } catch (_e) {
      return 1
    }
    const widthPx = this.scrollViewportWidth * density
    const heightPx = totalVp * density
    const estimatedBytes = widthPx * heightPx * 4
    const memoryBudget = 100 * 1024 * 1024
    if (estimatedBytes <= memoryBudget) {
      return 1
    }
    return Math.sqrt(memoryBudget / estimatedBytes)
  }

  // 等待 ShareMessageCard 高度稳定,避免 Markdown 异步排版时就开始截图。
  private async waitForCardStable(maxWaitMs: number = 4000, stableThresholdMs: number = 250): Promise<void> {
    const start = Date.now()
    while (true) {
      const sinceLastUpdate = Date.now() - this.cardContentHeightUpdatedAt
      if (this.cardContentHeight > 0 && this.cardContentHeightUpdatedAt > 0 && sinceLastUpdate >= stableThresholdMs) {
        return
      }
      if (Date.now() - start >= maxWaitMs) {
        return
      }
      await new Promise<void>((resolve) => setTimeout(() => resolve(), 100))
    }
  }

  private collectShareModelIds(): string[] {
    const ids: string[] = []
    for (let i = 0; i < this.messages.length; i++) {
      const message = this.messages[i]
      const id = resolveShareModelIdentity(message.modelId, this.currentModelId, message.modelName)
      if (id !== '' && !ids.includes(id)) {
        ids.push(id)
      }
    }
    return ids
  }

  private async ensureShareModelIconsReady(): Promise<void> {
    if (this.iconPreloadTask !== null) {
      await this.iconPreloadTask
      return
    }

    const modelIds = this.collectShareModelIds()
    if (modelIds.length === 0) {
      return
    }

    this.iconPreloadTask = this.preloadShareModelIcons(modelIds)
    try {
      await this.iconPreloadTask
    } finally {
      this.iconPreloadTask = null
    }
  }

  private async preloadShareModelIcons(modelIds: string[]): Promise<void> {
    console.info('SharePreviewSheet', `[preloadShareModelIcons] start, model count: ${modelIds.length}`)
    try {
      await Promise.all(modelIds.map(async (modelId) => {
        const result = await preloadModelIcon(modelId)
        if (result === '') {
          console.warn('SharePreviewSheet', `[preloadShareModelIcons] model icon unavailable: ${modelId}`)
        }
      }))
    } catch (error) {
      console.warn('SharePreviewSheet', `[preloadShareModelIcons] preload failed: ${this.extractErrorText(error)}`)
    } finally {
      this.iconRenderVersion += 1
      console.info('SharePreviewSheet', `[preloadShareModelIcons] done, iconRenderVersion=${this.iconRenderVersion}`)
    }
  }

  @Builder
  ModeButton(label: string | Resource, mode: ShareMode, icon: Resource) {
    Column() {
      Row() {
        SymbolGlyph(icon)
          .fontSize(20)
          .fontColor([this.selectedMode === mode ? this.themePrimary : $r('app.color.text_secondary')])
      }
      .width(48)
      .height(48)
      .borderRadius(24)
      .backgroundColor(this.selectedMode === mode ? this.themePrimaryLight : $r('app.color.surface'))
      .justifyContent(FlexAlign.Center)

      Text(label)
        .fontSize(12)
        .fontColor(this.selectedMode === mode ? this.themePrimary : $r('app.color.text_secondary'))
        .margin({ top: 6 })
    }
    .alignItems(HorizontalAlign.Center)
    .onClick(() => {
      if (this.selectedMode !== mode) {
        this.selectedMode = mode
        this.updatePreviewText()
      }
    })
  }

  // 处理分享
  private async handleShare(): Promise<void> {
    if (this.messages.length === 0) {
      console.warn('SharePreviewSheet', '[handleShare] no message to share')
      this.showShareToast($r('app.string.share_no_content'))
      return
    }

    this.isSharing = true
    console.info('SharePreviewSheet', `[handleShare] 开始分享，模式: ${this.selectedMode}, 消息数: ${this.messages.length}`)

    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext
      if (!context) {
        console.error('SharePreviewSheet', '[handleShare] app context unavailable')
        this.showShareToast($r('app.string.share_context_unavailable'))
        this.isSharing = false
        return
      }
      this.shareService.init(context)

      if (this.selectedMode === ShareMode.IMAGE) {
        // 图片分享：截取卡片组件
        await this.shareAsImage()
      } else if (this.selectedMode === ShareMode.MARKDOWN) {
        // Markdown 分享
        const content = this.shareService.convertToMarkdown(this.messages)
        const result = await this.shareService.shareText(content, 'conversation.md')
        if (!result.success) {
          if (result.errorMessage !== '') {
            this.showShareToast(result.errorMessage)
          } else {
            this.showShareToast($r('app.string.share_failed'))
          }
        }
      } else {
        // 纯文本分享
        const content = this.shareService.convertToPlainText(this.messages)
        const result = await this.shareService.shareText(content, 'conversation')
        if (!result.success) {
          if (result.errorMessage !== '') {
            this.showShareToast(result.errorMessage)
          } else {
            this.showShareToast($r('app.string.share_failed'))
          }
        }
      }
    } catch (e) {
      console.error('SharePreviewSheet', `分享失败: ${JSON.stringify(e)}`)
      this.showShareToast($r('app.string.share_failed'))
    } finally {
      this.isSharing = false
    }
  }

  // 图片分享
  private async shareAsImage(): Promise<void> {
    try {
      console.info('SharePreviewSheet', '[shareAsImage] start scroll-stitch sharing flow')
      await this.ensureShareModelIconsReady()
      await this.waitForCardStable()

      if (this.cardContentHeight <= 0 || this.scrollViewportHeight <= 0) {
        console.error('SharePreviewSheet',
          `[shareAsImage] invalid sizes: card=${this.cardContentHeight}, viewport=${this.scrollViewportHeight}`)
        this.showShareToast($r('app.string.share_snapshot_failed'))
        return
      }

      const scale = this.getCaptureScale()
      const totalContentVp = this.getTotalContentVp()
      console.info('SharePreviewSheet',
        `[shareAsImage] totalContent=${totalContentVp}, viewport=${this.scrollViewportHeight}, scale=${scale}`)

      const filePath = await this.shareService.captureScrollableAsImage({
        scroller: this.previewScroller,
        scrollAreaId: SHARE_PREVIEW_SCROLL_ID,
        uiContext: this.getUIContext(),
        totalContentVp: totalContentVp,
        viewportVp: this.scrollViewportHeight,
        scale: scale
      })
      console.info('SharePreviewSheet', `[shareAsImage] image saved: ${filePath}`)

      const result = await this.shareService.shareImage(filePath, 'conversation')
      if (!result.success) {
        console.error('SharePreviewSheet', `[shareAsImage] 分享失败: ${result.errorMessage}`)
        if (result.errorMessage !== '') {
          this.showShareToast(result.errorMessage)
        } else {
          this.showShareToast($r('app.string.share_failed'))
        }
      } else {
        console.info('SharePreviewSheet', '[shareAsImage] shared')
      }
    } catch (e) {
      const errorMessage = this.extractErrorText(e)
      console.error('SharePreviewSheet', `[shareAsImage] 图片分享失败: ${errorMessage}`)
      if (errorMessage.indexOf('截图失败') >= 0) {
        this.showShareToast($r('app.string.share_snapshot_failed'))
      } else {
        this.showShareToast($r('app.string.share_failed'))
      }
    }
  }
}
