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
  buildPointLightBorderEffect,
  getHdsStatusBarContentColor
} from '../utils/HdsVisualEffectUtil'
import {
  getDatabaseService,
  ModelUsageRankingItem,
  TokenModelRankingItem,
  DailyUsagePoint
} from '../services/DatabaseService'

const TAG = 'UsageStatsPage'
const RANGE_30D_MS: number = 30 * 24 * 60 * 60 * 1000
const RANKING_LIMIT: number = 10
const TREND_DAYS: number = 30
const RANGE_SWIPE_THRESHOLD: number = 72
const RANGE_DRAG_MAX_OFFSET: number = 44
const RANKING_ANIMATION_DELAY_MS: number = 40
const RANKING_ANIMATION_DURATION_MS: number = 640

let usageStatsPagePathStack: NavPathStack | null = null

// 大数字紧凑格式化:>=1e6→x.xM,>=1e4→x.xK,否则原样。避免几十万 token 在卡片里溢出。
// ArkTS 无千分位 API,这里用 toFixed 并去掉多余的 .0
function formatCompactNumber(value: number): string {
  if (value >= 1000000) {
    return stripTrailingZero((value / 1000000).toFixed(1)) + 'M'
  }
  if (value >= 10000) {
    return stripTrailingZero((value / 1000).toFixed(1)) + 'K'
  }
  return value.toString()
}

function stripTrailingZero(text: string): string {
  if (text.endsWith('.0')) {
    return text.substring(0, text.length - 2)
  }
  return text
}

// 排行/趋势展示用的统一数据项(把不同来源的排行映射成 名称 + 数值)
interface RankingDisplayItem {
  name: string
  value: number
}

enum UsageRangeKey {
  ALL = 'all',
  LAST_30D = 'last_30d'
}

@ComponentV2
struct UsageMetricCard {
  @Param icon: Resource = $r('sys.symbol.circle')
  @Param title: ResourceStr = ''
  @Param value: number = 0
  @Param valueText: string = ''
  @Param unit: ResourceStr = ''
  @Param primaryColor: string = '#4E6F9E'
  @Param primaryLightColor: string = '#D8E2EE'
  @Param surfaceColor: string = '#FFFDF8'

  private displayValue(): string {
    return this.valueText !== '' ? this.valueText : this.value.toString()
  }

  build() {
    Column() {
      Row({ space: 8 }) {
        Column() {
          SymbolGlyph(this.icon)
            .fontSize(16)
            .fontColor([this.primaryColor])
        }
        .width(28)
        .height(28)
        .borderRadius(9)
        .backgroundColor(this.primaryLightColor)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)

        Text(this.title)
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Row({ space: 4 }) {
        Text(this.displayValue())
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        Text(this.unit)
          .fontSize(12)
          .fontColor($r('app.color.text_tertiary'))
          .margin({ bottom: 4 })
      }
      .width('100%')
      .margin({ top: 10 })
      .alignItems(VerticalAlign.Bottom)
    }
    .width('100%')
    .padding(14)
    .backgroundColor(this.surfaceColor)
    .borderRadius(16)
    .border({ width: 1, color: $r('app.color.divider') })
    .visualEffect(buildPointLightBorderEffect())
  }
}

// 通用排行榜卡片:名称 + 数值 + 占比进度条。三种排行(模型调用 / Token / 生图)共用。
@ComponentV2
struct RankingListView {
  @Param rows: RankingDisplayItem[] = []
  @Param compact: boolean = false       // true 时数值用 K/M 紧凑格式(Token 排行)
  @Param themePrimary: string = '#4E6F9E'
  @Param surfaceColor: string = '#FFFDF8'
  @Param animationProgress: number = 0

  private getMaxValue(): number {
    let max = 0
    for (let i = 0; i < this.rows.length; i++) {
      if (this.rows[i].value > max) {
        max = this.rows[i].value
      }
    }
    return max
  }

  private getFraction(value: number): number {
    const max = this.getMaxValue()
    if (max <= 0) {
      return 0
    }
    const fraction = value / max
    return fraction < 0.04 ? 0.04 : fraction
  }

  private getAnimatedFraction(value: number): number {
    return this.getFraction(value) * this.animationProgress
  }

