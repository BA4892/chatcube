import { GeneratedMedia } from '../../models/ImageGenerationModels'
import { ImagePromptTemplate } from '../../models/ImagePromptTemplateModels'
import { getAppUiState } from '../../state/AppUiState'
import { getImageGenerationPreviewId } from './ImageGenerationPreviewUtil'
import { AdaptiveImageThumbnail } from '../AdaptiveImageThumbnail'
import { CubeSpinnerAssemble } from '../loading/CubeSpinner'

@ComponentV2
export struct ImageResultGrid {
  @Param isGenerating: boolean = false
  @Param isEditing: boolean = false
  @Param items: GeneratedMedia[] = []
  @Param requestedCount: number = 1
  @Param promptTemplates: ImagePromptTemplate[] = []
  @Param hasPromptTemplates: boolean = false
  @Param canRotatePromptTemplates: boolean = false
  @Param promptTemplatesVisible: boolean = true
  @Event onPreview: (index: number) => void = (_index: number): void => {}
  @Event onSave: (item: GeneratedMedia) => void = (_item: GeneratedMedia): void => {}
  @Event onCopyPrompt: (item: GeneratedMedia) => void = (_item: GeneratedMedia): void => {}
  @Event onContinueEdit: (item: GeneratedMedia) => void = (_item: GeneratedMedia): void => {}
  @Event onDelete: (item: GeneratedMedia) => void = (_item: GeneratedMedia): void => {}
  @Event onUseTemplate: (prompt: string) => void = (_prompt: string): void => {}
  @Event onRotateTemplates: () => void = (): void => {}
  @Event onToggleTemplateVisibility: () => void = (): void => {}
  @Event onManageTemplates: () => void = (): void => {}

  build() {
    Column() {
      if (this.isGenerating && this.items.length === 0) {
        this.LoadingState()
      } else if (this.items.length === 0) {
        this.EmptyState()
      } else if (this.items.length === 1) {
        this.SingleImage(this.items[0])
      } else {
        this.GridImages()
      }
    }
    .width('100%')
    .layoutWeight(1)
  }

