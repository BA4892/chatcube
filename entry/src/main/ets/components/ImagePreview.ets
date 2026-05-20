import { photoAccessHelper } from '@kit.MediaLibraryKit'
import { fileIo, fileUri } from '@kit.CoreFileKit'
import { buffer } from '@kit.ArkTS'
import { common } from '@kit.AbilityKit'
import { showToast } from '../utils/ToastUtil'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { http } from '@kit.NetworkKit'

interface ImagePreviewSourceSize {
  width: number
  height: number
}

interface ImagePreviewFittedSize {
  width: number
  height: number
}

/**
 * 图片预览组件
 * 支持：全屏查看、单击关闭、长按保存、双指缩放、双击缩放、Swiper 多图滑动切换、下拉关闭
 *
 * 架构：使用 Swiper 原生处理水平滑动切换，手势绑定在 Swiper 上处理缩放/拖拽/点击。
 * 缩放和平移只作用于当前图片，避免整体 Swiper 变换导致多图切换和边界计算异常。
 * 不能在 bindContentCover 内使用（模态层会拦截连续手势），
 * 应作为条件渲染的全屏覆盖层直接嵌入页面 Stack 中。
 * 需在宿主页面的 onBackPress() 中拦截返回键。
 *
 * 手势架构（绑定在 Swiper 上，长按操作栏内按钮优先）：
 * .parallelGesture(Exclusive: PinchGesture | PanGesture | LongPressGesture | TapGesture)
 *   PinchGesture：双指缩放
 *   PanGesture：放大时全向拖动，未放大时仅处理垂直下拉关闭
 *   LongPressGesture：弹出临时保存操作栏
 *   TapGesture：单击关闭，双击缩放
 */

@ComponentV2
export struct ImagePreview {
  @Param images: Array<string> = []
  @Param currentIndex: number = 0
  @Param topSafeAreaVp: number = 0
  @Param bottomSafeAreaVp: number = 0
  @Param transitionId: string = ''
  @Param transitionIndex: number = -1
  @Event onClose: () => void = () => {}

  // 缩放状态
  @Local imageScale: number = 1
  @Local lastImageScale: number = 1

  // 位移状态
  @Local offsetX: number = 0
  @Local offsetY: number = 0
  @Local lastOffsetX: number = 0
  @Local lastOffsetY: number = 0

  // 当前显示图片索引
  @Local displayIndex: number = 0

  // 背景透明度（下拉退出时渐变）
  @Local backgroundOpacity: number = 1

  // 共享元素转场时，目标大图首帧需要隐藏，避免先按全屏布局闪一下
  @Local previewImageOpacity: number = 1

  // geometryTransition 只在打开/关闭瞬间启用，预览浏览期间解绑，避免 Swiper 切回初始图时重复匹配出残影
  @Local sharedTransitionActive: boolean = false

  // 正常预览内容与共享元素转场层分离：Swiper 不参与 geometryTransition
  @Local previewContentVisible: boolean = true
  @Local transitionLayerVisible: boolean = false

  // 下拉关闭时的缩放（"抽离"效果）
  @Local dragScale: number = 1

  // 是否正在执行关闭动画（防止重复触发）
  @Local isDismissing: boolean = false

  // 保存状态
  @Local isSaving: boolean = false

  // 长按后显示临时操作栏
  @Local showActionBar: boolean = false

  // Swiper 手势禁用状态：缩放/下拉时禁用翻页，避免手势冲突
  @Local disableSwiperSwipe: boolean = false

  // 预览容器尺寸，用于按 ImageFit.Contain 后的可视尺寸计算拖动边界
  @Local containerWidth: number = 0
  @Local containerHeight: number = 0

  // 拖动方向锁定
  private panDirection: string = 'none'
  private sourceImageSizes: ImagePreviewSourceSize[] = []
  private cachedRemoteImageUris: Map<string, string> = new Map()
  private cachedRemoteImagePaths: string[] = []
  private pendingRemoteImageDownloads: Map<string, Promise<string>> = new Map()
  private isPreviewDisposed: boolean = false
  private readonly overlayHorizontalMarginVp: number = 18
  private readonly overlayBottomMarginVp: number = 18
  private readonly overlayTopMarginVp: number = 10
  private readonly actionBarHeightVp: number = 48
  private readonly sharedTransitionReleaseDelayMs: number = 320
  private readonly sharedTransitionImageShowDelayMs: number = 90