  private getAnimatedValueText(value: number): string {
    const animated = this.animationProgress >= 1 ? value : Math.floor(value * this.animationProgress)
    return this.compact ? formatCompactNumber(animated) : animated.toString()
  }

  @Builder
  private Row1(item: RankingDisplayItem, rank: number) {
    Column({ space: 8 }) {
      Row() {
        Text(`${rank}`)
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor(rank <= 3 ? this.themePrimary : $r('app.color.text_tertiary'))
          .width(22)

        Text(item.name)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(this.getAnimatedValueText(item.value))
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_secondary'))
          .margin({ left: 8 })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Stack({ alignContent: Alignment.Start }) {
        Column()
          .width('100%')
          .height(6)
          .borderRadius(3)
          .backgroundColor($r('app.color.divider'))

        Column()
          .width(`${this.getAnimatedFraction(item.value) * 100}%`)
          .height(6)
          .borderRadius(3)
          .backgroundColor(this.themePrimary)
      }
      .width('100%')
      .margin({ left: 22 })
    }
    .width('100%')
    .padding({ top: 10, bottom: 10, left: 14, right: 14 })
  }

  build() {
    Column() {
      ForEach(this.rows, (item: RankingDisplayItem, index: number) => {
        Column() {
          this.Row1(item, index + 1)
          if (index < this.rows.length - 1) {
            Divider()
              .color($r('app.color.divider'))
              .margin({ left: 50, right: 14 })
          }
        }
      }, (item: RankingDisplayItem, index: number) => `${index}_${item.name}_${item.value}`)
    }
    .width('100%')
    .backgroundColor(this.surfaceColor)
    .borderRadius(18)
    .clip(true)
    .border({ width: 1, color: $r('app.color.divider') })
    .visualEffect(buildPointLightBorderEffect())
  }
}

// 近 N 天每日用量柱状趋势图。沿用排行进度条的视觉语言(圆角条 + 主题色 + 入场动画)。
@ComponentV2
struct UsageTrendChart {
  @Param points: DailyUsagePoint[] = []
  @Param compact: boolean = false       // 峰值标注是否用 K/M(Token 用)
  @Param themePrimary: string = '#4E6F9E'
  @Param themePrimaryLight: string = '#D8E2EE'
  @Param surfaceColor: string = '#FFFDF8'
  @Param animationProgress: number = 0

  private static readonly BAR_AREA_HEIGHT: number = 96
  private static readonly MIN_BAR_HEIGHT: number = 3

  private getMaxValue(): number {
    let max = 0
    for (let i = 0; i < this.points.length; i++) {
      if (this.points[i].value > max) {
        max = this.points[i].value
      }
    }
    return max
  }

  private getBarHeight(value: number): number {
    const max = this.getMaxValue()
    if (max <= 0) {
      return UsageTrendChart.MIN_BAR_HEIGHT
    }
    const h = (value / max) * UsageTrendChart.BAR_AREA_HEIGHT * this.animationProgress
    return h < UsageTrendChart.MIN_BAR_HEIGHT ? UsageTrendChart.MIN_BAR_HEIGHT : h
  }

  // YYYY-MM-DD -> MM-DD
  private shortDay(day: string): string {
    return day.length >= 10 ? day.substring(5) : day
  }

  private firstDay(): string {
    return this.points.length > 0 ? this.shortDay(this.points[0].day) : ''
  }

  private midDay(): string {
    return this.points.length > 0 ? this.shortDay(this.points[Math.floor(this.points.length / 2)].day) : ''
  }

  private lastDay(): string {
    return this.points.length > 0 ? this.shortDay(this.points[this.points.length - 1].day) : ''
  }

  private peakText(): string {
    const max = this.getMaxValue()
    return this.compact ? formatCompactNumber(max) : max.toString()
  }

