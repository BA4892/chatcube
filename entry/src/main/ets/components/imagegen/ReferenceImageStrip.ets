import { getAppUiState } from '../../state/AppUiState'
import { AdaptiveImageThumbnail } from '../AdaptiveImageThumbnail'

@ComponentV2
export struct ReferenceImageStrip {
  @Param imagePaths: string[] = []
  @Param removable: boolean = true
  @Event onRemove: (path: string) => void = (_path: string): void => {}
  @Event onPreview: (index: number) => void = (_index: number): void => {}

  build() {
    Scroll() {
      Row({ space: 10 }) {
        ForEach(this.imagePaths, (path: string, index: number): void => {
          Stack({ alignContent: Alignment.TopEnd }) {
            AdaptiveImageThumbnail({
              src: 'file://' + path,
              previewId: this.getPreviewId(path, index),
              maxWidth: 72,
              maxHeight: 72,
              radius: 8,
              onPreview: (): void => {
                this.onPreview(index)
              }
            })

            if (this.removable) {
              Button() {
                SymbolGlyph($r('sys.symbol.xmark'))
                  .fontSize(10)
                  .fontColor([Color.White])
              }
              .type(ButtonType.Circle)
              .width(22)
              .height(22)
              .backgroundColor('rgba(0, 0, 0, 0.55)')
              .margin({ top: 4, right: 4 })
              .onClick(() => {
                this.onRemove(path)
              })
            }
          }
        }, (path: string): string => path)
      }
      .padding({ left: 16, right: 16 })
    }
    .width('100%')
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .backgroundColor(getAppUiState().themeBackground)
  }

  private getPreviewId(path: string, index: number): string {
    if (path !== '') {
      return 'image_generation_reference_' + path
    }
    return `image_generation_reference_${index}`
  }
}