  aboutToAppear(): void {
    this.isPreviewDisposed = false
    this.backgroundOpacity = 1
    this.previewImageOpacity = this.transitionId !== '' ? 0 : 1
    this.sharedTransitionActive = this.transitionId !== ''
    this.previewContentVisible = this.transitionId === ''
    this.transitionLayerVisible = this.transitionId !== ''
    this.displayIndex = this.normalizeImageIndex(this.currentIndex)
    this.prefetchRemoteImage(this.images[this.displayIndex])
    if (this.transitionId !== '') {
      setTimeout(() => {
        this.revealPreviewImageAfterOpen()
      }, this.sharedTransitionImageShowDelayMs)
      setTimeout(() => {
        this.finishSharedTransitionAfterOpen()
      }, this.sharedTransitionReleaseDelayMs)
    }
  }

  aboutToDisappear(): void {
    this.isPreviewDisposed = true
    this.cleanupCachedRemoteImages()
  }

  /**
   * 统一关闭入口：淡出遮罩后关闭。
   * 状态栏由宿主 ChatPage 统一管理，本组件不介入。
   */
  private dismiss(): void {
    if (this.isDismissing) return
    this.isDismissing = true
    this.hideSaveActionBar()
    if (this.canCloseWithSharedTransition()) {
      this.closeWithSharedTransition()
      return
    }
    this.getUIContext().animateTo({ duration: 200, curve: Curve.EaseOut }, () => {
      this.backgroundOpacity = 0
    })
    setTimeout(() => this.onClose(), 210)
  }

  private showImageToast(message: string | Resource, duration: number = 2000): void {
    showToast(this.getUIContext(), message, duration)
  }

  private getOverlayControlBorderColor(): string {
    return 'rgba(255, 255, 255, 0.10)'
  }

  private getOverlayControlShadowColor(): string {
    return 'rgba(0, 0, 0, 0.20)'
  }

  private normalizeImageIndex(index: number): number {
    if (this.images.length === 0) {
      return 0
    }
    if (index < 0) {
      return 0
    }
    if (index >= this.images.length) {
      return this.images.length - 1
    }
    return index
  }

  private getActiveImageScale(index: number): number {
    if (index !== this.displayIndex) {
      return 1
    }
    return this.imageScale * this.dragScale
  }

  private getActiveImageOffsetX(index: number): number {
    if (index !== this.displayIndex) {
      return 0
    }
    return this.offsetX
  }

  private getActiveImageOffsetY(index: number): number {
    if (index !== this.displayIndex) {
      return 0
    }
    return this.offsetY
  }

  private shouldUseSharedTransitionForIndex(index: number): boolean {
    return this.sharedTransitionActive && this.transitionId !== '' && index === this.displayIndex &&
      index === this.transitionIndex
  }

  private canCloseWithSharedTransition(): boolean {
    return this.transitionId !== '' && this.displayIndex === this.transitionIndex
  }

  private finishSharedTransitionAfterOpen(): void {
    if (this.isPreviewDisposed || this.isDismissing) {
      return
    }
    this.previewContentVisible = true
    this.sharedTransitionActive = false
    this.previewImageOpacity = 1
    setTimeout(() => {
      if (!this.isPreviewDisposed && !this.isDismissing) {
        this.transitionLayerVisible = false
      }
    }, 34)
  }

  private revealPreviewImageAfterOpen(): void {
    if (this.isPreviewDisposed || this.isDismissing) {
      return
    }
    this.getUIContext().animateTo({ duration: 140, curve: Curve.EaseOut }, () => {
      this.previewImageOpacity = 1
    })
  }

  private closeWithSharedTransition(): void {
    this.transitionLayerVisible = true
    this.previewContentVisible = false
    this.sharedTransitionActive = true
    this.previewImageOpacity = 1
    this.backgroundOpacity = 0
    this.disableSwiperSwipe = true
    setTimeout(() => {
      if (!this.isPreviewDisposed) {
        this.onClose()
      }
    }, 0)
  }

  private rememberSourceImageSize(index: number, width: number, height: number): void {
    if (index < 0 || Number.isNaN(width) || Number.isNaN(height) || width <= 0 || height <= 0) {
      return
    }
    this.sourceImageSizes[index] = { width: width, height: height }
  }

