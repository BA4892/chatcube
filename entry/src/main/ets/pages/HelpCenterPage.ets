// 使用帮助中心页
// 套用设置详情页统一模板(compact / detail-pane 双模式),内容用可控卡片渲染话题行。
// 点击话题通过 geometryTransition 进入帮助详情页,实现列表到详情的一镜到底效果。
import { curves } from '@kit.ArkUI'
import {
  HdsNavigation,
  HdsNavDestination,
  HdsNavDestinationTitleMode,
  HdsNavigationTitleBarOptions,
  HdsNavigationTitleMode
} from '@kit.UIDesignKit'
import { SettingsPagePresentationMode } from '../config/SettingsDetailPresentation'
import { getSettingsPageContentMaxWidth } from '../utils/SettingsPageLayoutHelper'
import { getAppUiState } from '../state/AppUiState'
import {
  buildHdsTopNavigationTitleBarOptionsForNativePage,
  getHdsTopNavigationContentTopPadding,
  getHdsStatusBarContentColor
} from '../utils/HdsVisualEffectUtil'
import { HELP_CATEGORIES, HelpCategory, HelpTopic } from '../config/HelpContent'
import { HelpTopicDetailRouteParams } from './HelpTopicDetailPage'

let helpCenterPagePathStack: NavPathStack | null = null
const HELP_TOPIC_DETAIL_ROUTE_NAME = 'HelpTopicDetailPage'
const HELP_TOPIC_GEOMETRY_PREFIX = 'help-topic-'

@ComponentV2
struct HelpTopicListItem {
  @Param title: ResourceStr = ''
  @Param teaser: ResourceStr = ''
  @Param geometryId: string = ''
  @Event onOpen: () => void = () => {}

  @Local scaleValue: number = 1

  private animateScale(scale: number): void {
    this.getUIContext().animateTo({ curve: curves.interpolatingSpring(0, 1, 350, 35) }, (): void => {
      this.scaleValue = scale
    })
  }

  private handleTouch(event?: TouchEvent): void {
    if (event === undefined) {
      return
    }
    if (event.type === TouchType.Down) {
      this.animateScale(0.97)
      return
    }
    if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      this.animateScale(1)
    }
  }

  build() {
    Column() {
      Row({ space: 12 }) {
        Column({ space: 4 }) {
          Text(this.title)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')

          Text(this.teaser)
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
            .lineHeight(19)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }
        .layoutWeight(1)

        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(17)
          .fontColor([$r('app.color.text_tertiary')])
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
      .width('100%')
      .padding({ left: 16, right: 12, top: 14, bottom: 14 })
      .backgroundColor($r('sys.color.comp_background_tertiary'))
      .borderRadius(8)
      .clip(true)
      .scale({
        x: this.scaleValue,
        y: this.scaleValue
      })
      .geometryTransition(this.geometryId, { follow: true })
      .transition(TransitionEffect.OPACITY.animation({ duration: 180, curve: Curve.EaseOut }))
      .onClick((): void => {
        this.onOpen()
      })
      .onTouch((event?: TouchEvent): void => {
        this.handleTouch(event)
      })
  }
}

@Entry
@ComponentV2
struct HelpCenterPage {
  @Param hostedInNavDestination: boolean = false

  private get topAvoidHeight(): number {
    return getAppUiState().topAvoidHeight
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

  @Local transitionEffect: TransitionEffect = TransitionEffect.IDENTITY
  private compactScroller: Scroller = new Scroller()

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

  private handleBack(): void {
    if (helpCenterPagePathStack !== null && helpCenterPagePathStack.size() > 0) {
      this.transitionEffect = TransitionEffect.IDENTITY
      helpCenterPagePathStack.pop()
    }
  }

  private getCompactContentTopPadding(): number {
    return getHdsTopNavigationContentTopPadding(this.px2vp(this.topAvoidHeight), this.windowWidthVp,
      this.windowHeightVp)
  }

  private getCompactTitleBarOptions(): HdsNavigationTitleBarOptions {
    return buildHdsTopNavigationTitleBarOptionsForNativePage(this.materialType, this.materialLevel, this.windowWidthVp,
      this.windowHeightVp, $r('app.string.settings_help_center'), (): void => {
        this.handleBack()
      })
  }

  private getTopicGeometryId(topic: HelpTopic): string {
    return HELP_TOPIC_GEOMETRY_PREFIX + topic.key
  }

  private openTopic(topic: HelpTopic): void {
    if (helpCenterPagePathStack === null) {
      return
    }

    const params: HelpTopicDetailRouteParams = {
      topicKey: topic.key,
      geometryId: this.getTopicGeometryId(topic)
    }
    this.transitionEffect = TransitionEffect.OPACITY
      .animation({ curve: curves.interpolatingSpring(0, 1, 195, 23) })

    this.getUIContext().animateTo({ curve: curves.interpolatingSpring(0, 1, 328, 36) }, (): void => {
      helpCenterPagePathStack?.pushPath({
        name: HELP_TOPIC_DETAIL_ROUTE_NAME,
        param: params as HelpTopicDetailRouteParams
      }, false)
    })
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

          Text($r('app.string.help_intro'))
            .fontSize(13)
            .lineHeight(20)
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
            .padding({ top: 8, bottom: 4 })

          ForEach(HELP_CATEGORIES, (category: HelpCategory) => {
            this.CategorySection(category)
          }, (category: HelpCategory) => category.key)

          Column().height(40)
        }
        .width('100%')
        .constraintSize({ maxWidth: this.getContentMaxWidth() })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .padding({ left: 16, right: 16 })
    }
    .width('100%')
    .layoutWeight(1)
    .scrollBar(BarState.Off)
    .align(Alignment.Top)
    .edgeEffect(EdgeEffect.Spring)
  }

  @Builder
  private CategorySection(category: HelpCategory) {
    Column({ space: 10 }) {
      this.SectionTitle(category.title)
      ForEach(category.topics, (topic: HelpTopic) => {
        HelpTopicListItem({
          title: topic.title,
          teaser: topic.teaser,
          geometryId: this.getTopicGeometryId(topic),
          onOpen: (): void => {
            this.openTopic(topic)
          }
        })
      }, (topic: HelpTopic) => topic.key)
    }
    .width('100%')
  }

  @Builder
  private SectionTitle(title: ResourceStr) {
    Text(title)
      .fontSize(14)
      .fontWeight(FontWeight.Medium)
      .fontColor($r('app.color.text_secondary'))
      .padding({ top: 24, bottom: 2 })
      .width('100%')
  }

  @Builder
  private DetailPaneHeader() {
    Column() {
      Row() {
        Text($r('app.string.settings_help_center'))
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
    .transition(this.transitionEffect)
    .onReady((context: NavDestinationContext) => {
      helpCenterPagePathStack = context.pathStack
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
      .transition(this.transitionEffect)
    }
  }
}

@Builder
export function HelpCenterPageBuilder(_name: string, _param: Object) {
  HelpCenterPage({
    hostedInNavDestination: true
  })
}
