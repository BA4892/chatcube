interface ImageCompleteEvent {
  width: number
  height: number
  componentWidth: number
  componentHeight: number
  loadingStatus: number
  contentWidth: number
  contentHeight: number
  contentOffsetX: number
  contentOffsetY: number
}

@ComponentV2
export struct AdaptiveImageThumbnail {
  @Param src: string = ''
  @Param previewId: string = ''
  @Param maxWidth: number = 180
  @Param maxHeight: number = 120
  @Param radius: number = 8
  @Param fallbackAspectRatio: number = 1
  @Param fillWidth: boolean = false
  @Param clickable: boolean = true
  @Event onPreview: () => void = () => {}

  @Local private sourceWidth: number = 0
  @Local private sourceHeight: number = 0
  @Local private hasImageLoadError: boolean = false

  @Monitor('src')
  onSourceChanged(): void {
    this.sourceWidth = 0
    this.sourceHeight = 0
    this.hasImageLoadError = false
  }

  private getSafeAspectRatio(): number {
    if (this.sourceWidth > 0 && this.sourceHeight > 0) {
      return Math.max(this.sourceWidth / this.sourceHeight, 0.05)
    }
    if (this.fallbackAspectRatio > 0) {
      return this.fallbackAspectRatio
    }
    return 1
  }

  private getBoundedWidth(): number {
    const ratio = this.getSafeAspectRatio()
    const boundsRatio = this.maxWidth / Math.max(this.maxHeight, 1)
    if (ratio >= boundsRatio) {
      return this.maxWidth
    }
    return Math.max(this.maxHeight * ratio, 1)
  }

  private getBoundedHeight(): number {
    const ratio = this.getSafeAspectRatio()
    const boundsRatio = this.maxWidth / Math.max(this.maxHeight, 1)
    if (ratio >= boundsRatio) {
      return Math.max(this.maxWidth / ratio, 1)
    }
    return this.maxHeight
  }

  private updateSourceSize(event?: ImageCompleteEvent): void {
    const width = event?.width ?? 0
    const height = event?.height ?? 0
    if (width <= 0 || height <= 0 ||
      (this.sourceWidth === width && this.sourceHeight === height)) {
      return
    }
    this.sourceWidth = width
    this.sourceHeight = height
  }

  private handlePreview(): void {
    if (!this.clickable) {
      return
    }
    this.onPreview()
  }

  @Builder
  private BrokenImage() {
    if (this.fillWidth) {
      Column() {
        SymbolGlyph($r('sys.symbol.picture'))
          .fontSize(Math.min(this.maxWidth, this.maxHeight) * 0.32)
          .fontColor([$r('app.color.text_tertiary')])
      }
      .width('100%')
      .aspectRatio(this.getSafeAspectRatio())
      .borderRadius(this.radius)
      .backgroundColor($r('app.color.divider'))
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
    } else {
      Column() {
        SymbolGlyph($r('sys.symbol.picture'))
          .fontSize(Math.min(this.maxWidth, this.maxHeight) * 0.32)
          .fontColor([$r('app.color.text_tertiary')])
      }
      .width(this.getBoundedWidth())
      .height(this.getBoundedHeight())
      .borderRadius(this.radius)
      .backgroundColor($r('app.color.divider'))
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
    }
  }

  @Builder
  private FillWidthImage() {
    Image(this.src)
      .id(this.previewId)
      .width('100%')
      .aspectRatio(this.getSafeAspectRatio())
      .objectFit(ImageFit.Contain)
      .interpolation(ImageInterpolation.Medium)
      .borderRadius(this.radius)
      .clip(true)
      .draggable(false)
      .onComplete((event?: ImageCompleteEvent) => {
        this.updateSourceSize(event)
      })
      .onError(() => {
        this.hasImageLoadError = true
      })
      .onClick(() => {
        this.handlePreview()
      })
  }

  @Builder
  private BoundedImage() {
    Image(this.src)
      .id(this.previewId)
      .width(this.getBoundedWidth())
      .height(this.getBoundedHeight())
      .objectFit(ImageFit.Contain)
      .interpolation(ImageInterpolation.Medium)
      .borderRadius(this.radius)
      .clip(true)
      .draggable(false)
      .onComplete((event?: ImageCompleteEvent) => {
        this.updateSourceSize(event)
      })
      .onError(() => {
        this.hasImageLoadError = true
      })
      .onClick(() => {
        this.handlePreview()
      })
  }

  build() {
    if (this.src === '' || this.hasImageLoadError) {
      this.BrokenImage()
    } else if (this.fillWidth) {
      this.FillWidthImage()
    } else {
      this.BoundedImage()
    }
  }
}