  private getFittedImageSize(index: number): ImagePreviewFittedSize {
    const fallbackWidth = this.containerWidth > 0 ? this.containerWidth : 1
    const fallbackHeight = this.containerHeight > 0 ? this.containerHeight : 1
    const sourceSize = this.sourceImageSizes[index]
    if (sourceSize === undefined || Number.isNaN(sourceSize.width) || Number.isNaN(sourceSize.height) ||
      sourceSize.width <= 0 || sourceSize.height <= 0 ||
      this.containerWidth <= 0 || this.containerHeight <= 0) {
      return { width: fallbackWidth, height: fallbackHeight }
    }

    const imageRatio = sourceSize.width / sourceSize.height
    const containerRatio = this.containerWidth / this.containerHeight
    if (imageRatio >= containerRatio) {
      return {
        width: this.containerWidth,
        height: this.containerWidth / imageRatio
      }
    }
    return {
      width: this.containerHeight * imageRatio,
      height: this.containerHeight
    }
  }

  private getMaxOffsetX(): number {
    const fittedSize = this.getFittedImageSize(this.displayIndex)
    return Math.max(0, (fittedSize.width * this.imageScale - this.containerWidth) / 2)
  }

  private getMaxOffsetY(): number {
    const fittedSize = this.getFittedImageSize(this.displayIndex)
    return Math.max(0, (fittedSize.height * this.imageScale - this.containerHeight) / 2)
  }

  private clampValue(value: number, min: number, max: number): number {
    if (value < min) {
      return min
    }
    if (value > max) {
      return max
    }
    return value
  }

  private clampImageOffset(): void {
    const maxOffsetX = this.getMaxOffsetX()
    const maxOffsetY = this.getMaxOffsetY()
    this.offsetX = this.clampValue(this.offsetX, -maxOffsetX, maxOffsetX)
    this.offsetY = this.clampValue(this.offsetY, -maxOffsetY, maxOffsetY)
    this.lastOffsetX = this.offsetX
    this.lastOffsetY = this.offsetY
  }

  private getDismissDistance(): number {
    if (this.containerHeight <= 0) {
      return 120
    }
    return this.clampValue(this.containerHeight * 0.18, 110, 180)
  }

  private areaLengthToNumber(value: Length): number {
    if (typeof value === 'number') {
      return value
    }
    if (typeof value !== 'string') {
      return 0
    }
    const numericValue = Number(value)
    if (Number.isNaN(numericValue)) {
      return 0
    }
    return numericValue
  }

  @Builder
  private PreviewActionBarBuilder() {
    Row() {
      Button({ type: ButtonType.Normal, stateEffect: false }) {
        Row({ space: 8 }) {
          if (this.isSaving) {
            LoadingProgress()
              .width(18)
              .height(18)
              .color('rgba(255, 255, 255, 0.84)')
          } else {
            SymbolGlyph($r('sys.symbol.square_and_arrow_down'))
              .fontSize(18)
              .fontColor(['rgba(255, 255, 255, 0.88)'])
          }

          Text($r('app.string.save'))
            .fontSize(14)
            .fontColor('rgba(255, 255, 255, 0.88)')
            .fontWeight(FontWeight.Medium)
        }
      }
      .height(38)
      .padding({ left: 14, right: 16 })
      .backgroundColor(Color.Transparent)
      .enabled(!this.isSaving)
      .onClick(() => {
        this.saveCurrentImage()
      })
    }
    .height(this.actionBarHeightVp)
    .padding({ left: 6, right: 6 })
    .backgroundColor('rgba(8, 12, 18, 0.58)')
    .borderRadius(24)
    .border({ width: 0.8, color: this.getOverlayControlBorderColor() })
    .shadow({ radius: 14, color: this.getOverlayControlShadowColor(), offsetX: 0, offsetY: 5 })
  }

  @Builder
  private PageIndicatorBuilder() {
    if (this.images.length > 1) {
      Text(`${this.displayIndex + 1}/${this.images.length}`)
        .fontSize(18)
        .fontColor('rgba(255, 255, 255, 0.86)')
        .fontWeight(FontWeight.Medium)
    }
  }

  @Builder
  private CloseButtonBuilder() {
    Button({ type: ButtonType.Circle, stateEffect: false }) {
      SymbolGlyph($r('sys.symbol.xmark'))
        .fontSize(34)
        .fontColor(['rgba(255, 255, 255, 0.82)'])
    }
    .width(52)
    .height(52)
    .backgroundColor(Color.Transparent)
    .onClick(() => {
      this.dismiss()
    })
  }

