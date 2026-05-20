import { getAppUiState } from '../../state/AppUiState'
import { ProviderIcon } from '../ProviderIcon'
import { buildModelIconRenderData, ModelIconRenderData } from '../../utils/ModelIconRenderUtils'
import { ReferenceImageStrip } from './ReferenceImageStrip'

@ComponentV2
export struct ImagePromptBar {
  @Param prompt: string = ''
  @Param isGenerating: boolean = false
  @Param isEditing: boolean = false
  @Param canGenerate: boolean = false
  @Param selectedModelId: string = ''
  @Param selectedModelName: string = ''
  @Param selectedProviderId: string = ''
  @Param selectedProviderIconType: string = 'svg'
  @Param selectedProviderIconPath: string = ''
  @Param selectedProviderTextIcon: string = ''
  @Param selectedProviderTextIconBgColor: string = ''
  @Param selectedProviderCustomImagePath: string = ''
  @Param selectedProviderBrandColor: ResourceColor = ''
  @Param referenceImages: string[] = []
  @Event onPromptChange: (value: string) => void = (_value: string): void => {}
  @Event onOpenModelSheet: () => void = (): void => {}
  @Event onOpenSettings: () => void = (): void => {}
  @Event onPickReferenceImages: () => void = (): void => {}
  @Event onGenerate: () => void = (): void => {}
  @Event onCancel: () => void = (): void => {}
  @Event onRemoveReferenceImage: (path: string) => void = (_path: string): void => {}
  @Event onPreviewReferenceImage: (index: number) => void = (_index: number): void => {}

  private get themePrimary(): string {
    return getAppUiState().themePrimary
  }

  private get themeSurface(): string {
    return getAppUiState().themeSurface
  }

  private getPrimaryActionText(): Resource {
    if (this.isGenerating) {
      return this.isEditing ? $r('app.string.image_generation_cancel_edit') : $r('app.string.image_generation_cancel')
    }
    if (this.isEditing) {
      return $r('app.string.image_generation_edit')
    }
    return $r('app.string.image_generation_generate')
  }

  private hasSelectedModel(): boolean {
    return this.selectedModelName !== '' && this.selectedProviderId !== ''
  }

  private getSelectedModelIconRenderData(): ModelIconRenderData {
    return buildModelIconRenderData(this.selectedModelId, this.selectedProviderId, this.selectedModelName)
  }

  build() {
    Column() {
      if (this.referenceImages.length > 0) {
        ReferenceImageStrip({
          imagePaths: this.referenceImages,
          removable: !this.isGenerating,
          onRemove: (path: string): void => {
            this.onRemoveReferenceImage(path)
          },
          onPreview: (index: number): void => {
            this.onPreviewReferenceImage(index)
          }
        })
          .margin({ bottom: 8 })
      }

      TextArea({ text: this.prompt, placeholder: $r('app.string.image_generation_prompt_placeholder') })
        .fontSize(15)
        .fontColor($r('app.color.text_primary'))
        .placeholderColor($r('app.color.text_tertiary'))
        .backgroundColor(this.themeSurface)
        .borderRadius(12)
        .constraintSize({ minHeight: 48, maxHeight: 140 })
        .padding({ left: 12, right: 12, top: 8, bottom: 8 })
        .onChange((value: string): void => {
          this.onPromptChange(value)
        })

      Row({ space: 8 }) {
        Button({ type: ButtonType.Capsule, stateEffect: false }) {
          Row() {
            this.SelectedModelIcon()
            Text(this.selectedModelName !== '' ? this.selectedModelName : $r('app.string.image_generation_model'))
              .fontSize(13)
              .fontColor(this.selectedModelName !== '' ? this.themePrimary : $r('app.color.text_secondary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .constraintSize({ maxWidth: 130 })
              .margin({ left: 4 })
          }
        }
        .height(34)
        .padding({ left: 12, right: 12 })
        .backgroundColor(getAppUiState().themeBackground)
        .onClick(() => {
          this.onOpenModelSheet()
        })
        .enabled(!this.isGenerating)

        this.IconButton($r('sys.symbol.gearshape'), (): void => {
          this.onOpenSettings()
        })

        this.IconButton($r('sys.symbol.shutter_photo'), (): void => {
          this.onPickReferenceImages()
        }, !this.isGenerating)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .margin({ top: 10 })

      Button({ type: ButtonType.Capsule, stateEffect: false }) {
        Row() {
          SymbolGlyph(this.isGenerating ? $r('sys.symbol.pause') : $r('sys.symbol.paperplane'))
            .fontSize(17)
            .fontColor([Color.White])
          Text(this.getPrimaryActionText())
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(Color.White)
            .margin({ left: 6 })
        }
        .justifyContent(FlexAlign.Center)
        .width('100%')
      }
      .width('100%')
      .height(42)
      .margin({ top: 8 })
      .backgroundColor(this.isGenerating || this.canGenerate ? this.themePrimary : $r('app.color.text_tertiary'))
      .enabled(this.isGenerating || this.canGenerate)
      .onClick(() => {
        if (this.isGenerating) {
          this.onCancel()
        } else {
          this.onGenerate()
        }
      })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .backgroundColor(getAppUiState().themeBackground)
  }

  @Builder
  private SelectedModelIcon() {
    if (this.hasSelectedModel()) {
      Column() {
        if (this.getSelectedModelIconRenderData().hasIcon()) {
          if (this.getSelectedModelIconRenderData().isRawfile()) {
            Image($rawfile(this.getSelectedModelIconRenderData().resourcePath))
              .width(18)
              .height(18)
              .objectFit(ImageFit.Contain)
          } else {
            Image(this.getSelectedModelIconRenderData().resourcePath)
              .width(18)
              .height(18)
              .objectFit(ImageFit.Contain)
          }
        } else {
          ProviderIcon({
            iconType: this.selectedProviderIconType,
            iconPath: this.selectedProviderIconPath,
            textIcon: this.selectedProviderTextIcon,
            textIconBgColor: this.selectedProviderTextIconBgColor,
            customImagePath: this.selectedProviderCustomImagePath,
            iconSize: 18,
            radius: 4,
            bgColor: this.selectedProviderBrandColor,
            brandColor: this.selectedProviderBrandColor,
            fallbackSymbol: $r('sys.symbol.ai_edit'),
            fallbackColor: $r('app.color.text_tertiary')
          })
        }
      }
      .width(20)
      .height(20)
      .borderRadius(5)
      .backgroundColor($r('app.color.model_icon_bg'))
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
    } else {
      SymbolGlyph($r('sys.symbol.picture'))
        .fontSize(15)
        .fontColor([$r('app.color.text_secondary')])
    }
  }

  @Builder
  private IconButton(icon: Resource, action: () => void, enabled: boolean = true) {
    Button() {
      SymbolGlyph(icon)
        .fontSize(18)
        .fontColor([enabled ? $r('app.color.text_secondary') : $r('app.color.text_tertiary')])
    }
    .type(ButtonType.Circle)
    .width(34)
    .height(34)
    .backgroundColor(getAppUiState().themeBackground)
    .enabled(enabled)
    .onClick(() => {
      action()
    })
  }
}
