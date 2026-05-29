import { ToolsCenterPanel } from '../components/ToolsCenterPanel'
import {
  HdsNavigation,
  HdsNavDestination,
  HdsNavDestinationTitleMode,
  HdsNavigationTitleBarOptions,
  HdsNavigationTitleMode
} from '@kit.UIDesignKit'
import { AppStorageKeys } from '../config/AppStorageKeys'
import { LayoutSizeClass } from '../config/LayoutProfile'
import { SettingsPagePresentationMode } from '../config/SettingsDetailPresentation'
import { getSettingsPageContentMaxWidth, getSettingsPageCompactTabsTotalInset } from '../utils/SettingsPageLayoutHelper'
import { getAppUiState } from '../state/AppUiState'
import {
  buildHdsTopNavigationTitleBarOptionsForNativePage,
  getHdsTopNavigationContentTopPadding,
  getHdsStatusBarContentColor
} from '../utils/HdsVisualEffectUtil'

let toolsCenterPagePathStack: NavPathStack | null = null

@Entry
@ComponentV2
struct ToolsCenterPage {
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
  private toolsCenterScroller: Scroller = new Scroller()

  private px2vp(px: number): number {
    return px / (this.getUIContext().getHostContext()?.resourceManager.getDeviceCapabilitySync().screenDensity ?? 3) * 160
  }

  private getContentMaxWidth(): number {
    return getSettingsPageContentMaxWidth(this.layoutSizeClass, this.windowWidthVp, this.settingsDetailPresentationMode,
      this.windowHeightVp)
  }

  private isDetailPaneMode(): boolean {
    return this.settingsDetailPresentationMode === SettingsPagePresentationMode.DETAIL_PANE
  }

  private getContentBottomPadding(): number {
    return 24 + getSettingsPageCompactTabsTotalInset(this.px2vp(this.bottomAvoidHeight),
      this.settingsDetailPresentationMode)
  }

  private handleBack(): void {
    if (toolsCenterPagePathStack !== null && toolsCenterPagePathStack.size() > 0) {
      toolsCenterPagePathStack.pop()
    }
  }

  private getCompactContentTopPadding(): number {
    return getHdsTopNavigationContentTopPadding(this.px2vp(this.topAvoidHeight), this.windowWidthVp,
      this.windowHeightVp)
  }

  private getCompactTitleBarOptions(): HdsNavigationTitleBarOptions {
    return buildHdsTopNavigationTitleBarOptionsForNativePage(this.materialType, this.materialLevel, this.windowWidthVp,
      this.windowHeightVp, $r('app.string.tools_center_title'), (): void => {
        this.handleBack()
      })
  }

  @Builder
  private PageContent() {
    Row() {
      Column() {
        ToolsCenterPanel({
          showHeader: false,
          contentBottomPadding: this.getContentBottomPadding(),
          contentTopPadding: this.isDetailPaneMode() ? 0 : this.getCompactContentTopPadding(),
          contentScroller: this.toolsCenterScroller
        })
      }
      .width('100%')
      .layoutWeight(1)
      .constraintSize({ maxWidth: this.getContentMaxWidth() })
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Top)
    .padding({ left: 16, right: 16 })
  }

  @Builder
  private DetailPaneHeader() {
    Column() {
      Row() {
        Text($r('app.string.tools_center_title'))
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
    .bindToScrollable([this.toolsCenterScroller])
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
      toolsCenterPagePathStack = context.pathStack
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
      .bindToScrollable([this.toolsCenterScroller])
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
export function ToolsCenterPageBuilder(name: string, param: Object) {
  ToolsCenterPage({
    hostedInNavDestination: true
  })
}
