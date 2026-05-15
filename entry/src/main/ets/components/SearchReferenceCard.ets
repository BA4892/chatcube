import { SearchReference } from '../models/ChatModels'
import { webview } from '@kit.ArkWeb'
import { getAppUiState } from '../state/AppUiState'
import { withColorAlpha } from '../utils/ColorAlphaUtils'

@ComponentV2
export struct SearchReferenceCard {
  @Param query: string = ''
  @Param searchEngine: string = ''
  @Param references: SearchReference[] = []
  @Param sourceLabel: string = ''
  // 初始展开态, 流式场景(AI 还在生成)传 true 可以自动展开卡片列表让用户看到结果
  @Param initialExpanded: boolean = false
  @Local isExpanded: boolean = false
  @Local private hasAppliedInitial: boolean = false
  @Local private userToggled: boolean = false
  @Local showWebSheet: boolean = false
  @Local sheetUrl: string = ''
  @Local sheetTitle: string = ''
  private sheetWebController: webview.WebviewController = new webview.WebviewController()
  private get isDarkMode(): boolean {
    return getAppUiState().isDarkMode
  }
  private get themePrimary(): string {
    return getAppUiState().themePrimary
  }
  private get themePrimarySubtleBackground(): string {
    return withColorAlpha(this.themePrimary, this.isDarkMode ? '28' : '16')
  }

  aboutToAppear(): void {
    if (this.initialExpanded && !this.hasAppliedInitial) {
      this.isExpanded = true
      this.hasAppliedInitial = true
    }
  }

  // 流式中 initialExpanded=true 打开, 生成结束 initialExpanded=false 时若用户没手动切过就自动收起,
  // 避免屏幕上堆着一串独立结果卡片降低可读性
  @Monitor('initialExpanded')
  onInitialExpandedChange(): void {
    if (this.userToggled) {
      return
    }
    if (this.initialExpanded) {
      this.isExpanded = true
    } else {
      this.isExpanded = false
    }
  }

  // 获取引用数量文本
  private getReferenceCountText(): string {
    return `${this.references.length}`
  }

  // 统一格式化展示的搜索关键词（单行、去掉多余空白）
  private getDisplayQuery(): string {
    const trimmed = this.query.trim()
    if (trimmed === '') {
      return ''
    }
    return trimmed.replace(/\s+/g, ' ')
  }