  @Builder
  private SavingInlineIndicatorBuilder() {
    if (this.isSaving) {
      LoadingProgress()
        .width(22)
        .height(22)
        .color('rgba(255, 255, 255, 0.84)')
        .position({ x: '50%', y: '100%' })
        .translate({ x: -11, y: -(this.overlayBottomMarginVp + this.bottomSafeAreaVp + 24) })
    }
  }

  @Builder
  private PreviewImageBuilder(image: string, index: number) {
    Image(image)
      .objectFit(ImageFit.Contain)
      .width('100%')
      .height('100%')
      .draggable(false)
      .scale({
        x: this.getActiveImageScale(index),
        y: this.getActiveImageScale(index)
      })
      .offset({
        x: this.getActiveImageOffsetX(index),
        y: this.getActiveImageOffsetY(index)
      })
      .onComplete((event) => {
        if (event?.loadingStatus) {
          this.rememberSourceImageSize(index, Number(event.contentWidth), Number(event.contentHeight))
        }
      })
  }

  @Builder
  private SharedTransitionImageBuilder() {
    if (this.transitionLayerVisible && this.shouldUseSharedTransitionForIndex(this.transitionIndex)) {
      Image(this.images[this.transitionIndex])
        .objectFit(ImageFit.Contain)
        .width('100%')
        .height('100%')
        .draggable(false)
        .opacity(this.previewImageOpacity)
        .geometryTransition(this.transitionId)
        .onComplete((event) => {
          if (event?.loadingStatus) {
            this.rememberSourceImageSize(this.transitionIndex, Number(event.contentWidth), Number(event.contentHeight))
          }
        })
    }
  }

  private showSaveActionBar(): void {
    this.showActionBar = true
  }