  build() {
    Column() {
      Row() {
        Text($r('app.string.usage_stats_trend_peak'))
          .fontSize(11)
          .fontColor($r('app.color.text_tertiary'))
        Text(this.peakText())
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.themePrimary)
          .margin({ left: 4 })
        Blank()
      }
      .width('100%')

      Row({ space: 2 }) {
        ForEach(this.points, (point: DailyUsagePoint) => {
          Column()
            .layoutWeight(1)
            .height(this.getBarHeight(point.value))
            .borderRadius(2)
            .backgroundColor(point.value > 0 ? this.themePrimary : this.themePrimaryLight)
        }, (point: DailyUsagePoint, index: number) => `${index}_${point.day}_${point.value}`)
      }
      .width('100%')
      .height(UsageTrendChart.BAR_AREA_HEIGHT)
      .alignItems(VerticalAlign.Bottom)
      .margin({ top: 10 })

      Row() {
        Text(this.firstDay())
          .fontSize(10)
          .fontColor($r('app.color.text_tertiary'))
        Blank()
        Text(this.midDay())
          .fontSize(10)
          .fontColor($r('app.color.text_tertiary'))
        Blank()
        Text(this.lastDay())
          .fontSize(10)
          .fontColor($r('app.color.text_tertiary'))
      }
      .width('100%')
      .margin({ top: 8 })
    }
    .width('100%')
    .padding(14)
    .backgroundColor(this.surfaceColor)
    .borderRadius(18)
    .border({ width: 1, color: $r('app.color.divider') })
    .visualEffect(buildPointLightBorderEffect())
  }
}

