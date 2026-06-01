import { AppStorageKeys } from '../config/AppStorageKeys'
import { ServiceRegistry } from '../services/ServiceRegistry'
import { IndexSettingsSheetContent } from '../components/index/IndexSettingsSheetContent'
import {
  HdsNavigation,
  HdsNavDestination,
  HdsNavDestinationTitleMode,
  HdsNavigationTitleBarOptions,
  HdsNavigationTitleMode
} from '@kit.UIDesignKit'
import { IndexSettingsSheetActionCallbacks } from './index/IndexSettingsSheetCoordinator'
import { SettingsSheetType } from './index/IndexPageTypes'
import { getSettingsPageContentMaxWidth, getSettingsPageCompactTabsTotalInset } from '../utils/SettingsPageLayoutHelper'
import { SettingsPagePresentationMode } from '../config/SettingsDetailPresentation'
import { getAppUiState, setAppUiStateValue } from '../state/AppUiState'
import {
  buildHdsTopNavigationTitleBarOptionsForNativePage,
  getHdsTopNavigationContentTopPadding,
  getHdsStatusBarContentColor
} from '../utils/HdsVisualEffectUtil'

let chatInputSettingsPathStack: NavPathStack | null = null

@Entry
@ComponentV2
struct ChatInputSettingsPage {
  @Param hostedInNavDestination: boolean = false
  private get topAvoidHeight(): number {
    return getAppUiState().topAvoidHeight
  }
  private get bottomAvoidHeight(): number {
    return getAppUiState().bottomAvoidHeight
  }
  private get layoutSizeClass(): string {
    return getAppUiState().layoutSizeClass
  }
  private get windowWidthVp(): number {
    return getAppUiState().windowWidthVp
  }
  private get windowHeightVp(): number {
    return getAppUiState().windowHeightVp
  }
  private get settingsDetailPresentationMode(): string {
    return getAppUiState().settingsDetailPresentationMode
  }
  private get materialType(): number {
    return getAppUiState().materialType
  }
  private get materialLevel(): number {
    return getAppUiState().materialLevel
  }

  @Local chatInputEnterKeySend: boolean = false
  @Local chatSuggestedQuestionsEnabled: boolean = false
  @Local experimentalMarkdownHybridEnabled: boolean = false

  private settingsManager = ServiceRegistry.settings()
  private compactScroller: Scroller = new Scroller()

  private px2vp(px: number): number {
    return px / (this.getUIContext().getHostContext()?.resourceManager.getDeviceCapabilitySync().screenDensity ?? 3) * 160
  }

  aboutToAppear(): void {
    this.reloadSettings()
  }

  private reloadSettings(): void {
    this.chatInputEnterKeySend = this.settingsManager.getChatInputEnterKeySend()
    this.chatSuggestedQuestionsEnabled = this.settingsManager.getChatSuggestedQuestionsEnabled()
    this.experimentalMarkdownHybridEnabled = this.settingsManager.getExperimentalMarkdownHybridEnabled()
  }

  private getContentMaxWidth(): number {
    return getSettingsPageContentMaxWidth(this.layoutSizeClass, this.windowWidthVp, this.settingsDetailPresentationMode,
      this.windowHeightVp)
  }

  private isDetailPaneMode(): boolean {
    return this.settingsDetailPresentationMode === SettingsPagePresentationMode.DETAIL_PANE
  }

  private getScrollBottomPadding(): number {
    return 24 + getSettingsPageCompactTabsTotalInset(this.px2vp(this.bottomAvoidHeight),
      this.settingsDetailPresentationMode)
  }

  private handleBack(): void {
    if (chatInputSettingsPathStack !== null && chatInputSettingsPathStack.size() > 0) {
      chatInputSettingsPathStack.pop()
    }
  }

  private getCompactContentTopPadding(): number {
    return getHdsTopNavigationContentTopPadding(this.px2vp(this.topAvoidHeight), this.windowWidthVp,
      this.windowHeightVp)
  }

  private getCompactTitleBarOptions(): HdsNavigationTitleBarOptions {
    return buildHdsTopNavigationTitleBarOptionsForNativePage(this.materialType, this.materialLevel, this.windowWidthVp,
      this.windowHeightVp, $r('app.string.settings_chat_input'), (): void => {
        this.handleBack()
      })
  }