  @Builder
  private LoadingState() {
    Column() {
      CubeSpinnerAssemble({ sizeVp: 64, color: getAppUiState().themePrimary })
      Text(this.getLoadingText())
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
        .margin({ top: 16 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  // 显示数量提示, 例如 "正在生成 3 张图片"; 多张时数字感更强, 缓解等待焦虑
  private getLoadingText(): ResourceStr {
    if (this.requestedCount > 1) {
      const key = this.isEditing ? 'image_generation_editing_count' : 'image_generation_generating_count'
      return $r(`app.string.${key}`, this.requestedCount)
    }
    return this.isEditing ?
      $r('app.string.image_generation_editing') :
      $r('app.string.image_generation_generating')
  }

  @Builder
  private EmptyState() {
    Column({ space: 16 }) {
      Column() {
        SymbolGlyph($r('sys.symbol.picture'))
          .fontSize(48)
          .fontColor([$r('app.color.text_tertiary')])
        Text($r('app.string.image_generation_empty_prompt'))
          .fontSize(16)
          .fontColor($r('app.color.text_secondary'))
          .margin({ top: 14 })
      }

      if (this.hasPromptTemplates || this.promptTemplates.length > 0) {
        if (this.promptTemplatesVisible) {
          // 示例 prompt 区: 标题 + 操作按钮 + 自动换行的 chip 流, 点击直接填入输入框
          Column() {
            Row() {
              Text($r('app.string.image_generation_empty_try_prompt'))
                .fontSize(13)
                .fontColor($r('app.color.text_tertiary'))
                .layoutWeight(1)
              this.TemplateActionButton($r('sys.symbol.arrow_clockwise'), $r('app.string.image_prompt_template_refresh'), (): void => {
                this.onRotateTemplates()
              }, this.canRotatePromptTemplates)
              this.TemplateActionButton($r('sys.symbol.eye_slash'), $r('app.string.image_prompt_template_hide_recommendations'), (): void => {
                this.onToggleTemplateVisibility()
              }, true)
              this.TemplateActionButton($r('sys.symbol.AI_word_suggest'), $r('app.string.image_prompt_template_manage'), (): void => {
                this.onManageTemplates()
              }, true)
            }
            .width('100%')
            .padding({ left: 16, right: 16 })
            .margin({ bottom: 8 })

            if (this.promptTemplates.length > 0) {
              Flex({
                direction: FlexDirection.Row,
                wrap: FlexWrap.Wrap,
                justifyContent: FlexAlign.Center
              }) {
                ForEach(this.promptTemplates, (template: ImagePromptTemplate): void => {
                  this.TemplateChip(template)
                }, (template: ImagePromptTemplate): string => template.id)
              }
              .width('100%')
              .padding({ left: 16, right: 16 })
            }
          }
          .width('100%')
        } else {
          Row() {
            this.TemplateActionButton($r('sys.symbol.eye'), $r('app.string.image_prompt_template_show_recommendations'), (): void => {
              this.onToggleTemplateVisibility()
            }, true)
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
        }
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  // 换行布局下放开宽度限制, 但 2 行 Ellipsis 避免单 chip 撑满整行
  @Builder
  private TemplateChip(template: ImagePromptTemplate) {
    Button({ type: ButtonType.Normal, stateEffect: false }) {
      Text(template.title !== '' ? template.title : template.prompt)
        .fontSize(12)
        .fontColor($r('app.color.text_primary'))
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .textAlign(TextAlign.Start)
    }
    .padding({ left: 12, right: 12, top: 8, bottom: 8 })
    .margin({ right: 8, bottom: 8 })
    .borderRadius(16)
    .backgroundColor(getAppUiState().themeSurface)
    .onClick(() => {
      this.onUseTemplate(template.prompt)
    })
  }

  @Builder
  private TemplateActionButton(icon: Resource, label: Resource, action: () => void, enabled: boolean) {
    Button({ type: ButtonType.Circle, stateEffect: false }) {
      SymbolGlyph(icon)
        .fontSize(16)
        .fontColor([enabled ? $r('app.color.text_secondary') : $r('app.color.text_tertiary')])
    }
    .width(30)
    .height(30)
    .backgroundColor(getAppUiState().themeSurface)
    .accessibilityText(label)
    .enabled(enabled)
    .margin({ left: 6 })
    .onClick(() => {
      action()
    })
  }

  @Builder
  private SingleImage(item: GeneratedMedia) {
    Column() {
      this.PreviewImage(item, this.getAspectRatioValue(item.aspectRatio), 0)

      this.ActionRow(item)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 16 })
  }

  @Builder
  private GridImages() {
    Grid() {
      ForEach(this.items, (item: GeneratedMedia, index: number): void => {
        GridItem() {
          Column() {
            this.PreviewImage(item, 1, index)
            this.ActionRow(item)
          }
          .width('100%')
        }
      }, (item: GeneratedMedia): string => item.id)
    }
    .columnsTemplate('1fr 1fr')
    .columnsGap(12)
    .rowsGap(12)
    .padding({ left: 16, right: 16, top: 16, bottom: 16 })
    .width('100%')
  }

  @Builder
  private PreviewImage(item: GeneratedMedia, aspectRatio: number, previewIndex: number) {
    AdaptiveImageThumbnail({
      src: 'file://' + item.filePath,
      previewId: this.getPreviewSourceId(item),
      fillWidth: true,
      fallbackAspectRatio: aspectRatio,
      radius: 8,
      onPreview: () => {
        this.onPreview(previewIndex)
      }
    })
  }

  @Builder
  private ActionRow(item: GeneratedMedia) {
    Row({ space: 6 }) {
      this.IconAction($r('sys.symbol.eye'), (): void => {
        const index = this.indexOfItem(item.id)
        this.onPreview(index >= 0 ? index : 0)
      })
      this.IconAction($r('sys.symbol.square_and_arrow_down'), (): void => {
        this.onSave(item)
      })
      this.IconAction($r('sys.symbol.checkmark_square_on_square'), (): void => {
        this.onCopyPrompt(item)
      })
      this.IconAction($r('sys.symbol.ai_edit'), (): void => {
        this.onContinueEdit(item)
      })
      this.IconAction($r('sys.symbol.trash'), (): void => {
        this.onDelete(item)
      }, true)
    }
    .width('100%')
    .justifyContent(FlexAlign.End)
    .margin({ top: 8, bottom: 6 })
  }

  @Builder
  private IconAction(icon: Resource, action: () => void, danger: boolean = false) {
    Button() {
      SymbolGlyph(icon)
        .fontSize(16)
        .fontColor([danger ? $r('app.color.status_error') : $r('app.color.text_secondary')])
    }
    .type(ButtonType.Circle)
    .width(32)
    .height(32)
    .backgroundColor(getAppUiState().themeSurface)
    .onClick(() => {
      action()
    })
  }

  private indexOfItem(id: string): number {
    for (let i = 0; i < this.items.length; i++) {
      if (this.items[i].id === id) {
        return i
      }
    }
    return -1
  }

  private getAspectRatioValue(aspectRatio: string): number {
    if (aspectRatio === 'landscape') {
      return 16 / 9
    }
    if (aspectRatio === 'portrait') {
      return 9 / 16
    }
    return 1
  }

  private getPreviewSourceId(item: GeneratedMedia): string {
    return getImageGenerationPreviewId(item)
  }
}
