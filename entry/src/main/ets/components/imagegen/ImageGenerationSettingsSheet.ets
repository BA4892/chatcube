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

      // 步进按钮 + 可键入输入框组合: 用户既能 ± 一张, 也能直接输入 1-4
      // TextInput onChange 中做范围 clamp, 避免脏值进入 ViewModel
      Row() {
        this.StepButton($r('sys.symbol.minus_circle'), this.canDecrement(), (): void => {
          this.onNumberChange(this.numberOfImages - 1)
        })
        TextInput({ text: `${this.numberOfImages}` })
          .type(InputType.Number)
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .textAlign(TextAlign.Center)
          .backgroundColor(Color.Transparent)
          .borderRadius(0)
          .maxLength(1)
          .layoutWeight(1)
          .onChange((value: string): void => {
            if (value === '') {
              this.onNumberChange(1)
              return
            }
            const parsed: number = Number.parseInt(value)
            if (!isNaN(parsed)) {
              this.onNumberChange(parsed)
            }
          })
        this.StepButton($r('sys.symbol.plus'), this.canIncrement(), (): void => {
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

  // 抽成辅助方法避免在 @Builder 调用中直接出现 < / > 操作符
  // (实测 es2abc 解析 builder 调用第三参为箭头函数时会把 `numberOfImages < 4` 中的 < 误识为泛型)
  private canDecrement(): boolean {
    return this.numberOfImages > 1
  }

  private canIncrement(): boolean {
    return this.numberOfImages < 4
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
  private StepButton(icon: Resource, enabled: boolean, action: () => void) {
    Button() {
      SymbolGlyph(icon)
        .fontSize(20)
        .fontColor([enabled ? this.themePrimary : $r('app.color.text_tertiary')])
    }
    .type(ButtonType.Circle)
    .width(36)
    .height(36)
    .backgroundColor(Color.Transparent)
    .enabled(enabled)
    .onClick(() => {
      action()
    })
  }
}
