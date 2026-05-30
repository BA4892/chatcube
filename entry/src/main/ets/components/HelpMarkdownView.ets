import { Want, common } from '@kit.AbilityKit'
import { BusinessError, pasteboard } from '@kit.BasicServicesKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { Markdown, MarkdownController } from '@luvi/lv-markdown-in'
import { getAppUiState } from '../state/AppUiState'
import {
  getMarkdownBlockSpacing,
  getMarkdownQuotePadding,
  getMarkdownTextLineHeight,
  getMarkdownTitleLineHeights,
  getMarkdownTitleSizes
} from '../utils/MarkdownTypographyUtils'
import { showToast } from '../utils/ToastUtil'

const DOMAIN = 0x0000
const TAG = 'HelpMarkdownView'

@ComponentV2
export struct HelpMarkdownView {
  @Param text: ResourceStr = ''
  @Param textSize: number = 15
  @Param compact: boolean = false
  @Param themeRenderKey: string = ''

  @Local resolvedText: string = ''

  private markdownController: MarkdownController = new MarkdownController()

  aboutToAppear(): void {
    this.syncResolvedText()
    this.configureMarkdownController()
  }

  @Monitor('text')
  onTextChange(): void {
    this.syncResolvedText()
  }

  @Monitor('textSize')
  onTextSizeChange(): void {
    this.configureMarkdownController()
  }

  @Monitor('compact')
  onCompactChange(): void {
    this.configureMarkdownController()
  }

  @Monitor('themeRenderKey')
  onThemeRenderKeyChange(): void {
    this.configureMarkdownController()
  }

  private syncResolvedText(): void {
    this.resolvedText = this.resolveText(this.text)
  }

  private resolveText(value: ResourceStr): string {
    if (typeof value === 'string') {
      return value
    }

    const hostContext = this.getUIContext().getHostContext()
    if (hostContext === null || hostContext === undefined) {
      return ''
    }

    try {
      return hostContext.resourceManager.getStringSync((value as Resource).id)
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Resolve help markdown text failed: %{public}s', JSON.stringify(error))
      return ''
    }
  }

  private configureMarkdownController(): void {
    const uiState = getAppUiState()
    const textSize = this.textSize
    const titleSizes = getMarkdownTitleSizes(textSize, this.compact)
    const codeTheme = uiState.isDarkMode ? 'dark' : 'light'
    const latexTextColor = uiState.isDarkMode ? 0xFFE0E0E0 : 0xFF333333

    this.markdownController
      .setTitleColor(uiState.themeMarkdownTitle)
      .setTextColor(uiState.themeMarkdownText)
      .setTextSize(textSize)
      .setTextLineHeight(getMarkdownTextLineHeight(textSize, this.compact))
      .setTitleSize(titleSizes)
      .setTitleLineHeight(getMarkdownTitleLineHeights(titleSizes, this.compact))
      .setQuoteBackgroundColor(uiState.themeMarkdownQuoteBg)
      .setQuoteBorderColor(uiState.themeMarkdownLink)
      .setQuotePadding(getMarkdownQuotePadding(textSize, this.compact))
      .setHyperlinkTextColor(uiState.themeMarkdownLink)
      .setHyperlinkBackgroundColor(uiState.themeMarkdownLinkBg)
      .setInlineCodeColor(uiState.themeMarkdownCodeText)
      .setInlineCodeBackgroundColor(uiState.themeMarkdownCodeBg)
      .setCodeBlockTheme(codeTheme)
      .setLatexMathTextColor(latexTextColor)
      .setLatexMathTextSize(textSize + 2)
      .setTableBackgroundColor(uiState.themeMarkdownTableBg)
      .setTableTitleBackgroundColor(uiState.themeMarkdownTableHeaderBg)
      .setTableInterleaveBackgroundColor(uiState.themeMarkdownTableAltBg)
      .setTableOuterBorderColor(uiState.themeMarkdownTableBorder)
      .setTableInnerBorderColor(uiState.themeMarkdownTableBorder)
      .setUlPointColor(uiState.themeMarkdownText)
      .setLineColor(uiState.themeMarkdownTableBorder)
      .setFootnoteTextColor(uiState.themeMarkdownLink)
      .setHyperlinkClickListener((_title: string, src: string): boolean => {
        return this.openExternalLink(src)
      })
      .setCodeCopyListener((code: string): void => {
        this.copyToClipboard(code)
      })
      .setTextSelectionEnable(true)
      .setTextSelectionCopyListener((selectedText: string): void => {
        this.copyToClipboard(selectedText)
      })

    this.markdownController.setTableTitleTextColor(uiState.themeMarkdownTitle)
    this.markdownController.setTableNormalTextColor(uiState.themeMarkdownText)
    this.markdownController.setTableInterleaveTextColor(uiState.themeMarkdownText)
    this.markdownController.setBlockSpacing(getMarkdownBlockSpacing(textSize, this.compact))
  }

  private normalizeLink(src: string): string {
    const trimmed = src.trim()
    if (trimmed.length === 0 || trimmed.startsWith('#')) {
      return ''
    }

    const lower = trimmed.toLowerCase()
    if (lower.startsWith('http://') || lower.startsWith('https://') ||
      lower.startsWith('mailto:') || lower.startsWith('tel:')) {
      return trimmed
    }

    if (/^[a-z][a-z0-9+.-]*:/.test(lower)) {
      return trimmed
    }

    if (trimmed.indexOf(' ') < 0 && trimmed.indexOf('.') > 0) {
      return `https://${trimmed}`
    }

    return ''
  }

  private openExternalLink(src: string): boolean {
    const uri = this.normalizeLink(src)
    if (uri.length === 0) {
      return false
    }

    const hostContext = this.getUIContext().getHostContext()
    if (hostContext === null || hostContext === undefined) {
      return false
    }

    const want: Want = {
      action: 'ohos.want.action.viewData',
      entities: ['entity.system.browsable'],
      uri: uri
    }

    ;(hostContext as common.UIAbilityContext).startAbility(want).catch((error: BusinessError): void => {
      hilog.error(DOMAIN, TAG, 'Open help link failed: %{public}s, error: %{public}s', uri, JSON.stringify(error))
      showToast(this.getUIContext(), '无法打开链接')
    })
    return true
  }

  private copyToClipboard(text: string): void {
    try {
      const pasteboardData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text)
      const systemPasteboard = pasteboard.getSystemPasteboard()
      systemPasteboard.setData(pasteboardData)
        .then((): void => {
          showToast(this.getUIContext(), $r('app.string.copy_success'))
        })
        .catch((error: BusinessError): void => {
          hilog.error(DOMAIN, TAG, 'Copy help markdown text failed: %{public}s', JSON.stringify(error))
        })
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Copy help markdown text failed: %{public}s', JSON.stringify(error))
    }
  }

  build() {
    Markdown({
      controller: this.markdownController,
      text: this.resolvedText
    })
      .width('100%')
      .backgroundColor(Color.Transparent)
  }
}