  private hideSaveActionBar(): void {
    this.showActionBar = false
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      // 黑色背景
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(Color.Black)
        .opacity(this.backgroundOpacity)

      if (this.transitionLayerVisible) {
        this.SharedTransitionImageBuilder()
      }

      if (this.previewContentVisible) {
        // Swiper 多图切换。Swiper 内图片不绑定 geometryTransition，只负责浏览交互。
        Swiper() {
          ForEach(this.images, (image: string, index: number) => {
            this.PreviewImageBuilder(image, index)
          }, (image: string, index: number): string => index.toString())
        }
        .index(this.displayIndex)
        .loop(false)
        .disableSwipe(this.disableSwiperSwipe || this.imageScale > 1)
        .indicator(false)
        .duration(300)
        .curve(Curve.EaseOut)
        .onChange((index: number) => {
          this.sharedTransitionActive = false
          this.previewImageOpacity = 1
          this.displayIndex = index
          this.resetGestureState()
          this.prefetchRemoteImage(this.images[index])
        })
        .width('100%')
        .height('100%')
        // 图片预览组合手势绑定在 Swiper 上，避免根容器 Pan 与 Swiper 内建翻页互相抢占。
        .parallelGesture(
          GestureGroup(GestureMode.Exclusive,
            PinchGesture({ fingers: 2 })
              .onActionStart(() => {
                this.hideSaveActionBar()
                this.lastImageScale = this.imageScale
                this.disableSwiperSwipe = true
              })
              .onActionUpdate((event: GestureEvent) => {
                let newScale = this.lastImageScale * event.scale
                if (newScale < 1) {
                  newScale = 1
                } else if (newScale > 4) {
                  newScale = 4
                }
                if (this.imageScale > 1) {
                  this.offsetX = this.offsetX / (this.imageScale - 1) * (newScale - 1) || 0
                  this.offsetY = this.offsetY / (this.imageScale - 1) * (newScale - 1) || 0
                } else {
                  this.offsetX = 0
                  this.offsetY = 0
                }
                this.imageScale = newScale
                this.dragScale = 1
                this.backgroundOpacity = 1
                this.clampImageOffset()
              })
              .onActionEnd(() => {
                if (this.imageScale <= 1) {
                  this.resetGestureState()
                } else {
                  this.clampImageOffset()
                  this.disableSwiperSwipe = false
                }
                this.lastImageScale = this.imageScale
              })
              .onActionCancel(() => {
                if (this.imageScale <= 1) {
                  this.resetGestureState()
                } else {
                  this.clampImageOffset()
                  this.disableSwiperSwipe = false
                }
              }),
            // PanGesture 距离阈值保持很低，下拉从第一段移动就驱动图片位置和背景透明度。
            PanGesture({ fingers: 1, distance: 1 })
              .onActionStart(() => {
                this.hideSaveActionBar()
                this.lastOffsetX = this.offsetX
                this.lastOffsetY = this.offsetY
                this.panDirection = 'none'
              })
              .onActionUpdate((event: GestureEvent) => {
                if (this.imageScale > 1) {
                  const nextOffsetX = this.lastOffsetX + event.offsetX
                  const nextOffsetY = this.lastOffsetY + event.offsetY
                  const maxOffsetX = this.getMaxOffsetX()
                  const maxOffsetY = this.getMaxOffsetY()
                  this.offsetX = this.clampValue(nextOffsetX, -maxOffsetX, maxOffsetX)
                  this.offsetY = this.clampValue(nextOffsetY, -maxOffsetY, maxOffsetY)
                  return
                }

                if (this.panDirection === 'none') {
                  if (Math.abs(event.offsetX) > 4 || Math.abs(event.offsetY) > 4) {
                    if (Math.abs(event.offsetX) > Math.abs(event.offsetY)) {
                      this.panDirection = 'horizontal'
                      this.disableSwiperSwipe = false
                    } else {
                      this.panDirection = 'vertical'
                      this.disableSwiperSwipe = true
                    }
                  }
                }

                if (this.panDirection !== 'vertical') {
                  return
                }

                const rawY = event.offsetY
                const dismissDistance = this.getDismissDistance()
                if (rawY > 0) {
                  this.offsetY = rawY
                  const dragRatio = Math.min(rawY / dismissDistance, 1)
                  this.dragScale = 1 - dragRatio * 0.18
                  this.backgroundOpacity = Math.max(0.05, 1 - dragRatio * 0.92)
                } else {
                  this.offsetY = rawY * 0.25
                  this.dragScale = 1
                  this.backgroundOpacity = 1
                }
              })
              .onActionEnd(() => {
                if (this.imageScale > 1) {
                  this.clampImageOffset()
                  return
                }

                if (this.panDirection === 'vertical' && this.offsetY > this.getDismissDistance()) {
                  this.isDismissing = true
                  this.hideSaveActionBar()
                  this.disableSwiperSwipe = true
                  if (this.canCloseWithSharedTransition()) {
                    this.closeWithSharedTransition()
                    return
                  }
                  this.getUIContext().animateTo({ duration: 220, curve: Curve.FastOutLinearIn }, () => {
                    this.offsetY = this.containerHeight > 0 ? this.containerHeight : 720
                    this.dragScale = 0.78
                    this.backgroundOpacity = 0
                  })
                  setTimeout(() => this.onClose(), 230)
                  return
                }

                this.getUIContext().animateTo({ duration: 240, curve: Curve.FastOutSlowIn }, () => {
                  this.offsetX = 0
                  this.offsetY = 0
                  this.dragScale = 1
                  this.backgroundOpacity = 1
                  this.disableSwiperSwipe = false
                })
              })
              .onActionCancel(() => {
                if (this.imageScale > 1) {
                  this.clampImageOffset()
                  return
                }
                this.getUIContext().animateTo({ duration: 180, curve: Curve.EaseOut }, () => {
                  this.offsetX = 0
                  this.offsetY = 0
                  this.dragScale = 1
                  this.backgroundOpacity = 1
                  this.disableSwiperSwipe = false
                })
              }),
            LongPressGesture({ duration: 500 })
              .onAction(() => {
                if (!this.isDismissing) {
                  this.showSaveActionBar()
                }
              }),
            GestureGroup(GestureMode.Exclusive,
              TapGesture({ count: 2 })
                .onAction(() => {
                  this.hideSaveActionBar()
                  this.getUIContext().animateTo({ duration: 250, curve: Curve.EaseOut }, () => {
                    if (this.imageScale > 1) {
                      this.imageScale = 1
                      this.lastImageScale = 1
                      this.offsetX = 0
                      this.offsetY = 0
                      this.lastOffsetX = 0
                      this.lastOffsetY = 0
                      this.disableSwiperSwipe = false
                    } else {
                      this.imageScale = 2
                      this.lastImageScale = 2
                      this.disableSwiperSwipe = true
                    }
                    this.dragScale = 1
                    this.backgroundOpacity = 1
                    this.clampImageOffset()
                  })
                }),
              TapGesture({ count: 1 })
                .onAction(() => {
                  this.dismiss()
                })
            )
          )
        )
      }

      if (this.previewContentVisible && this.showActionBar) {
        Row() {
          this.PreviewActionBarBuilder()
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .position({ x: 0, y: '100%' })
        .translate({ y: -(this.actionBarHeightVp + this.overlayBottomMarginVp + this.bottomSafeAreaVp) })
        .transition(TransitionEffect.OPACITY.animation({ duration: 160, curve: Curve.EaseOut }))
      }

      if (this.previewContentVisible && this.isSaving && !this.showActionBar) {
        this.SavingInlineIndicatorBuilder()
      }

      // 顶部参考系统相册预览：中间页码，左侧裸关闭图标
      if (this.previewContentVisible) {
        Row() {
          this.PageIndicatorBuilder()
        }
        .width('100%')
        .height(52)
        .justifyContent(FlexAlign.Center)
        .padding({
          left: this.overlayHorizontalMarginVp,
          right: this.overlayHorizontalMarginVp,
          top: this.topSafeAreaVp + this.overlayTopMarginVp
        })
        .position({ x: 0, y: 0 })
        .hitTestBehavior(HitTestMode.None)

        Row() {
          this.CloseButtonBuilder()
        }
        .width('100%')
        .padding({
          left: this.overlayHorizontalMarginVp,
          right: this.overlayHorizontalMarginVp,
          top: this.topSafeAreaVp + this.overlayTopMarginVp
        })
        .position({ x: 0, y: 0 })
      }
    }
    .width('100%')
    .height('100%')
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    .onAreaChange((_oldArea: Area, newArea: Area) => {
      this.containerWidth = this.areaLengthToNumber(newArea.width)
      this.containerHeight = this.areaLengthToNumber(newArea.height)
      if (this.imageScale > 1) {
        this.clampImageOffset()
      }
    })
  }

