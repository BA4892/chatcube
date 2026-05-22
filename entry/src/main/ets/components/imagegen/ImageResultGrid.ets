import { GeneratedMedia } from '../../models/ImageGenerationModels'
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
  @Event onPreview: (index: number) => void = (_index: number): void => {}
  @Event onSave: (item: GeneratedMedia) => void = (_item: GeneratedMedia): void => {}
  @Event onCopyPrompt: (item: GeneratedMedia) => void = (_item: GeneratedMedia): void => {}
  @Event onDelete: (item: GeneratedMedia) => void = (_item: GeneratedMedia): void => {}
  @Event onUseTemplate: (prompt: string) => void = (_prompt: string): void => {}

  // 5 个示例 prompt: 覆盖摄影/插画/3D/极简/微距, 让首次进入的用户即时上手
  private static readonly PROMPT_TEMPLATE_KEYS: string[] = [
    'image_generation_template_1',
    'image_generation_template_2',
    'image_generation_template_3',
    'image_generation_template_4',
    'image_generation_template_5'
  ]

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

      // 示例 prompt 区: 标题 + 自动换行的 chip 流, 点击直接填入输入框
      Column() {
        Text($r('app.string.image_generation_empty_try_prompt'))
          .fontSize(13)
          .fontColor($r('app.color.text_tertiary'))
          .width('100%')
          .padding({ left: 16, right: 16 })
          .margin({ bottom: 8 })

        Flex({
          direction: FlexDirection.Row,
          wrap: FlexWrap.Wrap,
          justifyContent: FlexAlign.Center
        }) {
          ForEach(ImageResultGrid.PROMPT_TEMPLATE_KEYS, (key: string): void => {
            this.TemplateChip(key)
          }, (key: string): string => key)
        }
        .width('100%')
        .padding({ left: 16, right: 16 })
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  // chip 直接 $r(key) 读字符串; onClick 时通过 getStringSync 取真实文本传给回调
  // 换行布局下放开宽度限制, 但 2 行 Ellipsis 避免单 chip 撑满整行
  @Builder
  private TemplateChip(stringKey: string) {
    Button({ type: ButtonType.Normal, stateEffect: false }) {
      Text($r(`app.string.${stringKey}`))
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
      this.applyTemplate(stringKey)
    })
  }

  private applyTemplate(stringKey: string): void {
    try {
      const ctx = this.getUIContext().getHostContext()
      if (ctx === undefined) {
        return
      }
      const promptText = ctx.resourceManager.getStringByNameSync(stringKey)
      if (promptText !== '') {
        this.onUseTemplate(promptText)
      }
    } catch (error) {
      console.error('ImageResultGrid', `Failed to load template prompt: ${JSON.stringify(error)}`)
    }
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
