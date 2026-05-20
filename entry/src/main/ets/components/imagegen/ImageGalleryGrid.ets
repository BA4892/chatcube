import { GeneratedMedia } from '../../models/ImageGenerationModels'
import { getAppUiState } from '../../state/AppUiState'
import { getImageGenerationPreviewId } from './ImageGenerationPreviewUtil'

@ComponentV2
export struct ImageGalleryGrid {
  @Param items: GeneratedMedia[] = []
  @Param columns: number = 2
  @Event onPreview: (index: number) => void = (_index: number): void => {}
  @Event onSave: (item: GeneratedMedia) => void = (_item: GeneratedMedia): void => {}
  @Event onCopyPrompt: (item: GeneratedMedia) => void = (_item: GeneratedMedia): void => {}
  @Event onDelete: (item: GeneratedMedia) => void = (_item: GeneratedMedia): void => {}

  build() {
    if (this.items.length === 0) {
      this.EmptyState()
    } else {
      Grid() {
        Repeat<GeneratedMedia>(this.items)
          .each((obj: RepeatItem<GeneratedMedia>) => {
            GridItem() {
              this.MediaCard(obj.item)
            }
          })
          .key((item: GeneratedMedia) => {
            return item.id
          })
          .virtualScroll({ totalCount: this.items.length })
      }
      .columnsTemplate(this.getColumnsTemplate())
      .columnsGap(12)
      .rowsGap(12)
      .padding({ left: 16, right: 16, top: 16, bottom: 24 })
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .cachedCount(this.getCachedCount())
    }
  }

  @Builder
  private EmptyState() {
    Column() {
      SymbolGlyph($r('sys.symbol.picture'))
        .fontSize(48)
        .fontColor([$r('app.color.text_tertiary')])
      Text($r('app.string.image_generation_gallery_empty'))
        .fontSize(16)
        .fontColor($r('app.color.text_secondary'))
        .margin({ top: 14 })
      Text($r('app.string.image_generation_gallery_empty_desc'))
        .fontSize(13)
        .fontColor($r('app.color.text_tertiary'))
        .margin({ top: 4 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private MediaCard(item: GeneratedMedia) {
    Column() {
      this.PreviewImage(item)

      Text(item.modelName)
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .margin({ top: 8 })

      Text(item.prompt)
        .fontSize(12)
        .fontColor($r('app.color.text_secondary'))
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .margin({ top: 4 })

      Row({ space: 4 }) {
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
      .margin({ top: 8 })
    }
    .width('100%')
    .padding(10)
    .backgroundColor(getAppUiState().themeSurface)
    .borderRadius(8)
  }

  @Builder
  private PreviewImage(item: GeneratedMedia) {
    Image('file://' + item.filePath)
      .width('100%')
      .aspectRatio(1)
      .objectFit(ImageFit.Cover)
      .borderRadius(8)
      .clip(true)
      .id(this.getPreviewSourceId(item))
      .onClick(() => {
        this.onPreview(this.indexOfItem(item.id))
      })
  }

  @Builder
  private IconAction(icon: Resource, action: () => void, danger: boolean = false) {
    Button() {
      SymbolGlyph(icon)
        .fontSize(15)
        .fontColor([danger ? $r('app.color.status_error') : $r('app.color.text_secondary')])
    }
    .type(ButtonType.Circle)
    .width(30)
    .height(30)
    .backgroundColor(getAppUiState().themeBackground)
    .onClick(() => {
      action()
    })
  }

  private getColumnsTemplate(): string {
    if (this.columns >= 3) {
      return '1fr 1fr 1fr'
    }
    return '1fr 1fr'
  }

  private getCachedCount(): number {
    return this.columns >= 3 ? 9 : 6
  }

  private indexOfItem(id: string): number {
    for (let i = 0; i < this.items.length; i++) {
      if (this.items[i].id === id) {
        return i
      }
    }
    return 0
  }

  private getPreviewSourceId(item: GeneratedMedia): string {
    return getImageGenerationPreviewId(item)
  }
}
