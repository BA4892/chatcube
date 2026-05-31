import { webview } from '@kit.ArkWeb'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { getAppUiState, observeAppUiState } from '../state/AppUiState'

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

  private getBackgroundColor(): string {
    return this.isDarkMode ? '#000000' : '#FFFFFF'
  }

  private getTextColor(): string {
    return this.isDarkMode ? '#E8E8E8' : '#222222'
  }

  private getLineColor(): string {
    return this.isDarkMode ? '#A8A8A8' : '#666666'
  }

  private getHtmlDataUrl(): string {
    const bgColor = this.getBackgroundColor()
    const textColor = this.getTextColor()
    const wrappedHtml = '<!DOCTYPE html><html><head>' +
      '<meta charset="utf-8">' +
      '<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">' +
      '<style>' +
      '* { box-sizing: border-box; }' +
      'html, body { width: 100%; min-height: 100%; margin: 0; padding: 12px; ' +
      'font-family: HarmonyOS Sans, -apple-system, sans-serif; background: ' + bgColor + '; color: ' + textColor + '; }' +
      'img { max-width: 100%; height: auto; }' +
      'table { border-collapse: collapse; width: 100%; }' +
      'th, td { border: 1px solid ' + (this.isDarkMode ? '#3A3A3A' : '#DDDDDD') + '; padding: 8px; text-align: left; }' +
      'th { background: ' + (this.isDarkMode ? '#171717' : '#F5F5F5') + '; }' +
      'a { color: ' + (this.isDarkMode ? '#9CBFE8' : '#4E6F9E') + '; }' +
      'pre, code { font-family: monospace; }' +
      'pre { padding: 12px; border-radius: 8px; overflow-x: auto; background: ' +
      (this.isDarkMode ? '#101010' : '#F6F8FA') + '; }' +
      '</style></head><body>' +
      this.code +
      '</body></html>'
    return 'data:text/html;charset=utf-8,' + encodeURIComponent(wrappedHtml)
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
      this.htmlWebController.loadUrl(this.getHtmlDataUrl())
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
      this.themeObserverDisposer = observeAppUiState(['isDarkMode', 'themePrimary', 'themePrimaryLight'], (): void => {
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
        Web({ src: this.getHtmlDataUrl(), controller: this.htmlWebController })
          .width('100%')
          .layoutWeight(1)
          .onControllerAttached(() => {
            this.isHtmlWebReady = true
          })
          .javaScriptAccess(true)
          .domStorageAccess(true)
          .backgroundColor(this.getBackgroundColor())
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.getBackgroundColor())
  }
}
