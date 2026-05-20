import { GeneratedMedia } from '../../models/ImageGenerationModels'
import { getAppUiState } from '../../state/AppUiState'
import { getImageGenerationPreviewId } from './ImageGenerationPreviewUtil'

@ComponentV2
export struct ImageResultGrid {
  @Param isGenerating: boolean = false
  @Param isEditing: boolean = false
  @Param items: GeneratedMedia[] = []
  @Event onPreview: (index: number) => void = (_index: number): void => {}
  @Event onSave: (item: GeneratedMedia) => void = (_item: GeneratedMedia): void => {}
  @Event onCopyPrompt: (item: GeneratedMedia) => void = (_item: GeneratedMedia): void => {}
  @Event onDelete: (item: GeneratedMedia) => void = (_item: GeneratedMedia): void => {}

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
      LoadingProgress()
        .width(44)
        .height(44)
        .color(getAppUiState().themePrimary)
      Text(this.isEditing ? $r('app.string.image_generation_editing') : $r('app.string.image_generation_generating'))
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
        .margin({ top: 12 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private EmptyState() {
    Column() {
      SymbolGlyph($r('sys.symbol.picture'))
        .fontSize(48)
        .fontColor([$r('app.color.text_tertiary')])
      Text($r('app.string.image_generation_empty_prompt'))
        .fontSize(16)
        .fontColor($r('app.color.text_secondary'))
        .margin({ top: 14 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
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
    Image('file://' + item.filePath)
      .width('100%')
      .aspectRatio(aspectRatio)
      .objectFit(ImageFit.Cover)
      .borderRadius(8)
      .clip(true)
      .id(this.getPreviewSourceId(item))
      .onClick(() => {
        this.onPreview(previewIndex)
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