@Entry
@ComponentV2
struct UsageStatsPage {
  @Param hostedInNavDestination: boolean = false
  private get topAvoidHeight(): number {
    return getAppUiState().topAvoidHeight
  }
  private get themePrimary(): string {
    return getAppUiState().themePrimary
  }
  private get themePrimaryLight(): string {
    return getAppUiState().themePrimaryLight
  }
  private get themeBackground(): string {
    return getAppUiState().themeBackground
  }
  private get themeSurface(): string {
    return getAppUiState().themeSurface
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

  @Local currentRange: UsageRangeKey = UsageRangeKey.ALL
  @Local sessionCount: number = 0
  @Local messageCount: number = 0
  @Local distinctModelCount: number = 0
  @Local activeDayCount: number = 0
  @Local ranking: ModelUsageRankingItem[] = []
  // Token 用量
  @Local totalTokens: number = 0
  @Local inputTokens: number = 0
  @Local outputTokens: number = 0
  @Local avgTokensPerReply: number = 0
  @Local tokenRanking: TokenModelRankingItem[] = []
  @Local tokenTrend: DailyUsagePoint[] = []
  // 生图统计
  @Local imageTotal: number = 0
  @Local imageGenerate: number = 0
  @Local imageEdit: number = 0
  @Local imageModelCount: number = 0
  @Local imageRanking: ModelUsageRankingItem[] = []
  @Local imageTrend: DailyUsagePoint[] = []
  @Local isLoading: boolean = true
  @Local rankingAnimationProgress: number = 0
  @Local rangeSwipeOffsetX: number = 0

  private compactScroller: Scroller = new Scroller()
  private statsLoadToken: number = 0
  private rankingAnimationTimer: number = -1
  private rangePanDirection: string = 'none'

  private px2vp(px: number): number {
    return px / (this.getUIContext().getHostContext()?.resourceManager.getDeviceCapabilitySync().screenDensity ?? 3) * 160
  }

  aboutToAppear(): void {
    this.loadStats()
  }

  aboutToDisappear(): void {
    this.clearRankingAnimationTimer()
  }

  private getRangeStartMs(): number {
    if (this.currentRange === UsageRangeKey.LAST_30D) {
      return Date.now() - RANGE_30D_MS
    }
    return 0
  }

  private async loadStats(): Promise<void> {
    const loadToken = this.statsLoadToken + 1
    this.statsLoadToken = loadToken
    this.isLoading = true
    this.rankingAnimationProgress = 0
    this.clearRankingAnimationTimer()
    try {
      const db = getDatabaseService()
      const rangeStart = this.getRangeStartMs()
      const overview = await db.getUsageOverview(rangeStart)
      const ranking = await db.getModelUsageRanking(rangeStart, RANKING_LIMIT)
      const tokenRanking = await db.getTokenModelRanking(rangeStart, RANKING_LIMIT)
      const imageStats = await db.getImageGenerationStats(rangeStart)
      const imageRanking = await db.getImageModelRanking(rangeStart, RANKING_LIMIT)
      // 趋势固定"近 N 天",不随 ALL / 近30天 切换变化
      const tokenTrend = await db.getTokenDailyTrend(TREND_DAYS)
      const imageTrend = await db.getImageDailyTrend(TREND_DAYS)
      if (loadToken !== this.statsLoadToken) {
        return
      }
      this.sessionCount = overview.sessionCount
      this.messageCount = overview.messageCount
      this.distinctModelCount = overview.distinctModelCount
      this.activeDayCount = overview.activeDayCount
      this.ranking = ranking
      this.totalTokens = overview.totalTokens
      this.inputTokens = overview.inputTokens
      this.outputTokens = overview.outputTokens
      this.avgTokensPerReply = overview.tokenMessageCount > 0 ?
        Math.round(overview.totalTokens / overview.tokenMessageCount) : 0
      this.tokenRanking = tokenRanking
      this.tokenTrend = tokenTrend
      this.imageTotal = imageStats.total
      this.imageGenerate = imageStats.generateCount
      this.imageEdit = imageStats.editCount
      this.imageModelCount = imageStats.distinctModelCount
      this.imageRanking = imageRanking
      this.imageTrend = imageTrend
      this.startRankingAnimation()
    } catch (error) {
      console.error(TAG, `Failed to load usage stats: ${JSON.stringify(error)}`)
    } finally {
      if (loadToken === this.statsLoadToken) {
        this.isLoading = false
      }
    }
  }

  private clearRankingAnimationTimer(): void {
    if (this.rankingAnimationTimer !== -1) {
      clearTimeout(this.rankingAnimationTimer)
      this.rankingAnimationTimer = -1
    }
  }

  private startRankingAnimation(): void {
    this.clearRankingAnimationTimer()
    if (this.isEmpty()) {
      this.rankingAnimationProgress = 1
      return
    }
    this.rankingAnimationTimer = setTimeout((): void => {
      this.rankingAnimationTimer = -1
      this.getUIContext().animateTo({ duration: RANKING_ANIMATION_DURATION_MS, curve: Curve.EaseOut }, () => {
        this.rankingAnimationProgress = 1
      })
    }, RANKING_ANIMATION_DELAY_MS)
  }

  private getContentMaxWidth(): number {
    return getSettingsPageContentMaxWidth(this.layoutSizeClass, this.windowWidthVp, this.settingsDetailPresentationMode,
      this.windowHeightVp)
  }

  private isDetailPaneMode(): boolean {
    return this.settingsDetailPresentationMode === SettingsPagePresentationMode.DETAIL_PANE
  }

  private handleBack(): void {
    if (usageStatsPagePathStack !== null && usageStatsPagePathStack.size() > 0) {
      usageStatsPagePathStack.pop()
    }
  }

  private getCompactContentTopPadding(): number {
    return getHdsTopNavigationContentTopPadding(this.px2vp(this.topAvoidHeight), this.windowWidthVp,
      this.windowHeightVp)
  }

  private getCompactTitleBarOptions(): HdsNavigationTitleBarOptions {
    return buildHdsTopNavigationTitleBarOptionsForNativePage(this.materialType, this.materialLevel, this.windowWidthVp,
      this.windowHeightVp, $r('app.string.settings_usage_stats'), (): void => {
        this.handleBack()
      })
  }

  private displayModelName(modelName: string, modelId: string): string {
    if (modelName !== '') {
      return modelName
    }
    if (modelId !== '') {
      return modelId
    }
    return '—'
  }

  private modelRankingRows(): RankingDisplayItem[] {
    const rows: RankingDisplayItem[] = []
    for (let i = 0; i < this.ranking.length; i++) {
      const item = this.ranking[i]
      rows.push({ name: this.displayModelName(item.modelName, item.modelId), value: item.count })
    }
    return rows
  }

  private tokenRankingRows(): RankingDisplayItem[] {
    const rows: RankingDisplayItem[] = []
    for (let i = 0; i < this.tokenRanking.length; i++) {
      const item = this.tokenRanking[i]
      rows.push({ name: this.displayModelName(item.modelName, item.modelId), value: item.totalTokens })
    }
    return rows
  }

  private imageRankingRows(): RankingDisplayItem[] {
    const rows: RankingDisplayItem[] = []
    for (let i = 0; i < this.imageRanking.length; i++) {
      const item = this.imageRanking[i]
      rows.push({ name: this.displayModelName(item.modelName, item.modelId), value: item.count })
    }
    return rows
  }

  private hasTrendData(points: DailyUsagePoint[]): boolean {
    for (let i = 0; i < points.length; i++) {
      if (points[i].value > 0) {
        return true
      }
    }
    return false
  }

  private isEmpty(): boolean {
    return this.messageCount === 0 && this.ranking.length === 0 && this.imageTotal === 0
  }

  private switchRange(rangeKey: UsageRangeKey): void {
    if (this.currentRange === rangeKey) {
      return
    }
    this.getUIContext().animateTo({ duration: 180, curve: Curve.EaseInOut }, () => {
      this.currentRange = rangeKey
      this.rangeSwipeOffsetX = 0
      this.rankingAnimationProgress = 0
    })
    this.loadStats()
  }

  private getRangeBySwipeOffset(offsetX: number): UsageRangeKey | null {
    if (offsetX <= -RANGE_SWIPE_THRESHOLD && this.currentRange === UsageRangeKey.ALL) {
      return UsageRangeKey.LAST_30D
    }
    if (offsetX >= RANGE_SWIPE_THRESHOLD && this.currentRange === UsageRangeKey.LAST_30D) {
      return UsageRangeKey.ALL
    }
    return null
  }

  private getDampedRangeSwipeOffset(offsetX: number): number {
    let offset = offsetX * 0.18
    if ((this.currentRange === UsageRangeKey.ALL && offset > 0) ||
      (this.currentRange === UsageRangeKey.LAST_30D && offset < 0)) {
      offset = offset * 0.35
    }
    if (offset > RANGE_DRAG_MAX_OFFSET) {
      return RANGE_DRAG_MAX_OFFSET
    }
    if (offset < -RANGE_DRAG_MAX_OFFSET) {
      return -RANGE_DRAG_MAX_OFFSET
    }
    return offset
  }

  private handleRangeSwipeStart(): void {
    this.rangePanDirection = 'none'
  }

  private handleRangeSwipeUpdate(event: GestureEvent): void {
    const absX = Math.abs(event.offsetX)
    const absY = Math.abs(event.offsetY)
    if (this.rangePanDirection === 'none' && (absX > 12 || absY > 12)) {
      this.rangePanDirection = absX > absY * 1.25 ? 'horizontal' : 'vertical'
    }
    if (this.rangePanDirection !== 'horizontal') {
      return
    }
    this.rangeSwipeOffsetX = this.getDampedRangeSwipeOffset(event.offsetX)
  }

  private handleRangeSwipeEnd(event: GestureEvent): void {
    const nextRange = this.rangePanDirection === 'horizontal' ? this.getRangeBySwipeOffset(event.offsetX) : null
    this.rangePanDirection = 'none'
    this.getUIContext().animateTo({ duration: 180, curve: Curve.EaseOut }, () => {
      this.rangeSwipeOffsetX = 0
    })
    if (nextRange !== null) {
      this.switchRange(nextRange)
    }
  }

  @Builder
  private DetailPaneHeader() {
    Column() {
      Row() {
        Text($r('app.string.settings_usage_stats'))
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
    .backgroundColor(this.themeBackground)
    .border({ width: { bottom: 1 }, color: $r('app.color.divider') })
  }

  @Builder
  private RangeTabButton(rangeKey: UsageRangeKey, title: ResourceStr) {
    Button() {
      Column({ space: 6 }) {
        Text(title)
          .fontSize(15)
          .fontWeight(this.currentRange === rangeKey ? FontWeight.Bold : FontWeight.Medium)
          .fontColor(this.currentRange === rangeKey ? $r('app.color.text_primary') : $r('app.color.text_secondary'))
          .animation({ duration: 180, curve: Curve.EaseOut })

        Column()
          .width(this.currentRange === rangeKey ? 24 : 14)
          .height(3)
          .borderRadius(2)
          .backgroundColor(this.currentRange === rangeKey ? this.themePrimary : Color.Transparent)
          .animation({ duration: 180, curve: Curve.EaseOut })
      }
      .alignItems(HorizontalAlign.Start)
    }
    .type(ButtonType.Normal)
    .stateEffect(false)
    .padding({ left: 0, right: 0, top: 4, bottom: 4 })
    .backgroundColor(Color.Transparent)
    .onClick(() => {
      this.switchRange(rangeKey)
    })
  }

  @Builder
  private RangeTabs() {
    Row({ space: 20 }) {
      this.RangeTabButton(UsageRangeKey.ALL, $r('app.string.usage_stats_range_all'))
      this.RangeTabButton(UsageRangeKey.LAST_30D, $r('app.string.usage_stats_range_30d'))
      Blank()
    }
    .width('100%')
    .padding({ left: 4, right: 4, top: 8, bottom: 8 })
  }

  @Builder
  private SectionTitle(title: ResourceStr, subtitle: ResourceStr | null) {
    Column({ space: 2 }) {
      Text(title)
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_secondary'))
      if (subtitle !== null) {
        Text(subtitle)
          .fontSize(11)
          .fontColor($r('app.color.text_tertiary'))
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 4, bottom: 6 })
  }

  @Builder
  private MetricsGrid() {
    Column({ space: 10 }) {
      Row({ space: 10 }) {
        Column() {
          UsageMetricCard({
            icon: $r('sys.symbol.message'),
            title: $r('app.string.usage_stats_metric_sessions'),
            value: this.sessionCount,
            unit: $r('app.string.usage_stats_unit_count'),
            primaryColor: this.themePrimary,
            primaryLightColor: this.themePrimaryLight,
            surfaceColor: this.themeSurface
          })
        }.layoutWeight(1)
        Column() {
          UsageMetricCard({
            icon: $r('sys.symbol.ellipsis_message'),
            title: $r('app.string.usage_stats_metric_messages'),
            value: this.messageCount,
            unit: $r('app.string.usage_stats_unit_count'),
            primaryColor: this.themePrimary,
            primaryLightColor: this.themePrimaryLight,
            surfaceColor: this.themeSurface
          })
        }.layoutWeight(1)
      }
      .width('100%')

      Row({ space: 10 }) {
        Column() {
          UsageMetricCard({
            icon: $r('sys.symbol.square_stack_3d'),
            title: $r('app.string.usage_stats_metric_models'),
            value: this.distinctModelCount,
            unit: $r('app.string.usage_stats_unit_count'),
            primaryColor: this.themePrimary,
            primaryLightColor: this.themePrimaryLight,
            surfaceColor: this.themeSurface
          })
        }.layoutWeight(1)
        Column() {
          UsageMetricCard({
            icon: $r('sys.symbol.calendar'),
            title: $r('app.string.usage_stats_metric_active_days'),
            value: this.activeDayCount,
            unit: $r('app.string.usage_stats_unit_day'),
            primaryColor: this.themePrimary,
            primaryLightColor: this.themePrimaryLight,
            surfaceColor: this.themeSurface
          })
        }.layoutWeight(1)
      }
      .width('100%')
    }
    .width('100%')
  }

  @Builder
  private TokenMetricsGrid() {
    Column({ space: 10 }) {
      Row({ space: 10 }) {
        Column() {
          UsageMetricCard({
            icon: $r('sys.symbol.character_textbox'),
            title: $r('app.string.usage_stats_metric_total_tokens'),
            valueText: formatCompactNumber(this.totalTokens),
            unit: $r('app.string.usage_stats_unit_token'),
            primaryColor: this.themePrimary,
            primaryLightColor: this.themePrimaryLight,
            surfaceColor: this.themeSurface
          })
        }.layoutWeight(1)
        Column() {
          UsageMetricCard({
            icon: $r('sys.symbol.chevron_up'),
            title: $r('app.string.usage_stats_metric_input_tokens'),
            valueText: formatCompactNumber(this.inputTokens),
            unit: $r('app.string.usage_stats_unit_token'),
            primaryColor: this.themePrimary,
            primaryLightColor: this.themePrimaryLight,
            surfaceColor: this.themeSurface
          })
        }.layoutWeight(1)
      }
      .width('100%')

      Row({ space: 10 }) {
        Column() {
          UsageMetricCard({
            icon: $r('sys.symbol.chevron_down'),
            title: $r('app.string.usage_stats_metric_output_tokens'),
            valueText: formatCompactNumber(this.outputTokens),
            unit: $r('app.string.usage_stats_unit_token'),
            primaryColor: this.themePrimary,
            primaryLightColor: this.themePrimaryLight,
            surfaceColor: this.themeSurface
          })
        }.layoutWeight(1)
        Column() {
          UsageMetricCard({
            icon: $r('sys.symbol.ellipsis_message'),
            title: $r('app.string.usage_stats_metric_avg_tokens'),
            valueText: formatCompactNumber(this.avgTokensPerReply),
            unit: $r('app.string.usage_stats_unit_token'),
            primaryColor: this.themePrimary,
            primaryLightColor: this.themePrimaryLight,
            surfaceColor: this.themeSurface
          })
        }.layoutWeight(1)
      }
      .width('100%')
    }
    .width('100%')
  }

  @Builder
  private ImageMetricsGrid() {
    Column({ space: 10 }) {
      Row({ space: 10 }) {
        Column() {
          UsageMetricCard({
            icon: $r('sys.symbol.picture'),
            title: $r('app.string.usage_stats_metric_image_total'),
            value: this.imageTotal,
            unit: $r('app.string.usage_stats_unit_image'),
            primaryColor: this.themePrimary,
            primaryLightColor: this.themePrimaryLight,
            surfaceColor: this.themeSurface
          })
        }.layoutWeight(1)
        Column() {
          UsageMetricCard({
            icon: $r('sys.symbol.wand_and_stars'),
            title: $r('app.string.usage_stats_metric_image_generate'),
            value: this.imageGenerate,
            unit: $r('app.string.usage_stats_unit_image'),
            primaryColor: this.themePrimary,
            primaryLightColor: this.themePrimaryLight,
            surfaceColor: this.themeSurface
          })
        }.layoutWeight(1)
      }
      .width('100%')

      Row({ space: 10 }) {
        Column() {
          UsageMetricCard({
            icon: $r('sys.symbol.picture_star_fill'),
            title: $r('app.string.usage_stats_metric_image_edit'),
            value: this.imageEdit,
            unit: $r('app.string.usage_stats_unit_image'),
            primaryColor: this.themePrimary,
            primaryLightColor: this.themePrimaryLight,
            surfaceColor: this.themeSurface
          })
        }.layoutWeight(1)
        Column() {
          UsageMetricCard({
            icon: $r('sys.symbol.square_stack_3d'),
            title: $r('app.string.usage_stats_metric_image_models'),
            value: this.imageModelCount,
            unit: $r('app.string.usage_stats_unit_count'),
            primaryColor: this.themePrimary,
            primaryLightColor: this.themePrimaryLight,
            surfaceColor: this.themeSurface
          })
        }.layoutWeight(1)
      }
      .width('100%')
    }
    .width('100%')
  }

  @Builder
  private EmptyState() {
    Column({ space: 8 }) {
      SymbolGlyph($r('sys.symbol.exclamationmark_circle'))
        .fontSize(48)
        .fontColor([$r('app.color.text_tertiary')])
        .margin({ bottom: 4 })
      Text($r('app.string.usage_stats_empty_title'))
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_secondary'))
      Text($r('app.string.usage_stats_empty_desc'))
        .fontSize(13)
        .fontColor($r('app.color.text_tertiary'))
        .textAlign(TextAlign.Center)
        .padding({ left: 24, right: 24 })
    }
    .width('100%')
    .padding({ top: 64, bottom: 64 })
    .alignItems(HorizontalAlign.Center)
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

          this.RangeTabs()

          if (this.isEmpty() && !this.isLoading) {
            this.EmptyState()
          } else {
            // 总览
            Column() {
              this.SectionTitle($r('app.string.usage_stats_overview_title'), null)
              this.MetricsGrid()
            }
            .width('100%')
            .margin({ top: 6 })

            // 模型调用排行
            if (this.ranking.length > 0) {
              Column() {
                this.SectionTitle($r('app.string.usage_stats_ranking_title'),
                  $r('app.string.usage_stats_ranking_subtitle'))
                RankingListView({
                  rows: this.modelRankingRows(),
                  compact: false,
                  themePrimary: this.themePrimary,
                  surfaceColor: this.themeSurface,
                  animationProgress: this.rankingAnimationProgress
                })
              }
              .width('100%')
              .margin({ top: 18 })
            }

            // Token 用量
            if (this.totalTokens > 0) {
              Column() {
                this.SectionTitle($r('app.string.usage_stats_token_overview_title'),
                  $r('app.string.usage_stats_token_overview_subtitle'))
                this.TokenMetricsGrid()
              }
              .width('100%')
              .margin({ top: 18 })

              if (this.tokenRanking.length > 0) {
                Column() {
                  this.SectionTitle($r('app.string.usage_stats_token_ranking_title'),
                    $r('app.string.usage_stats_token_ranking_subtitle'))
                  RankingListView({
                    rows: this.tokenRankingRows(),
                    compact: true,
                    themePrimary: this.themePrimary,
                    surfaceColor: this.themeSurface,
                    animationProgress: this.rankingAnimationProgress
                  })
                }
                .width('100%')
                .margin({ top: 18 })
              }

              if (this.hasTrendData(this.tokenTrend)) {
                Column() {
                  this.SectionTitle($r('app.string.usage_stats_token_trend_title'), null)
                  UsageTrendChart({
                    points: this.tokenTrend,
                    compact: true,
                    themePrimary: this.themePrimary,
                    themePrimaryLight: this.themePrimaryLight,
                    surfaceColor: this.themeSurface,
                    animationProgress: this.rankingAnimationProgress
                  })
                }
                .width('100%')
                .margin({ top: 18 })
              }
            }

            // AI 生图
            if (this.imageTotal > 0) {
              Column() {
                this.SectionTitle($r('app.string.usage_stats_image_overview_title'), null)
                this.ImageMetricsGrid()
              }
              .width('100%')
              .margin({ top: 18 })

              if (this.imageRanking.length > 0) {
                Column() {
                  this.SectionTitle($r('app.string.usage_stats_image_ranking_title'),
                    $r('app.string.usage_stats_image_ranking_subtitle'))
                  RankingListView({
                    rows: this.imageRankingRows(),
                    compact: false,
                    themePrimary: this.themePrimary,
                    surfaceColor: this.themeSurface,
                    animationProgress: this.rankingAnimationProgress
                  })
                }
                .width('100%')
                .margin({ top: 18 })
              }

              if (this.hasTrendData(this.imageTrend)) {
                Column() {
                  this.SectionTitle($r('app.string.usage_stats_image_trend_title'), null)
                  UsageTrendChart({
                    points: this.imageTrend,
                    compact: false,
                    themePrimary: this.themePrimary,
                    themePrimaryLight: this.themePrimaryLight,
                    surfaceColor: this.themeSurface,
                    animationProgress: this.rankingAnimationProgress
                  })
                }
                .width('100%')
                .margin({ top: 18 })
              }
            }
          }

          Blank().width('100%').height(28)
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
    .translate({ x: this.rangeSwipeOffsetX, y: 0 })
    .parallelGesture(
      PanGesture({ fingers: 1, distance: 18 })
        .onActionStart(() => {
          this.handleRangeSwipeStart()
        })
        .onActionUpdate((event: GestureEvent) => {
          this.handleRangeSwipeUpdate(event)
        })
        .onActionEnd((event: GestureEvent) => {
          this.handleRangeSwipeEnd(event)
        })
    )
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
    .backgroundColor(this.themeBackground)
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
    .backgroundColor(this.themeBackground)
    .onReady((context: NavDestinationContext) => {
      usageStatsPagePathStack = context.pathStack
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
      .backgroundColor(this.themeBackground)
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
export function UsageStatsPageBuilder(name: string, param: Object) {
  UsageStatsPage({
    hostedInNavDestination: true
  })
}
