import { Want, common } from '@kit.AbilityKit'
import { BusinessError, pasteboard } from '@kit.BasicServicesKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { ChatMarkdownHybridRenderer } from './ChatMarkdownHybridRenderer'
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

  aboutToAppear(): void {
    this.syncResolvedText()
  }

  @Monitor('text')
  onTextChange(): void {
    this.syncResolvedText()
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
    ChatMarkdownHybridRenderer({
      content: this.resolvedText,
      isInputEnded: true,
      incrementalAnalysis: false,
      useCangjieComponent: true,
      chatFontSize: this.textSize + 1,
      compact: this.compact,
      themeRenderKey: this.themeRenderKey,
      onOpenLink: (_title: string, url: string): void => {
        this.openExternalLink(url)
      },
      onCopyText: (text: string): void => {
        this.copyToClipboard(text)
      },
      onCopyCode: (code: string): void => {
        this.copyToClipboard(code)
      }
    })
      .width('100%')
      .backgroundColor(Color.Transparent)
  }
}