  private buildCallbacks(): IndexSettingsSheetActionCallbacks {
    const callbacks = new IndexSettingsSheetActionCallbacks()
    callbacks.onToggleChatInputEnterKeySend = async (value: boolean): Promise<void> => {
      const previousValue = this.chatInputEnterKeySend
      this.chatInputEnterKeySend = value
      setAppUiStateValue(AppStorageKeys.CHAT_INPUT_ENTER_KEY_SEND, value)
      try {
        await this.settingsManager.setChatInputEnterKeySend(value)
      } catch (error) {
        console.error('ChatInputSettingsPage', `Failed to set enter key behavior: ${JSON.stringify(error)}`)
        this.chatInputEnterKeySend = previousValue
        setAppUiStateValue(AppStorageKeys.CHAT_INPUT_ENTER_KEY_SEND, previousValue)
      }
    }
    callbacks.onToggleChatSuggestedQuestionsEnabled = async (value: boolean): Promise<void> => {
      const previousValue = this.chatSuggestedQuestionsEnabled
      this.chatSuggestedQuestionsEnabled = value
      setAppUiStateValue(AppStorageKeys.CHAT_SUGGESTED_QUESTIONS_ENABLED, value)
      try {
        await this.settingsManager.setChatSuggestedQuestionsEnabled(value)
      } catch (error) {
        console.error('ChatInputSettingsPage', `Failed to set suggested questions: ${JSON.stringify(error)}`)
        this.chatSuggestedQuestionsEnabled = previousValue
        setAppUiStateValue(AppStorageKeys.CHAT_SUGGESTED_QUESTIONS_ENABLED, previousValue)
      }
    }
    callbacks.onToggleExperimentalMarkdownHybridEnabled = async (value: boolean): Promise<void> => {
      const previousValue = this.experimentalMarkdownHybridEnabled
      this.experimentalMarkdownHybridEnabled = value
      setAppUiStateValue(AppStorageKeys.EXPERIMENTAL_MARKDOWN_HYBRID_ENABLED, value)
      try {
        await this.settingsManager.setExperimentalMarkdownHybridEnabled(value)
      } catch (error) {
        console.error('ChatInputSettingsPage', `Failed to set experimental markdown renderer: ${JSON.stringify(error)}`)
        this.experimentalMarkdownHybridEnabled = previousValue
        setAppUiStateValue(AppStorageKeys.EXPERIMENTAL_MARKDOWN_HYBRID_ENABLED, previousValue)
      }
    }
    return callbacks
  }

  @Builder
  private PageContent() {
    Scroll(this.compactScroller) {
      Row() {
        Column() {
          if (!this.isDetailPaneMode()) {
            Blank()
              .width('100%')
              .height(this.getCompactContentTopPadding())
          }

          IndexSettingsSheetContent({
            settingsSheetType: SettingsSheetType.CHAT_INPUT,
            chatInputEnterKeySend: this.chatInputEnterKeySend,
            chatSuggestedQuestionsEnabled: this.chatSuggestedQuestionsEnabled,
            experimentalMarkdownHybridEnabled: this.experimentalMarkdownHybridEnabled,
            callbacks: this.buildCallbacks()
          })
        }
        .width('100%')
        .constraintSize({ maxWidth: this.getContentMaxWidth() })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .padding({ left: 16, right: 16, bottom: this.getScrollBottomPadding() })
    }
    .width('100%')
    .layoutWeight(1)
    .scrollBar(BarState.Off)
  }

  @Builder
  private DetailPaneHeader() {
    Column() {
      Row() {
        Text($r('app.string.settings_chat_input'))
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
      }
      .width('100%')
      .height(64)
      .padding({ left: 24, right: 24 })
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .backgroundColor(getAppUiState().themeBackground)
    .border({ width: { bottom: 1 }, color: $r('app.color.divider') })
  }

  build() {
    if (this.hostedInNavDestination) {
      this.NavDestinationRoot()
    } else {
      this.StandaloneRoot()
    }
  }

  @Builder
  private PageRootContent() {
    Column() {
      if (this.isDetailPaneMode()) {
        Column() {
          this.DetailPaneHeader()
          this.PageContent()
        }
        .width('100%')
        .layoutWeight(1)
      } else {
        this.PageContent()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(getAppUiState().themeBackground)
  }

  @Builder
  private NavDestinationRoot() {
    HdsNavDestination() {
      this.PageRootContent()
    }
    .titleBar(this.getCompactTitleBarOptions())
    .bindToScrollable([this.compactScroller])
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .hideTitleBar(this.isDetailPaneMode(), false)
    .systemBarStyle(
      { statusBarContentColor: getHdsStatusBarContentColor() },
      { statusBarContentColor: getHdsStatusBarContentColor() }
    )
    .hideBackButton(false)
    .hideToolBar(true)
    .backgroundColor(getAppUiState().themeBackground)
    .onReady((context: NavDestinationContext) => {
      chatInputSettingsPathStack = context.pathStack
    })
    .onBackPressed((): boolean => {
      this.handleBack()
      return true
    })
  }

  @Builder
  private StandaloneRoot() {
    if (this.isDetailPaneMode()) {
      this.PageRootContent()
    } else {
      HdsNavigation() {
        this.PageRootContent()
      }
      .width('100%')
      .height('100%')
      .backgroundColor(getAppUiState().themeBackground)
      .titleBar(this.getCompactTitleBarOptions())
      .bindToScrollable([this.compactScroller])
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
export function ChatInputSettingsPageBuilder(name: string, param: Object) {
  ChatInputSettingsPage({
    hostedInNavDestination: true
  })
}