  private async saveCurrentImage(): Promise<void> {
    if (this.isSaving) {
      return
    }

    const imageUri = this.images[this.displayIndex]
    if (!imageUri) {
      this.showImageToast($r('app.string.image_not_found'))
      return
    }

    this.isSaving = true
    try {
      if (imageUri.startsWith('data:')) {
        await this.saveFromBase64(imageUri)
      } else if (imageUri.startsWith('http://') || imageUri.startsWith('https://')) {
        await this.saveFromRemoteUri(imageUri)
      } else {
        await this.saveFromFileUri(imageUri)
      }
      this.showImageToast($r('app.string.image_saved_to_album'))
      this.hideSaveActionBar()
    } catch (err) {
      const errorMessage = err instanceof Error ? err.message : String(err)
      hilog.error(0x0000, 'ImagePreview', 'Save image failed: %{public}s', errorMessage)
      this.showImageToast($r('app.string.image_save_failed'))
    } finally {
      this.isSaving = false
    }
  }

  private async saveFromFileUri(imageUri: string): Promise<void> {
    const hostContext = this.getUIContext().getHostContext()
    if (!hostContext) {
      throw new Error('UI context is unavailable')
    }
    const context = hostContext as common.UIAbilityContext
    let srcFile: fileIo.File | null = null
    let desFile: fileIo.File | null = null
    try {
      const srcPath = this.resolveLocalFilePath(imageUri)
      if (srcPath === '') {
        throw new Error('Image path is empty')
      }
      const srcUri = fileUri.getUriFromPath(srcPath)

      const ext = this.getExtensionFromUri(srcPath)
      const config: photoAccessHelper.PhotoCreationConfig = {
        title: `IMG_${Date.now()}`,
        fileNameExtension: ext,
        photoType: photoAccessHelper.PhotoType.IMAGE,
        subtype: photoAccessHelper.PhotoSubtype.DEFAULT
      }

      const phAccessHelper = photoAccessHelper.getPhotoAccessHelper(context)
      const desFileUris = await phAccessHelper.showAssetsCreationDialog([srcUri], [config])
      if (desFileUris.length === 0) {
        throw new Error('No target file uri selected')
      }

      srcFile = fileIo.openSync(srcPath, fileIo.OpenMode.READ_ONLY)
      desFile = fileIo.openSync(desFileUris[0], fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE)
      await fileIo.copyFile(srcFile.fd, desFile.fd)
    } catch (error) {
      throw new Error(`Save from file uri failed: ${this.formatSaveError(error)}`)
    } finally {
      this.closeFileQuietly(srcFile)
      this.closeFileQuietly(desFile)
    }
  }

