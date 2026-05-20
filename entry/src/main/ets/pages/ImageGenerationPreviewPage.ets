import { common } from '@kit.AbilityKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { getAppUiState } from '../state/AppUiState'
import { saveFileImageToAlbum } from '../utils/RawfileImageSaveUtil'
import { showToast } from '../utils/ToastUtil'

export class ImageGenerationPreviewRouteParams {
  images: string[] = []
  selectedIndex: number = 0
  transitionIds: string[] = []
  aspectRatios: number[] = []
  topSafeAreaVp: number = 0
  bottomSafeAreaVp: number = 0
  onIndexChange: (index: number) => void = (_index: number): void => {}
  onBackToSource: () => void = (): void => {}
  onPreviewClosed: () => void = (): void => {}
}

let imageGenerationPreviewPathStack: NavPathStack | null = null
let imageGenerationPreviewBackHandler: (() => boolean) | null = null

@ComponentV2
struct ImageGenerationPreviewPage {
  @Param routeParam: ImageGenerationPreviewRouteParams = new ImageGenerationPreviewRouteParams()

  @Local images: string[] = []
  @Local displayIndex: number = 0
  @Local transitionIds: string[] = []
  @Local aspectRatios: number[] = []
  @Local topSafeAreaVp: number = 0
  @Local bottomSafeAreaVp: number = 0
  @Local imageScale: number = 1
  @Local lastImageScale: number = 1
  @Local offsetX: number = 0
  @Local offsetY: number = 0
  @Local lastOffsetX: number = 0
  @Local lastOffsetY: number = 0
  @Local dragScale: number = 1
  @Local backgroundOpacity: number = 1
  @Local containerWidth: number = 0
  @Local containerHeight: number = 0
  @Local disableSwiperSwipe: boolean = false
  @Local showActionBar: boolean = false
  @Local isSaving: boolean = false
  @Local isDismissing: boolean = false
  @Local isReturningToSource: boolean = false
  @Local returnFrameLeft: number = 0
  @Local returnFrameTop: number = 0
  @Local returnFrameScale: number = 1

  private onIndexChange: (index: number) => void = (_index: number): void => {}
  private onBackToSource: () => void = (): void => {}
  private onPreviewClosed: () => void = (): void => {}
  private readonly actionBarHeightVp: number = 48
  private readonly overlayHorizontalMarginVp: number = 18
  private readonly overlayTopMarginVp: number = 10
  private readonly overlayBottomMarginVp: number = 18

  aboutToAppear(): void {
    this.applyRouteParam()
    imageGenerationPreviewBackHandler = (): boolean => {
      this.closeToSource()
      return true
    }
  }

  aboutToDisappear(): void {
    if (imageGenerationPreviewBackHandler !== null) {
      imageGenerationPreviewBackHandler = null
    }
  }

  private applyRouteParam(): void {
    this.images = this.routeParam.images
    this.transitionIds = this.routeParam.transitionIds
    this.aspectRatios = this.routeParam.aspectRatios
    this.displayIndex = this.normalizeIndex(this.routeParam.selectedIndex)
    this.topSafeAreaVp = this.routeParam.topSafeAreaVp
    this.bottomSafeAreaVp = this.routeParam.bottomSafeAreaVp
    this.onIndexChange = this.routeParam.onIndexChange
    this.onBackToSource = this.routeParam.onBackToSource
    this.onPreviewClosed = this.routeParam.onPreviewClosed
    this.onIndexChange(this.displayIndex)
  }

