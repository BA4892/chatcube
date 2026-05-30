import { curves } from '@kit.ArkUI'
import {
  HdsNavDestination,
  HdsNavDestinationTitleMode
} from '@kit.UIDesignKit'
import { SettingsPagePresentationMode } from '../config/SettingsDetailPresentation'
import { HELP_CATEGORIES, HelpCategory, HelpTopic } from '../config/HelpContent'
import { HelpMarkdownView } from '../components/HelpMarkdownView'
import { getAppUiState } from '../state/AppUiState'
import {
  getHdsStatusBarContentColor,
  getHdsTopNavigationContentTopPadding
} from '../utils/HdsVisualEffectUtil'
import { getSettingsPageContentMaxWidth } from '../utils/SettingsPageLayoutHelper'

export interface HelpTopicDetailRouteParams {
  topicKey?: string
  geometryId?: string
}

let helpTopicDetailPathStack: NavPathStack | null = null

function resolveHelpTopicDetailRouteParams(param: Object): HelpTopicDetailRouteParams {
  return param as HelpTopicDetailRouteParams
}

function findHelpTopic(topicKey: string): HelpTopic | null {
  for (let categoryIndex = 0; categoryIndex < HELP_CATEGORIES.length; categoryIndex++) {
    const category: HelpCategory = HELP_CATEGORIES[categoryIndex]
    for (let topicIndex = 0; topicIndex < category.topics.length; topicIndex++) {
      const topic: HelpTopic = category.topics[topicIndex]
      if (topic.key === topicKey) {
        return topic
      }
    }
  }
  return null
}

@ComponentV2
struct HelpTopicDetailPageContent {
  @Param topicKey: string = ''
  @Param geometryId: string = ''

  private detailScroller: Scroller = new Scroller()

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

  private px2vp(px: number): number {
    return px / (this.getUIContext().getHostContext()?.resourceManager.getDeviceCapabilitySync().screenDensity ?? 3) * 160
  }

  private isDetailPaneMode(): boolean {
    return this.settingsDetailPresentationMode === SettingsPagePresentationMode.DETAIL_PANE
  }

  private getContentMaxWidth(): number {
    return getSettingsPageContentMaxWidth(this.layoutSizeClass, this.windowWidthVp, this.settingsDetailPresentationMode,
      this.windowHeightVp)
  }

  private getTopPadding(): number {
    if (this.isDetailPaneMode()) {
      return 0
    }
    return getHdsTopNavigationContentTopPadding(this.px2vp(this.topAvoidHeight), this.windowWidthVp,
      this.windowHeightVp)
  }

  private getBottomPadding(): number {
    return Math.max(this.px2vp(this.bottomAvoidHeight), 24)
  }

  private getTopic(): HelpTopic | null {
    return findHelpTopic(this.topicKey)
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

  private handleBack(): void {
    if (helpTopicDetailPathStack === null || helpTopicDetailPathStack.size() <= 0) {
      return
    }
    this.getUIContext().animateTo({ curve: curves.interpolatingSpring(0, 1, 342, 38) }, (): void => {
      helpTopicDetailPathStack?.pop(false)
    })
  }

  @Builder
  private DetailHeader(topic: HelpTopic | null) {
    Row({ space: 12 }) {
      Button({ type: ButtonType.Circle, stateEffect: true }) {
        SymbolGlyph($r('sys.symbol.chevron_left'))
          .fontSize(20)
          .fontColor([$r('app.color.text_primary')])
      }
      .width(40)
      .height(40)
      .padding(0)
      .backgroundColor($r('sys.color.comp_background_tertiary'))
      .onClick((): void => {
        this.handleBack()
      })

      Text(topic?.title ?? $r('app.string.settings_help_center'))
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
    }
    .width('100%')
    .height(56)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private DetailBody(topic: HelpTopic | null) {
    if (topic !== null) {
      Text(topic.title)
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .width('100%')

      Text(topic.teaser)
        .fontSize(13)
        .fontColor($r('app.color.text_secondary'))
        .lineHeight(20)
        .width('100%')

      HelpMarkdownView({
        text: topic.markdownBody,
        textSize: 15,
        themeRenderKey: this.getMarkdownThemeRenderKey()
      })
    } else {
      Text($r('app.string.settings_help_center'))
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .width('100%')

      Text('未找到对应帮助内容')
        .fontSize(15)
        .fontColor($r('app.color.text_secondary'))
        .lineHeight(22)
        .width('100%')
    }
  }

  @Builder
  private DetailCard(topic: HelpTopic | null) {
    Column() {
      Scroll(this.detailScroller) {
        Column({ space: 12 }) {
          this.DetailBody(topic)
        }
        .width('100%')
        .padding({ bottom: this.getBottomPadding() })
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .align(Alignment.Top)
    }
    .width('100%')
    .height('100%')
    .padding({ left: 16, right: 16, top: 18, bottom: 0 })
    .backgroundColor($r('sys.color.comp_background_tertiary'))
    .borderRadius(8)
    .clip(true)
    .geometryTransition(this.geometryId)
    .transition(TransitionEffect.OPACITY)
    .layoutWeight(1)
  }

  build() {
    HdsNavDestination() {
      Column() {
        Blank()
          .width('100%')
          .height(this.getTopPadding())

        Row() {
          Column({ space: 14 }) {
            this.DetailHeader(this.getTopic())

            this.DetailCard(this.getTopic())
          }
          .width('100%')
          .height('100%')
          .constraintSize({ maxWidth: this.getContentMaxWidth() })
          .padding({ left: 24, right: 24 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      }
      .width('100%')
      .height('100%')
      .clip(true)
      .backgroundColor(getAppUiState().themeBackground)
      .transition(TransitionEffect.OPACITY)
    }
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .hideTitleBar(true, false)
    .hideToolBar(true)
    .backgroundColor(getAppUiState().themeBackground)
    .systemBarStyle(
      { statusBarContentColor: getHdsStatusBarContentColor() },
      { statusBarContentColor: getHdsStatusBarContentColor() }
    )
    .onReady((context: NavDestinationContext): void => {
      helpTopicDetailPathStack = context.pathStack
    })
    .onBackPressed((): boolean => {
      this.handleBack()
      return true
    })
  }
}

@Builder
export function HelpTopicDetailPageBuilder(_name: string, param: Object) {
  HelpTopicDetailPageContent({
    topicKey: resolveHelpTopicDetailRouteParams(param).topicKey ?? '',
    geometryId: resolveHelpTopicDetailRouteParams(param).geometryId ?? ''
  })
}