  private async saveFromRemoteUri(imageUri: string): Promise<void> {
    try {
      const localUri = await this.cacheRemoteImage(imageUri)
      await this.saveFromFileUri(localUri)
    } catch (error) {
      throw new Error(`Save from remote uri failed: ${this.formatSaveError(error)}`)
    }
  }

  private prefetchRemoteImage(imageUri: string): void {
    if (!this.isRemoteImageUri(imageUri)) {
      return
    }
    this.cacheRemoteImage(imageUri).catch((error: Object): void => {
      hilog.error(0x0000, 'ImagePreview', 'Prefetch remote image failed: %{public}s', this.formatSaveError(error))
    })
  }

  private isRemoteImageUri(imageUri: string): boolean {
    return imageUri.startsWith('http://') || imageUri.startsWith('https://')
  }

  private async cacheRemoteImage(imageUri: string): Promise<string> {
    const cachedUri = this.cachedRemoteImageUris.get(imageUri)
    if (cachedUri !== undefined && cachedUri !== '') {
      return cachedUri
    }

    const pending = this.pendingRemoteImageDownloads.get(imageUri)
    if (pending !== undefined) {
      return await pending
    }

    const promise = this.downloadRemoteImageToTempUri(imageUri)
    this.pendingRemoteImageDownloads.set(imageUri, promise)
    try {
      const localUri = await promise
      this.cachedRemoteImageUris.set(imageUri, localUri)
      return localUri
    } finally {
      this.pendingRemoteImageDownloads.delete(imageUri)
    }
  }

  private async downloadRemoteImageToTempUri(imageUri: string): Promise<string> {
    const hostContext = this.getUIContext().getHostContext()
    if (!hostContext) {
      throw new Error('UI context is unavailable')
    }
    const context = hostContext as common.UIAbilityContext
    const httpRequest = http.createHttp()
    let tempFilePath = ''

    try {
      const response = await httpRequest.request(imageUri, {
        method: http.RequestMethod.GET,
        connectTimeout: 15000,
        readTimeout: 60000,
        expectDataType: http.HttpDataType.ARRAY_BUFFER
      })
      if (response.responseCode !== 200) {
        throw new Error(`HTTP ${response.responseCode}`)
      }

      const imageBuffer = response.result as ArrayBuffer
      if (imageBuffer.byteLength <= 0) {
        throw new Error('Empty image data')
      }

      const contentType = response.header?.['content-type'] as string | undefined
      const ext = this.getExtensionForRemoteImage(imageUri, contentType)
      tempFilePath = `${context.cacheDir}/temp_save_${Date.now()}.${ext}`
      const tempFile = fileIo.openSync(tempFilePath, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY)
      fileIo.writeSync(tempFile.fd, imageBuffer)
      fileIo.closeSync(tempFile)

      if (this.isPreviewDisposed) {
        fileIo.unlinkSync(tempFilePath)
        tempFilePath = ''
        throw new Error('Image preview has been closed')
      }

      this.cachedRemoteImagePaths.push(tempFilePath)
      const tempFileUriStr = fileUri.getUriFromPath(tempFilePath)
      return tempFileUriStr
    } catch (error) {
      if (tempFilePath !== '') {
        try {
          fileIo.unlinkSync(tempFilePath)
        } catch (cleanupError) {
          hilog.error(0x0000, 'ImagePreview', 'Cleanup failed remote temp file failed: %{public}s',
            JSON.stringify(cleanupError))
        }
      }
      throw new Error(`Download remote image failed: ${this.formatSaveError(error)}`)
    } finally {
      httpRequest.destroy()
    }
  }

  private cleanupCachedRemoteImages(): void {
    for (let i = 0; i < this.cachedRemoteImagePaths.length; i++) {
      const filePath = this.cachedRemoteImagePaths[i]
      if (filePath !== '') {
        try {
          fileIo.unlinkSync(filePath)
        } catch (cleanupError) {
          hilog.error(0x0000, 'ImagePreview', 'Cleanup remote temp file failed: %{public}s', JSON.stringify(cleanupError))
        }
      }
    }
    this.cachedRemoteImageUris.clear()
    this.cachedRemoteImagePaths = []
  }

