import { ImageAspectRatio } from '../../models/ImageGenerationModels'
import { getAppUiState } from '../../state/AppUiState'

@ComponentV2
export struct ImageGenerationSettingsSheet {
  @Param numberOfImages: number = 1
  @Param selectedAspectRatio: ImageAspectRatio = ImageAspectRatio.SQUARE
  @Event onNumberChange: (value: number) => void = (_value: number): void => {}
  @Event onAspectRatioChange: (value: ImageAspectRatio) => void = (_value: ImageAspectRatio): void => {}

  private get themePrimary(): string {
    return getAppUiState().themePrimary
  }

  private get themeSurface(): string {
    return getAppUiState().themeSurface
  }

  build() {
    Column({ space: 18 }) {
      this.CountSetting()
      this.AspectRatioSetting()
      Column().height(16)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 24 })
  }

  @Builder
  private CountSetting() {
    Column() {
      Text($r('app.string.image_generation_count'))
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_secondary'))
        .width('100%')
        .margin({ bottom: 8 })

      Row() {
        this.StepButton($r('sys.symbol.minus_circle'), (): void => {
          this.onNumberChange(this.numberOfImages - 1)
        })
        Text(`${this.numberOfImages}`)
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .textAlign(TextAlign.Center)
          .layoutWeight(1)
        this.StepButton($r('sys.symbol.plus'), (): void => {
          this.onNumberChange(this.numberOfImages + 1)
        })
      }
      .width('100%')
      .height(48)
      .padding({ left: 8, right: 8 })
      .backgroundColor(this.themeSurface)
      .borderRadius(12)
    }
    .width('100%')
  }

  @Builder
  private AspectRatioSetting() {
    Column() {
      Text($r('app.string.image_generation_aspect_ratio'))
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_secondary'))
        .width('100%')
        .margin({ bottom: 8 })

      Row({ space: 8 }) {
        this.AspectChip(ImageAspectRatio.SQUARE, $r('app.string.image_generation_aspect_square'))
        this.AspectChip(ImageAspectRatio.LANDSCAPE, $r('app.string.image_generation_aspect_landscape'))
        this.AspectChip(ImageAspectRatio.PORTRAIT, $r('app.string.image_generation_aspect_portrait'))
      }
      .width('100%')
    }
    .width('100%')
  }

  @Builder
  private AspectChip(value: ImageAspectRatio, label: Resource) {
    Button({ type: ButtonType.Capsule, stateEffect: false }) {
      Text(label)
        .fontSize(13)
        .fontColor(this.selectedAspectRatio === value ? this.themePrimary : $r('app.color.text_secondary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .height(40)
    .layoutWeight(1)
    .backgroundColor(this.selectedAspectRatio === value ? getAppUiState().themePrimaryLight : this.themeSurface)
    .border({
      width: this.selectedAspectRatio === value ? 1 : 0.5,
      color: this.selectedAspectRatio === value ? this.themePrimary : $r('app.color.divider')
    })
    .onClick(() => {
      this.onAspectRatioChange(value)
    })
  }

  @Builder
  private StepButton(icon: Resource, action: () => void) {
    Button() {
      SymbolGlyph(icon)
        .fontSize(20)
        .fontColor([this.themePrimary])
    }
    .type(ButtonType.Circle)
    .width(36)
    .height(36)
    .backgroundColor(Color.Transparent)
    .onClick(() => {
      action()
    })
  }
}
