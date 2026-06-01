import { webview } from '@kit.ArkWeb'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { BusinessError, pasteboard } from '@kit.BasicServicesKit'
import { getAppUiState, observeAppUiState } from '../state/AppUiState'
import { showToast } from '../utils/ToastUtil'

const DOMAIN = 0x0002
const TAG = 'CodePreviewSheet'
const MERMAID_PREVIEW_URL = 'resource://rawfile/mermaid/mermaid-preview.html'

interface MermaidRenderPayload {
  code: string
  dark: boolean
  primary: string
  primaryLight: string
  background: string
  text: string
  line: string
}

export function getCodePreviewSheetTitle(kind: string): string {
  if (kind === 'mermaid') {
    return 'Mermaid 预览'
  }
  if (kind === 'html') {
    return 'HTML 预览'
  }
  if (kind !== '') {
    return kind.toUpperCase() + ' 代码'
  }
  return '预览'
}

@ComponentV2
export struct CodePreviewSheet {
  @Param kind: string = ''
  @Param code: string = ''

  private htmlWebController: webview.WebviewController = new webview.WebviewController()
  private mermaidWebController: webview.WebviewController = new webview.WebviewController()
  private isHtmlWebReady: boolean = false
  private isMermaidWebReady: boolean = false
  private isMermaidPageReady: boolean = false
  private themeObserverDisposer: (() => void) | null = null

  private get isDarkMode(): boolean {
    return getAppUiState().isDarkMode
  }

  private get themePrimary(): string {
    return getAppUiState().themePrimary
  }

  private get themePrimaryLight(): string {
    return getAppUiState().themePrimaryLight
  }

  private get themeTextPrimary(): string {
    return getAppUiState().themeTextPrimary
  }

  private getBackgroundColor(): string {
    return getAppUiState().themeBackground
  }

  private getTextColor(): string {
    return this.themeTextPrimary
  }

  private getLineColor(): string {
    return this.isDarkMode ? '#A8A8A8' : '#666666'
  }

  private getCodeBlockBackgroundColor(): string {
    return this.isDarkMode ? '#101010' : '#F6F8FA'
  }

  private copyCode(): void {
    try {
      const pasteboardData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.code)
      const systemPasteboard = pasteboard.getSystemPasteboard()
      systemPasteboard.setData(pasteboardData)
        .then((): void => {
          showToast(this.getUIContext(), $r('app.string.copy_success'))
        })
        .catch((error: BusinessError): void => {
          hilog.error(DOMAIN, TAG, `Copy preview code failed: ${JSON.stringify(error)}`)
        })
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Copy preview code failed: ${JSON.stringify(error)}`)
    }
  }

  private getMermaidRenderScript(): string {
    const payload: MermaidRenderPayload = {
      code: this.code,
      dark: this.isDarkMode,
      primary: this.themePrimary,
      primaryLight: this.themePrimaryLight,
      background: this.getBackgroundColor(),
      text: this.getTextColor(),
      line: this.getLineColor()
    }
    return 'window.renderMermaid(' + JSON.stringify(payload) + ')'
  }

  private renderMermaid(): void {
    if (this.kind !== 'mermaid' || !this.isMermaidWebReady || !this.isMermaidPageReady) {
      return
    }
    try {
      this.mermaidWebController.runJavaScript(this.getMermaidRenderScript())
        .catch((error: Error) => {
          hilog.error(DOMAIN, TAG, `Render Mermaid failed: ${JSON.stringify(error)}`)
        })
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Run Mermaid script failed: ${JSON.stringify(error)}`)
    }
  }

  private reloadHtml(): void {
    if (this.kind !== 'html' || !this.isHtmlWebReady) {
      return
    }
    try {
      this.htmlWebController.loadData(this.code, 'text/html', 'UTF-8', ' ', ' ')
    } catch (error) {
      hilog.error(DOMAIN, TAG, `Reload HTML preview failed: ${JSON.stringify(error)}`)
    }
  }

  private reloadPreview(): void {
    if (this.kind === 'mermaid') {
      this.renderMermaid()
    } else if (this.kind === 'html') {
      this.reloadHtml()
    }
  }

  @Monitor('kind')
  onKindChange(): void {
    this.htmlWebController = new webview.WebviewController()
    this.mermaidWebController = new webview.WebviewController()
    this.isHtmlWebReady = false
    this.isMermaidWebReady = false
    this.isMermaidPageReady = false
  }

  @Monitor('code')
  onCodeChange(): void {
    this.reloadPreview()
  }

  aboutToAppear(): void {
    if (this.themeObserverDisposer === null) {
      this.themeObserverDisposer = observeAppUiState([
        'isDarkMode',
        'themePrimary',
        'themePrimaryLight',
        'themeBackground',
        'themeTextPrimary'
      ], (): void => {
        this.reloadPreview()
      })
    }
  }

  aboutToDisappear(): void {
    if (this.themeObserverDisposer !== null) {
      this.themeObserverDisposer()
      this.themeObserverDisposer = null
    }
  }

  build() {
    Column() {
      if (this.kind === 'mermaid') {
        Web({ src: MERMAID_PREVIEW_URL, controller: this.mermaidWebController })
          .width('100%')
          .layoutWeight(1)
          .onControllerAttached(() => {
            this.isMermaidWebReady = true
          })
          .onPageEnd(() => {
            this.isMermaidPageReady = true
            this.renderMermaid()
          })
          .javaScriptAccess(true)
          .fileAccess(false)
          .backgroundColor(this.getBackgroundColor())
      } else if (this.kind === 'html') {
        Web({ src: '', controller: this.htmlWebController })
          .width('100%')
          .layoutWeight(1)
          .onControllerAttached(() => {
            this.isHtmlWebReady = true
            this.reloadHtml()
          })
          .javaScriptAccess(true)
          .domStorageAccess(true)
          .backgroundColor(this.getBackgroundColor())
      } else {
        Column() {
          Row() {
            Text(this.kind !== '' ? this.kind.toUpperCase() : 'CODE')
              .fontSize(12)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.getTextColor())
              .layoutWeight(1)

            Button() {
              SymbolGlyph($r('sys.symbol.checkmark_square_on_square'))
                .fontSize(16)
                .fontColor([this.themePrimary])
            }
            .width(36)
            .height(36)
            .borderRadius(18)
            .backgroundColor(this.isDarkMode ? '#242424' : '#ECEFF5')
            .onClick(() => {
              this.copyCode()
            })
          }
          .width('100%')
          .height(44)
          .padding({ left: 16, right: 12 })

          Scroll() {
            Text(this.code)
              .width('100%')
              .fontSize(13)
              .lineHeight(20)
              .fontFamily('monospace')
              .fontColor(this.getTextColor())
              .textAlign(TextAlign.Start)
              .copyOption(CopyOptions.LocalDevice)
          }
          .width('100%')
          .layoutWeight(1)
          .padding(12)
          .backgroundColor(this.getCodeBlockBackgroundColor())
        }
        .width('100%')
        .height('100%')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.getBackgroundColor())
  }
}