  private async saveFromBase64(dataUri: string): Promise<void> {
    const hostContext = this.getUIContext().getHostContext()
    if (!hostContext) {
      throw new Error('UI context is unavailable')
    }
    const context = hostContext as common.UIAbilityContext

    // 解析 data URI: data:image/png;base64,xxxxx
    const commaIndex = dataUri.indexOf(',')
    const base64Data = dataUri.substring(commaIndex + 1)
    const mimeSection = dataUri.substring(0, commaIndex)

    let ext = 'png'
    if (mimeSection.includes('jpeg') || mimeSection.includes('jpg')) {
      ext = 'jpg'
    } else if (mimeSection.includes('gif')) {
      ext = 'gif'
    } else if (mimeSection.includes('webp')) {
      ext = 'webp'
    }

    // 解码 base64 并写入临时文件
    const decodedBuffer = buffer.from(base64Data, 'base64')
    const tempFileName = `temp_save_${Date.now()}.${ext}`
    const tempFilePath = `${context.cacheDir}/${tempFileName}`
    try {
      const tempFile = fileIo.openSync(tempFilePath, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY)
      fileIo.writeSync(tempFile.fd, decodedBuffer.buffer)
      fileIo.closeSync(tempFile)

      const tempFileUriStr = fileUri.getUriFromPath(tempFilePath)
      await this.saveFromFileUri(tempFileUriStr)
    } catch (error) {
      throw new Error(`Save from base64 failed: ${this.formatSaveError(error)}`)
    } finally {
      // 清理临时文件
      try {
        fileIo.unlinkSync(tempFilePath)
      } catch (cleanupError) {
        hilog.error(0x0000, 'ImagePreview', 'Cleanup temp file failed: %{public}s', JSON.stringify(cleanupError))
      }
    }
  }

  private getExtensionFromUri(uri: string): string {
    const queryIndex = uri.indexOf('?')
    const fragmentIndex = uri.indexOf('#')
    let cleanUri = uri
    if (queryIndex >= 0) {
      cleanUri = cleanUri.substring(0, queryIndex)
    }
    if (fragmentIndex >= 0) {
      cleanUri = cleanUri.substring(0, fragmentIndex)
    }
    const dotIndex = cleanUri.lastIndexOf('.')
    if (dotIndex >= 0) {
      const ext = cleanUri.substring(dotIndex + 1).toLowerCase()
      if (ext === 'jpeg') {
        return 'jpg'
      }
      return ext
    }
    return 'jpg'
  }

  private resolveLocalFilePath(uri: string): string {
    let cleanUri = uri.trim()
    const queryIndex = cleanUri.indexOf('?')
    if (queryIndex >= 0) {
      cleanUri = cleanUri.substring(0, queryIndex)
    }
    const fragmentIndex = cleanUri.indexOf('#')
    if (fragmentIndex >= 0) {
      cleanUri = cleanUri.substring(0, fragmentIndex)
    }
    if (!cleanUri.toLowerCase().startsWith('file://')) {
      return cleanUri
    }
    try {
      return new fileUri.FileUri(cleanUri).path
    } catch (_error) {
      return cleanUri.substring(7)
    }
  }

  private getExtensionForRemoteImage(uri: string, contentType?: string): string {
    if (contentType !== undefined && contentType !== '') {
      const mimeType = contentType.split(';')[0].trim().toLowerCase()
      if (mimeType === 'image/jpeg' || mimeType === 'image/jpg') {
        return 'jpg'
      }
      if (mimeType === 'image/png') {
        return 'png'
      }
      if (mimeType === 'image/gif') {
        return 'gif'
      }
      if (mimeType === 'image/webp') {
        return 'webp'
      }
      if (mimeType === 'image/bmp') {
        return 'bmp'
      }
    }
    return this.getExtensionFromUri(uri)
  }

  private formatSaveError(error: Object): string {
    if (error instanceof Error) {
      return error.message
    }
    return JSON.stringify(error)
  }

  private closeFileQuietly(file: fileIo.File | null): void {
    if (file === null) {
      return
    }
    try {
      fileIo.closeSync(file)
    } catch (error) {
      hilog.error(0x0000, 'ImagePreview', 'Close image file failed: %{public}s', this.formatSaveError(error))
    }
  }

  private resetGestureState(): void {
    this.imageScale = 1
    this.lastImageScale = 1
    this.offsetX = 0
    this.offsetY = 0
    this.lastOffsetX = 0
    this.lastOffsetY = 0
    this.backgroundOpacity = 1
    this.dragScale = 1
    this.panDirection = 'none'
    this.disableSwiperSwipe = false
    this.showActionBar = false
  }
}
