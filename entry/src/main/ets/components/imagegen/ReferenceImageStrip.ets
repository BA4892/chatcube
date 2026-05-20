import { getAppUiState } from '../../state/AppUiState'

@ComponentV2
export struct ReferenceImageStrip {
  @Param imagePaths: string[] = []
  @Param removable: boolean = true
  @Event onRemove: (path: string) => void = (_path: string): void => {}

  build() {
    Scroll() {
      Row({ space: 10 }) {
        ForEach(this.imagePaths, (path: string): void => {
          Stack({ alignContent: Alignment.TopEnd }) {
            Image('file://' + path)
              .width(64)
              .height(64)
              .objectFit(ImageFit.Cover)
              .borderRadius(8)
              .clip(true)

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
          .width(64)
          .height(64)
        }, (path: string): string => path)
      }
      .padding({ left: 16, right: 16 })
    }
    .width('100%')
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .backgroundColor(getAppUiState().themeBackground)
  }
}
