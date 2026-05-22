import { getAppUiState } from '../../state/AppUiState'
import { ProviderIcon } from '../ProviderIcon'
import { buildModelIconRenderData, ModelIconRenderData } from '../../utils/ModelIconRenderUtils'
import { ImageAspectRatio } from '../../models/ImageGenerationModels'
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
  @Param selectedAspectRatio: ImageAspectRatio = ImageAspectRatio.SQUARE
  @Event onPromptChange: (value: string) => void = (_value: string): void => {}
  @Event onOpenModelSheet: () => void = (): void => {}
  @Event onOpenSettings: () => void = (): void => {}
  @Event onPickReferenceImages: () => void = (): void => {}
  @Event onGenerate: () => void = (): void => {}
  @Event onCancel: () => void = (): void => {}
  @Event onRemoveReferenceImage: (path: string) => void = (_path: string): void => {}
  @Event onPreviewReferenceImage: (index: number) => void = (_index: number): void => {}
  @Event onAspectRatioChange: (value: ImageAspectRatio) => void = (_value: ImageAspectRatio): void => {}

  private get themePrimary(): string {
    return getAppUiState().themePrimary
  }

  private get themeSurface(): string {
    return getAppUiState().themeSurface
  }

  private hasSelectedModel(): boolean {
    return this.selectedModelName !== '' && this.selectedProviderId !== ''
  }

  private getSelectedModelIconRenderData(): ModelIconRenderData {
    return buildModelIconRenderData(this.selectedModelId, this.selectedProviderId, this.selectedModelName)
  }

  // 主操作按钮状态: 生成中 → 取消(error 红);可发送 → 主题色;不可用 → 灰
  private getPrimaryActionColor(): ResourceColor {
    if (this.isGenerating) {
      return $r('app.color.status_error')
    }
    if (this.canGenerate) {
      return this.themePrimary
    }
    return $r('app.color.text_tertiary')
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

      // 工具行: 左侧可横滑 (model + 📷 + 3 比例 chip + 设置),右侧固定 send 圆按钮
      // 横滑容器避免窄屏溢出, send 按钮始终在最右触手可及
      Row({ space: 8 }) {
        Scroll() {
          Row({ space: 8 }) {
            this.ModelCapsule()
            this.IconCircleButton($r('sys.symbol.shutter_photo'), !this.isGenerating, (): void => {
              this.onPickReferenceImages()
            })
            this.AspectChip(ImageAspectRatio.SQUARE, '1:1')
            this.AspectChip(ImageAspectRatio.LANDSCAPE, '16:9')
            this.AspectChip(ImageAspectRatio.PORTRAIT, '9:16')
            this.IconCircleButton($r('sys.symbol.gearshape'), true, (): void => {
              this.onOpenSettings()
            })
          }
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .layoutWeight(1)
        .align(Alignment.Start)

        this.SendButton()
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .margin({ top: 10 })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .backgroundColor(getAppUiState().themeBackground)
  }

  @Builder
  private ModelCapsule() {
    Button({ type: ButtonType.Capsule, stateEffect: false }) {
      Row() {
        this.SelectedModelIcon()
        Text(this.selectedModelName !== '' ? this.selectedModelName : $r('app.string.image_generation_model'))
          .fontSize(13)
          .fontColor(this.selectedModelName !== '' ? this.themePrimary : $r('app.color.text_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .constraintSize({ maxWidth: 120 })
          .margin({ left: 4 })
      }
    }
    .height(34)
    .padding({ left: 10, right: 12 })
    .backgroundColor(this.themeSurface)
    .onClick(() => {
      this.onOpenModelSheet()
    })
    .enabled(!this.isGenerating)
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
  private AspectChip(value: ImageAspectRatio, label: string) {
    Button({ type: ButtonType.Normal, stateEffect: false }) {
      Text(label)
        .fontSize(12)
        .fontWeight(this.selectedAspectRatio === value ? FontWeight.Medium : FontWeight.Regular)
        .fontColor(this.selectedAspectRatio === value ? this.themePrimary : $r('app.color.text_secondary'))
    }
    .height(34)
    .padding({ left: 10, right: 10 })
    .borderRadius(17)
    .backgroundColor(this.selectedAspectRatio === value ? getAppUiState().themePrimaryLight : this.themeSurface)
    .border({
      width: this.selectedAspectRatio === value ? 1 : 0,
      color: this.themePrimary
    })
    .enabled(!this.isGenerating)
    .onClick(() => {
      this.onAspectRatioChange(value)
    })
  }

  @Builder
  private IconCircleButton(icon: Resource, enabled: boolean, action: () => void) {
    Button() {
      SymbolGlyph(icon)
        .fontSize(17)
        .fontColor([enabled ? $r('app.color.text_secondary') : $r('app.color.text_tertiary')])
    }
    .type(ButtonType.Circle)
    .width(34)
    .height(34)
    .backgroundColor(this.themeSurface)
    .enabled(enabled)
    .onClick(() => {
      action()
    })
  }

  // 圆形主操作按钮: 生成中显示 stop, 否则显示发送箭头;颜色随状态切换
  @Builder
  private SendButton() {
    Button({ type: ButtonType.Circle, stateEffect: false }) {
      SymbolGlyph(this.isGenerating ? $r('sys.symbol.pause') : $r('sys.symbol.paperplane'))
        .fontSize(17)
        .fontColor([Color.White])
    }
    .width(40)
    .height(40)
    .backgroundColor(this.getPrimaryActionColor())
    .enabled(this.isGenerating || this.canGenerate)
    .onClick(() => {
      if (this.isGenerating) {
        this.onCancel()
      } else {
        this.onGenerate()
      }
    })
  }
}
