import { webview } from '@kit.ArkWeb'
import {
  HdsNavigation,
  HdsNavDestination,
  HdsNavDestinationTitleMode,
  HdsNavigationTitleBarOptions,
  HdsNavigationTitleMode
} from '@kit.UIDesignKit'
import { SettingsPagePresentationMode } from '../config/SettingsDetailPresentation'
import { getSettingsPageCompactTabsTotalInset } from '../utils/SettingsPageLayoutHelper'
import { getAppUiState } from '../state/AppUiState'
import {
  buildHdsTopNavigationTitleBarOptionsForNativePage,
  getHdsTopNavigationContentTopPadding,
  getHdsStatusBarContentColor
} from '../utils/HdsVisualEffectUtil'

const PRIVACY_POLICY_URL = 'https://agreement-drcn.hispace.dbankcloud.cn/index.html?lang=zh&agreementId=1955969859250584064'

let privacyPolicyPagePathStack: NavPathStack | null = null

@Entry
@ComponentV2
struct PrivacyPolicyPage {
  @Param hostedInNavDestination: boolean = false
  private get topAvoidHeight(): number {
    return getAppUiState().topAvoidHeight
  }
  private get bottomAvoidHeight(): number {
    return getAppUiState().bottomAvoidHeight
  }
  private get settingsDetailPresentationMode(): string {
    return getAppUiState().settingsDetailPresentationMode
  }
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
  @Computed
  get appIsDarkMode(): boolean {
    return getAppUiState().isDarkMode
  }

  private privacyPolicyWebController: webview.WebviewController = new webview.WebviewController()

  private px2vp(px: number): number {
    return px / (this.getUIContext().getHostContext()?.resourceManager.getDeviceCapabilitySync().screenDensity ?? 3) * 160
  }

  private getContentBottomPadding(): number {
    return 24 + getSettingsPageCompactTabsTotalInset(this.px2vp(this.bottomAvoidHeight),
      this.settingsDetailPresentationMode)
  }

  private isDetailPaneMode(): boolean {
    return this.settingsDetailPresentationMode === SettingsPagePresentationMode.DETAIL_PANE
  }

  private handleBack(): void {
    if (privacyPolicyPagePathStack !== null && privacyPolicyPagePathStack.size() > 0) {
      privacyPolicyPagePathStack.pop()
    }
  }

  private getCompactContentTopPadding(): number {
    return getHdsTopNavigationContentTopPadding(this.px2vp(this.topAvoidHeight), this.windowWidthVp,
      this.windowHeightVp)
  }

  private getCompactTitleBarOptions(): HdsNavigationTitleBarOptions {
    return buildHdsTopNavigationTitleBarOptionsForNativePage(this.materialType, this.materialLevel, this.windowWidthVp,
      this.windowHeightVp, $r('app.string.settings_privacy_policy'), (): void => {
        this.handleBack()
      })
  }

  @Builder
  private PageContent() {
    Column() {
      Web({ src: PRIVACY_POLICY_URL, controller: this.privacyPolicyWebController })
        .width('100%')
        .layoutWeight(1)
        .javaScriptAccess(true)
        .domStorageAccess(true)
        .darkMode(this.appIsDarkMode ? WebDarkMode.On : WebDarkMode.Off)
        .forceDarkAccess(this.appIsDarkMode)
        .backgroundColor(getAppUiState().themeBackground)
    }
    .width('100%')
    .layoutWeight(1)
    .backgroundColor(getAppUiState().themeBackground)
    .padding({
      top: this.isDetailPaneMode() ? 0 : this.getCompactContentTopPadding(),
      bottom: this.getContentBottomPadding()
    })
  }

  @Builder
  private DetailPaneHeader() {
    Column() {
      Row() {
        Text($r('app.string.settings_privacy_policy'))
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
      privacyPolicyPagePathStack = context.pathStack
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
export function PrivacyPolicyPageBuilder(name: string, param: Object) {
  PrivacyPolicyPage({
    hostedInNavDestination: true
  })
}