  // 获取阴影颜色（根据深浅模式）
  private getShadowColor(): ResourceColor {
    return this.isDarkMode ? 'rgba(255, 255, 255, 0.08)' : 'rgba(0, 0, 0, 0.12)'
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // ========== 悬浮联网查询标签 ==========
      Row() {
        // 联网搜索图标
        SymbolGlyph($r('sys.symbol.magnifyingglass'))
          .fontSize(13)
          .fontColor([this.themePrimary])

        // 标题文本
        Text($r('app.string.web_search'))
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(getAppUiState().themeTextSecondary)
          .margin({ left: 4 })

        // 来源标签（区分：Function Calling vs 手动搜索链路）
        if (this.sourceLabel.trim() !== '') {
          Text(this.sourceLabel.trim())
            .fontSize(11)
            .fontColor(getAppUiState().themeTextTertiary)
            .margin({ left: 6 })
        }

        if (this.searchEngine.trim() !== '') {
          Text(this.searchEngine.trim())
            .fontSize(11)
            .fontColor(this.themePrimary)
            .padding({ left: 6, right: 6, top: 1, bottom: 1 })
            .borderRadius(8)
            .backgroundColor(this.themePrimarySubtleBackground)
            .margin({ left: 6 })
        }

        // 实际搜索关键词（占据剩余空间，便于排查工具入参）
        if (this.getDisplayQuery() !== '') {
          Text(this.getDisplayQuery())
            .fontSize(12)
            .fontColor(getAppUiState().themeTextTertiary)
            .margin({ left: 8 })
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
        } else {
          Text('')
            .layoutWeight(1)
        }

        // 分隔线
        Row()
          .width(1)
          .height(10)
          .backgroundColor(getAppUiState().themeDivider)
          .margin({ left: 8, right: 8 })

        // 引用数量
        Text(this.getReferenceCountText())
          .fontSize(12)
          .fontColor(getAppUiState().themeTextSecondary)

        // 展开/折叠箭头
        SymbolGlyph(this.isExpanded ? $r('sys.symbol.chevron_up') : $r('sys.symbol.chevron_down'))
          .fontSize(12)
          .fontColor([getAppUiState().themeTextTertiary])
          .margin({ left: 6 })
          .width(12)
          .height(12)
      }
      .height(28)
      .padding({ left: 10, right: 10 })
      .borderRadius(14)
      .clip(true)
      .shadow({
        radius: 8,
        color: this.getShadowColor(),
        offsetX: 0,
        offsetY: 2
      })
      .stateStyles({
        normal: {
          .backgroundColor(getAppUiState().themeSurface)
        },
        pressed: {
          .backgroundColor(getAppUiState().themeDivider)
        }
      })
      .onClick(() => {
        this.userToggled = true
        this.getUIContext().animateTo({ duration: 200, curve: Curve.EaseInOut }, () => {
          this.isExpanded = !this.isExpanded
        })
      })

      // 引用列表（可折叠）
      if (this.isExpanded) {
        Column({ space: 0 }) {
          ForEach(this.references, (ref: SearchReference, index: number) => {
            this.ReferenceItem(ref, index + 1)
          }, (ref: SearchReference) => ref.id)
        }
        .width('100%')
        .margin({ top: 36 })
        .clip(true)
      }
    }
    .width('100%')
    .alignContent(Alignment.TopStart)
    .bindSheet($$this.showWebSheet, this.WebSheetBuilder(), {
      height: SheetSize.LARGE,
      detents: [SheetSize.LARGE],
      dragBar: true,
      showClose: true,
      title: { title: this.sheetTitle !== '' ? this.sheetTitle : $r('app.string.common_web_page') },
      onDisappear: () => {
        this.sheetUrl = ''
        this.sheetTitle = ''
      }
    })
  }

  @Builder
  WebSheetBuilder() {
    Column() {
      if (this.sheetUrl !== '') {
        Web({ src: this.sheetUrl, controller: this.sheetWebController })
          .width('100%')
          .layoutWeight(1)
      } else {
        Column() {
          Text($r('app.string.common_invalid_link'))
            .fontSize(14)
            .fontColor(getAppUiState().themeTextSecondary)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(getAppUiState().themeBackground)
  }

  @Builder
  ReferenceItem(ref: SearchReference, index: number) {
    Column({ space: 6 }) {
      // 标题行：序号 + 标题
      Row({ space: 8 }) {
        // 序号圆圈
        Text(`${index}`)
          .fontSize(11)
          .fontColor(Color.White)
          .fontWeight(FontWeight.Medium)
          .width(20)
          .height(20)
          .textAlign(TextAlign.Center)
          .borderRadius(10)
          .backgroundColor(this.themePrimary)

        // 标题
        Text(ref.title)
          .fontSize(14)
          .fontColor(getAppUiState().themeTextPrimary)
          .fontWeight(FontWeight.Medium)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
      }
      .width('100%')

      // 摘要
      if (ref.snippet !== '') {
        Text(ref.snippet)
          .fontSize(12)
          .fontColor(getAppUiState().themeTextSecondary)
          .lineHeight(18)
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ left: 28 })
      }

      // URL
      Text(ref.url)
        .fontSize(11)
        .fontColor(getAppUiState().themeTextTertiary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ left: 28 })
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 12, bottom: 12 })
    .borderRadius(14)
    .margin({ bottom: 8 })
    .border({ width: 0.5, color: getAppUiState().themeDivider })
    .stateStyles({
      normal: {
        .backgroundColor(getAppUiState().themeSurface)
      },
      pressed: {
        .backgroundColor(getAppUiState().themeDivider)
      }
    })
    .onClick(() => {
      this.sheetUrl = ref.url
      this.sheetTitle = ref.title
      this.showWebSheet = true
    })
  }
}
