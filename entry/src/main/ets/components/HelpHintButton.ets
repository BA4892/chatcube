// 可复用的内联帮助提示按钮:一个 ? 图标,点击弹出 sheet 展示标题 + 正文。
// 用于在功能页就地解释易卡住的设置(如 API 参数、角色含义、生图前置条件)。
import { getAppUiState } from '../state/AppUiState'
import { HelpMarkdownView } from './HelpMarkdownView'

@ComponentV2
export struct HelpHintButton {
  // 提示标题与正文(走字符串资源以支持本地化)
  @Param title: ResourceStr = ''
  @Param body: ResourceStr = ''
  // 图标字号,默认 16
  @Param iconSize: number = 16
  @Local showSheet: boolean = false

  private get themeBackground(): string {
    return getAppUiState().themeBackground
  }

  private getMarkdownThemeRenderKey(): string {
    const uiState = getAppUiState()
    return [
      uiState.isDarkMode ? 'dark' : 'light',
      uiState.themeMarkdownTitle,
      uiState.themeMarkdownText,
      uiState.themeMarkdownLink,
      uiState.themeMarkdownLinkBg,
      uiState.themeMarkdownCodeBg,
      uiState.themeMarkdownCodeText,
      uiState.themeMarkdownQuoteBg,
      uiState.themeMarkdownTableBg,
      uiState.themeMarkdownTableHeaderBg,
      uiState.themeMarkdownTableAltBg,
      uiState.themeMarkdownTableBorder
    ].join('|')
  }

  build() {
    SymbolGlyph($r('sys.symbol.questionmark_circle'))
      .fontSize(this.iconSize)
      .fontColor([$r('app.color.text_tertiary')])
      .onClick(() => {
        this.showSheet = true
      })
      .bindSheet($$this.showSheet, this.HintSheet(), {
        height: SheetSize.FIT_CONTENT,
        showClose: true,
        dragBar: true,
        backgroundColor: this.themeBackground
      })
  }

  @Builder
  HintSheet() {
    Column({ space: 12 }) {
      Text(this.title)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .width('100%')

      HelpMarkdownView({
        text: this.body,
        textSize: 14,
        compact: true,
        themeRenderKey: this.getMarkdownThemeRenderKey()
      })
    }
    .width('100%')
    .padding({ left: 24, right: 24, top: 8, bottom: 32 })
    .alignItems(HorizontalAlign.Start)
  }
}