  private normalizeIndex(index: number): number {
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

  private getViewportWidth(): number {
    if (this.containerWidth > 0) {
      return this.containerWidth
    }
    return Math.max(getAppUiState().windowWidthVp, 1)
  }

  private getViewportHeight(): number {
    if (this.containerHeight > 0) {
      return this.containerHeight
    }
    return Math.max(getAppUiState().windowHeightVp, 1)
  }

  private getImageRatio(index: number): number {
    if (index >= 0 && index < this.aspectRatios.length && this.aspectRatios[index] > 0) {
      return this.aspectRatios[index]
    }
    return 1
  }

  private getDisplayWidth(index: number): number {
    const viewportWidth = this.getViewportWidth()
    const viewportHeight = this.getViewportHeight()
    const imageRatio = this.getImageRatio(index)
    const viewportRatio = viewportWidth / viewportHeight
    if (imageRatio >= viewportRatio) {
      return viewportWidth
    }
    return viewportHeight * imageRatio
  }

  private getDisplayHeight(index: number): number {
    const viewportWidth = this.getViewportWidth()
    const viewportHeight = this.getViewportHeight()
    const imageRatio = this.getImageRatio(index)
    const viewportRatio = viewportWidth / viewportHeight
    if (imageRatio >= viewportRatio) {
      return viewportWidth / imageRatio
    }
    return viewportHeight
  }

  private getBaseFrameLeft(index: number): number {
    return (this.getViewportWidth() - this.getDisplayWidth(index)) / 2
  }

  private getBaseFrameTop(index: number): number {
    return (this.getViewportHeight() - this.getDisplayHeight(index)) / 2
  }

  private getImageFrameWidth(index: number): number {
    const frameScale = this.isReturningToSource && index === this.displayIndex ? this.returnFrameScale : 1
    return this.getDisplayWidth(index) * frameScale
  }

  private getImageFrameHeight(index: number): number {
    const frameScale = this.isReturningToSource && index === this.displayIndex ? this.returnFrameScale : 1
    return this.getDisplayHeight(index) * frameScale
  }

  private getImageFrameLeft(index: number): number {
    if (this.isReturningToSource && index === this.displayIndex) {
      return this.returnFrameLeft
    }
    return this.getBaseFrameLeft(index)
  }

  private getImageFrameTop(index: number): number {
    if (this.isReturningToSource && index === this.displayIndex) {
      return this.returnFrameTop
    }
    return this.getBaseFrameTop(index)
  }

  private getActiveScale(index: number): number {
    if (index !== this.displayIndex || this.isReturningToSource) {
      return 1
    }
    return this.imageScale * this.dragScale
  }

  private getActiveOffsetX(index: number): number {
    if (index !== this.displayIndex || this.isReturningToSource) {
      return 0
    }
    return this.offsetX
  }

  private getActiveOffsetY(index: number): number {
    if (index !== this.displayIndex || this.isReturningToSource) {
      return 0
    }
    return this.offsetY
  }

  private getActiveTransitionId(index: number): string {
    if (index === this.displayIndex && index >= 0 && index < this.transitionIds.length) {
      return this.transitionIds[index]
    }
    return ''
  }

  private getMaxOffsetX(): number {
    return Math.max(0, (this.getDisplayWidth(this.displayIndex) * this.imageScale - this.getViewportWidth()) / 2)
  }

  private getMaxOffsetY(): number {
    return Math.max(0, (this.getDisplayHeight(this.displayIndex) * this.imageScale - this.getViewportHeight()) / 2)
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
    return this.clampValue(this.getViewportHeight() * 0.18, 110, 190)
  }

  private getPanDirection(): PanDirection {
    return this.imageScale > 1 ? PanDirection.All : PanDirection.Vertical
  }

  private areaLengthToNumber(value: Length): number {
    if (typeof value === 'number') {
      return value
    }
    if (typeof value !== 'string') {
      return 0
    }
    const numberValue = Number(value)
    return Number.isNaN(numberValue) ? 0 : numberValue
  }

  private resetGestureState(): void {
    this.imageScale = 1
    this.lastImageScale = 1
    this.offsetX = 0
    this.offsetY = 0
    this.lastOffsetX = 0
    this.lastOffsetY = 0
    this.dragScale = 1
    this.backgroundOpacity = 1
    this.disableSwiperSwipe = false
    this.showActionBar = false
    this.isReturningToSource = false
    this.returnFrameScale = 1
  }

  private prepareReturnFrame(): void {
    const displayWidth = this.getDisplayWidth(this.displayIndex)
    const displayHeight = this.getDisplayHeight(this.displayIndex)
    const totalScale = this.imageScale * this.dragScale
    const baseLeft = this.getBaseFrameLeft(this.displayIndex)
    const baseTop = this.getBaseFrameTop(this.displayIndex)
    this.returnFrameScale = totalScale
    this.returnFrameLeft = baseLeft + this.offsetX - displayWidth * (totalScale - 1) / 2
    this.returnFrameTop = baseTop + this.offsetY - displayHeight * (totalScale - 1) / 2
    this.offsetX = 0
    this.offsetY = 0
    this.imageScale = 1
    this.dragScale = 1
    this.isReturningToSource = true
  }

  private closeToSource(): void {
    if (this.isDismissing || this.images.length === 0) {
      return
    }
    this.isDismissing = true
    this.showActionBar = false
    this.disableSwiperSwipe = true
    this.prepareReturnFrame()
    this.getUIContext().animateTo({
      duration: 260,
      curve: Curve.EaseIn,
      onFinish: () => {
        this.onPreviewClosed()
      }
    }, () => {
      this.backgroundOpacity = 0
      this.onBackToSource()
      if (imageGenerationPreviewPathStack !== null) {
        imageGenerationPreviewPathStack.pop(false)
      }
    })
  }

  private async saveCurrentImage(): Promise<void> {
    if (this.isSaving) {
      return
    }
    const imageUri = this.images[this.displayIndex]
    if (imageUri === undefined || imageUri === '') {
      showToast(this.getUIContext(), $r('app.string.image_not_found'))
      return
    }
    const hostContext = this.getUIContext().getHostContext()
    if (hostContext === undefined || hostContext === null) {
      showToast(this.getUIContext(), $r('app.string.image_save_failed'))
      return
    }

    this.isSaving = true
    try {
      await saveFileImageToAlbum(hostContext as common.UIAbilityContext, imageUri, 'IMG')
      showToast(this.getUIContext(), $r('app.string.image_saved_to_album'))
      this.showActionBar = false
    } catch (error) {
      hilog.error(0x0000, 'ImageGenerationPreview', 'Save image failed: %{public}s', JSON.stringify(error))
      showToast(this.getUIContext(), $r('app.string.image_save_failed'))
    } finally {
      this.isSaving = false
    }
  }

  @Builder
  private PreviewImageBuilder(image: string, index: number) {
    Image(image)
      .objectFit(ImageFit.Contain)
      .width(this.getImageFrameWidth(index))
      .height(this.getImageFrameHeight(index))
      .position({ x: this.getImageFrameLeft(index), y: this.getImageFrameTop(index) })
      .scale({ x: this.getActiveScale(index), y: this.getActiveScale(index) })
      .offset({ x: this.getActiveOffsetX(index), y: this.getActiveOffsetY(index) })
      .draggable(false)
      .geometryTransition(this.getActiveTransitionId(index))
      .transition(TransitionEffect.OPACITY)
  }

  @Builder
  private ActionBarBuilder() {
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
            .fontWeight(FontWeight.Medium)
            .fontColor('rgba(255, 255, 255, 0.88)')
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
    .backgroundColor('rgba(8, 12, 18, 0.62)')
    .borderRadius(24)
  }

  @Builder
  private TopOverlayBuilder() {
    Row() {
      if (this.images.length > 1) {
        Text(`${this.displayIndex + 1}/${this.images.length}`)
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor('rgba(255, 255, 255, 0.86)')
      }
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
      Button({ type: ButtonType.Circle, stateEffect: false }) {
        SymbolGlyph($r('sys.symbol.xmark'))
          .fontSize(34)
          .fontColor(['rgba(255, 255, 255, 0.82)'])
      }
      .width(52)
      .height(52)
      .backgroundColor(Color.Transparent)
      .onClick(() => {
        this.closeToSource()
      })
    }
    .width('100%')
    .padding({
      left: this.overlayHorizontalMarginVp,
      right: this.overlayHorizontalMarginVp,
      top: this.topSafeAreaVp + this.overlayTopMarginVp
    })
    .position({ x: 0, y: 0 })
  }

  build() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(Color.Black)
        .opacity(this.backgroundOpacity)

      Swiper() {
        ForEach(this.images, (image: string, index: number): void => {
          Stack() {
            this.PreviewImageBuilder(image, index)
          }
          .width('100%')
          .height('100%')
        }, (_image: string, index: number): string => index.toString())
      }
      .width('100%')
      .height('100%')
      .clip(false)
      .index(this.displayIndex)
      .loop(false)
      .indicator(false)
      .duration(300)
      .curve(Curve.EaseOut)
      .disableSwipe(this.disableSwiperSwipe || this.imageScale > 1 || this.isDismissing)
      .onAnimationStart((_index: number, targetIndex: number) => {
        this.onIndexChange(targetIndex)
      })
      .onChange((index: number) => {
        this.displayIndex = index
        this.resetGestureState()
        this.onIndexChange(index)
      })
      .parallelGesture(
        GestureGroup(GestureMode.Exclusive,
          PinchGesture({ fingers: 2 })
            .onActionStart(() => {
              this.showActionBar = false
              this.lastImageScale = this.imageScale
              this.disableSwiperSwipe = true
            })
            .onActionUpdate((event: GestureEvent) => {
              this.imageScale = this.clampValue(this.lastImageScale * event.scale, 1, 4)
              this.dragScale = 1
              this.backgroundOpacity = 1
              this.clampImageOffset()
            })
            .onActionEnd(() => {
              if (this.imageScale <= 1) {
                this.resetGestureState()
              } else {
                this.clampImageOffset()
                this.disableSwiperSwipe = true
              }
              this.lastImageScale = this.imageScale
            }),
          PanGesture({ fingers: 1, distance: 1, direction: this.getPanDirection() })
            .onActionStart(() => {
              this.showActionBar = false
              this.lastOffsetX = this.offsetX
              this.lastOffsetY = this.offsetY
              this.disableSwiperSwipe = this.imageScale <= 1
            })
            .onActionUpdate((event: GestureEvent) => {
              if (this.imageScale > 1) {
                this.offsetX = this.lastOffsetX + event.offsetX
                this.offsetY = this.lastOffsetY + event.offsetY
                this.clampImageOffset()
                return
              }

              if (event.offsetY <= 0) {
                this.offsetY = event.offsetY * 0.22
                this.dragScale = 1
                this.backgroundOpacity = 1
                return
              }

              const dismissDistance = this.getDismissDistance()
              const dragRatio = Math.min(event.offsetY / dismissDistance, 1)
              this.offsetY = event.offsetY
              this.dragScale = 1 - dragRatio * 0.18
              this.backgroundOpacity = Math.max(0.08, 1 - dragRatio * 0.92)
            })
            .onActionEnd(() => {
              if (this.imageScale > 1) {
                this.clampImageOffset()
                return
              }

              if (this.offsetY > this.getDismissDistance()) {
                this.closeToSource()
                return
              }

              this.getUIContext().animateTo({ duration: 220, curve: Curve.FastOutSlowIn }, () => {
                this.offsetX = 0
                this.offsetY = 0
                this.dragScale = 1
                this.backgroundOpacity = 1
                this.disableSwiperSwipe = false
              })
            })
            .onActionCancel(() => {
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
                this.showActionBar = true
              }
            }),
          GestureGroup(GestureMode.Exclusive,
            TapGesture({ count: 2 })
              .onAction(() => {
                this.showActionBar = false
                this.getUIContext().animateTo({ duration: 240, curve: Curve.EaseOut }, () => {
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
                this.closeToSource()
              })
          )
        )
      )

      if (this.showActionBar) {
        Row() {
          this.ActionBarBuilder()
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .position({ x: 0, y: '100%' })
        .translate({ y: -(this.actionBarHeightVp + this.overlayBottomMarginVp + this.bottomSafeAreaVp) })
        .transition(TransitionEffect.OPACITY.animation({ duration: 160, curve: Curve.EaseOut }))
      }

      if (!this.isDismissing) {
        this.TopOverlayBuilder()
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
}

@Builder
export function ImageGenerationPreviewPageBuilder(name: string, param: Object) {
  NavDestination() {
    ImageGenerationPreviewPage({ routeParam: param as ImageGenerationPreviewRouteParams })
  }
  .width('100%')
  .height('100%')
  .mode(NavDestinationMode.DIALOG)
  .expandSafeArea([SafeAreaType.SYSTEM])
  .hideTitleBar(true)
  .onReady((context: NavDestinationContext) => {
    imageGenerationPreviewPathStack = context.pathStack
  })
  .onBackPressed((): boolean => {
    if (imageGenerationPreviewBackHandler !== null) {
      return imageGenerationPreviewBackHandler()
    }
    return true
  })
  .transition(TransitionEffect.opacity(0.99))
}
