import {
  CJMarkdown,
  MarkdownConfiguration,
  MarkdownPlugin,
  MarkdownTheme,
  LatexMathColorFormat
} from '@cangjie-tpc/markdown_hybrid'
import {
  HdsNavigation,
  HdsNavDestination,
  HdsNavDestinationTitleMode,
  HdsNavigationTitleBarOptions,
  HdsNavigationTitleMode
} from '@kit.UIDesignKit'
import { getAppUiState } from '../state/AppUiState'
import { getSettingsManager } from '../viewmodels/SettingsManager'
import {
  buildHdsTopNavigationTitleBarOptionsForNativePage,
  getHdsTopNavigationContentTopPadding,
  getHdsStatusBarContentColor
} from '../utils/HdsVisualEffectUtil'

let markdownHybridPreviewPathStack: NavPathStack | null = null

@Entry
@ComponentV2
struct MarkdownHybridPreviewPage {
  @Param hostedInNavDestination: boolean = false
  @Local private useCangjieComponent: boolean = true
  @Local private incrementalAnalysis: boolean = false
  @Local private isInputEnded: boolean = true
  @Local private experimentalMarkdownHybridEnabled: boolean = false
  private previewScroller: Scroller = new Scroller()
  private settingsManager = getSettingsManager()
  private readonly content: string =
    '# markdown_hybrid PoC\n\n' +
      '行内公式：$E = mc^2$，以及 $\\alpha + \\beta = \\gamma$。\n\n' +
      '块级公式：\n\n' +
      '$$L = \\frac{1}{2n} \\sum_{i=1}^{n} (y_i - \\hat{y}_i)^2$$\n\n' +
      '$$w := w - \\alpha \\frac{\\partial L}{\\partial w}$$\n\n' +
      '$$Y_{i,j} = \\sum_m \\sum_n X_{i+m,j+n} \\cdot K_{m,n}$$\n\n' +
      '表格：\n\n' +
      '| 项 | 值 |\n' +
      '| --- | --- |\n' +
      '| renderer | markdown_hybrid |\n' +
      '| formula | formula-ffi/native |\n\n' +
      '```html\n<div class="demo">Hello markdown_hybrid</div>\n```\n\n' +
      '<p><strong>HTML 标签</strong>渲染测试</p>\n'

  private get windowWidthVp(): number {
    return getAppUiState().windowWidthVp
  }

  private get windowHeightVp(): number {
    return getAppUiState().windowHeightVp
  }

  private get materialType(): number {
    return getAppUiState().materialType
  }

  private get materialLevel(): number {
    return getAppUiState().materialLevel
  }

  private get isDarkMode(): boolean {
    return getAppUiState().isDarkMode
  }

  aboutToAppear(): void {
    this.experimentalMarkdownHybridEnabled = getAppUiState().experimentalMarkdownHybridEnabled
    this.settingsManager.initialize().then((): void => {
      this.experimentalMarkdownHybridEnabled = this.settingsManager.getExperimentalMarkdownHybridEnabled()
    }).catch((error: Error): void => {
      console.error('MarkdownHybridPreviewPage', `Load experimental switch failed: ${JSON.stringify(error)}`)
    })
  }

  private px2vp(px: number): number {
    return px / (this.getUIContext().getHostContext()?.resourceManager.getDeviceCapabilitySync().screenDensity ?? 3) * 160
  }

  private handleBack(): void {
    if (markdownHybridPreviewPathStack !== null && markdownHybridPreviewPathStack.size() > 0) {
      markdownHybridPreviewPathStack.pop()
    }
  }

  private getCompactContentTopPadding(): number {
    return getHdsTopNavigationContentTopPadding(this.px2vp(getAppUiState().topAvoidHeight), this.windowWidthVp,
      this.windowHeightVp)
  }

  private getCompactTitleBarOptions(): HdsNavigationTitleBarOptions {
    return buildHdsTopNavigationTitleBarOptionsForNativePage(this.materialType, this.materialLevel, this.windowWidthVp,
      this.windowHeightVp, 'Markdown Hybrid PoC', (): void => {
        this.handleBack()
      })
  }

  private buildMarkdownConfig(): MarkdownConfiguration {
    const config = new MarkdownConfiguration()
    const theme = new MarkdownTheme()
    const hostContext = this.getUIContext().getHostContext()
    if (hostContext !== undefined && hostContext !== null) {
      theme.setContext(hostContext)
    }
    theme.setBlockFirstTopMargin(0)
    theme.setBlockLastBottomMargin(0)
    theme.setBlockTopAndBottomMargins(8)
    theme.setParagraphTextSize(15)
    theme.setParagraphTextLineHeight(23)
    theme.setParagraphTextColor(this.isDarkMode ? 0xFFE7E0D4 : 0xFF3D3830)
    theme.setHeadingTextColor(this.isDarkMode ? 0xFFF3EFE6 : 0xFF24211C)
    theme.setLinkColor(this.isDarkMode ? 0xFF9CBFE8 : 0xFF4E6F9E)
    theme.setCodeBackgroundColor(this.isDarkMode ? 0xFF24221E : 0xFFF3EFE8)
    theme.setCodeTextColor(this.isDarkMode ? 0xFFD7C4A9 : 0xFF8F5E45)
    theme.setCodeBlockBackgroundColor(this.isDarkMode ? 0xFF24221E : 0xFFF3EFE8)
    theme.setLatexDefaultText(true)
    theme.setLatexMathTextSize(17)
    theme.setLatexMathTextColor(this.isDarkMode ? 0xFFE7E0D4 : 0xFF24211C)
    theme.setLatexMathBackGroupColor(0x00000000)
    theme.setLatexMathColorFormat(LatexMathColorFormat.COLOR_FORMAT_BGRA_8888)
    theme.setLatexMathBlockCenter(false)
    config.setMarkdownTheme(theme)
    config.setLatexImageCallback((_data: ArrayBuffer, height: number, width: number): void => {
      console.info('MarkdownHybridPreviewPage', `latex image generated ${width}x${height}`)
    })
    return config
  }

  private buildMarkdownPlugin(): MarkdownPlugin {
    const plugin = new MarkdownPlugin()
    plugin.setIsTablePlugin(true)
    plugin.setIsLatexMathPlugin(true)
    plugin.setIsStrikethroughPlugin(true)
    plugin.setIsTaskListPlugin(true)
    plugin.setIsLinkifyPlugin(true, [])
    plugin.setIsHtmlPlugin(true)
    return plugin
  }

  private toggleExperimentalMarkdownHybrid(): void {
    const nextValue = !this.experimentalMarkdownHybridEnabled
    this.experimentalMarkdownHybridEnabled = nextValue
    this.settingsManager.setExperimentalMarkdownHybridEnabled(nextValue).catch((error: Error): void => {
      this.experimentalMarkdownHybridEnabled = !nextValue
      console.error('MarkdownHybridPreviewPage', `Set experimental switch failed: ${JSON.stringify(error)}`)
    })
  }

  @Builder
  private ToggleButton(label: string, selected: boolean, action: () => void) {
    Button(label)
      .height(34)
      .fontSize(13)
      .fontColor(selected ? Color.White : $r('app.color.text_secondary'))
      .backgroundColor(selected ? $r('app.color.primary') : $r('app.color.toolbar_btn_bg'))
      .borderRadius(8)
      .padding({ left: 12, right: 12 })
      .onClick(action)
  }

  @Builder
  private PageContent() {
    Column() {
      Row({ space: 8 }) {
        this.ToggleButton('Cangjie', this.useCangjieComponent, (): void => {
          this.useCangjieComponent = true
        })
        this.ToggleButton('ArkUI', !this.useCangjieComponent, (): void => {
          this.useCangjieComponent = false
        })
        this.ToggleButton('Incremental', this.incrementalAnalysis, (): void => {
          this.incrementalAnalysis = !this.incrementalAnalysis
        })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: this.getCompactContentTopPadding() + 12, bottom: 6 })

      Row({ space: 8 }) {
        this.ToggleButton(this.experimentalMarkdownHybridEnabled ? 'Chat Hybrid ON' : 'Chat Hybrid OFF',
          this.experimentalMarkdownHybridEnabled, (): void => {
            this.toggleExperimentalMarkdownHybrid()
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 0, bottom: 8 })

      Scroll(this.previewScroller) {
        Column() {
          CJMarkdown({
            content: this.content,
            isInputEnded: this.isInputEnded,
            incrementalAnalysis: this.incrementalAnalysis,
            useCangjieComponent: this.useCangjieComponent,
            config: this.buildMarkdownConfig(),
            plugin: this.buildMarkdownPlugin()
          })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 8, bottom: 32 })
      }
      .width('100%')
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(getAppUiState().themeBackground)
  }

  build() {
    if (this.hostedInNavDestination) {
      HdsNavDestination() {
        this.PageContent()
      }
      .titleBar(this.getCompactTitleBarOptions())
      .bindToScrollable([this.previewScroller])
      .titleMode(HdsNavDestinationTitleMode.MINI)
      .systemBarStyle(
        { statusBarContentColor: getHdsStatusBarContentColor() },
        { statusBarContentColor: getHdsStatusBarContentColor() }
      )
      .hideBackButton(false)
      .hideToolBar(true)
      .backgroundColor(getAppUiState().themeBackground)
      .onReady((context: NavDestinationContext) => {
        markdownHybridPreviewPathStack = context.pathStack
      })
      .onBackPressed((): boolean => {
        this.handleBack()
        return true
      })
    } else {
      HdsNavigation() {
        this.PageContent()
      }
      .width('100%')
      .height('100%')
      .backgroundColor(getAppUiState().themeBackground)
      .titleBar(this.getCompactTitleBarOptions())
      .bindToScrollable([this.previewScroller])
      .titleMode(HdsNavigationTitleMode.MINI)
      .systemBarStyle(
        { statusBarContentColor: getHdsStatusBarContentColor() },
        { statusBarContentColor: getHdsStatusBarContentColor() }
      )
      .hideBackButton(false)
      .hideToolBar(true)
      .mode(NavigationMode.Stack)
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP])
    }
  }
}

@Builder
export function MarkdownHybridPreviewPageBuilder(_name: string, _param: Object) {
  MarkdownHybridPreviewPage({
    hostedInNavDestination: true
  })
}
