/**
 * ChatCube 加载动效预览页 (DEV)
 *
 * 用于设计阶段评审 CubeSpinner 的 A/B/C/D 四种变体, 不在正式 UI 入口暴露,
 * 通过 AboutPage 版本号 5 连点进入。定稿后此页面可保留作为内部 design system 文档,
 * 也可直接删除 (同时清理 router_map.json 注册与 AboutPage 隐藏入口)。
 */

import {
  CubeSpinnerLight,
  CubeSpinnerBubble,
  CubeSpinnerAssemble,
  CubeSpinner3D
} from '../components/loading/CubeSpinner'
import { getAppUiState } from '../state/AppUiState'

let cubeSpinnerPreviewPathStack: NavPathStack | null = null

type PreviewBackground = 'light' | 'bubble' | 'dark'
type PreviewVariant = 'A' | 'B' | 'C' | 'D'
type PreviewComparison = 'title' | 'imagegen'

@Entry
@ComponentV2
struct CubeSpinnerPreview {
  @Local private bgVariant: PreviewBackground = 'light'

  private get themePrimary(): string {
    return getAppUiState().themePrimary
  }

  private get themePrimaryLight(): string {
    return getAppUiState().themePrimaryLight
  }

  private get themeBackground(): string {
    return getAppUiState().themeBackground
  }

  private get themeAiBubble(): string {
    return getAppUiState().themeAiBubble
  }

  private get themeSurface(): string {
    return getAppUiState().themeSurface
  }

  private getStageColor(): string {
    if (this.bgVariant === 'dark') {
      return '#1F1F22'
    }
    if (this.bgVariant === 'bubble') {
      return this.themeAiBubble
    }
    return this.themeSurface
  }

  private getStageBorderColor(): string {
    return this.bgVariant === 'dark' ? 'rgba(255,255,255,0.12)' : 'rgba(0,0,0,0.08)'
  }

  private getStageLabelColor(): string {
    return this.bgVariant === 'dark' ? 'rgba(255,255,255,0.72)' : '#6F6A60'
  }

  private getSpinnerColor(): string {
    // 暗背景下, 用一个偏亮的主题色更易看清
    return this.bgVariant === 'dark' ? '#A8C0E3' : this.themePrimary
  }

  private handleBack(): void {
    if (cubeSpinnerPreviewPathStack !== null && cubeSpinnerPreviewPathStack.size() > 0) {
      cubeSpinnerPreviewPathStack.pop()
    }
  }

  build() {
    NavDestination() {
      Column() {
        this.HeaderBar()
        Scroll() {
          Column({ space: 16 }) {
            this.BackgroundToggleRow()

            this.VariantCard(
              'A',
              'A · Light Cube',
              '静态立方体, 高光在三个面之间循环 + 整体微浮动',
              '推荐: 标题旁小指示器 / 通用 loading (12 - 32vp)'
            )

            this.VariantCard(
              'B',
              'B · Bubble Dots',
              '现有 TypingDots 套上呼吸"对话气泡", 视觉上像 icon 上的对话面',
              '推荐: 聊天里 AI 思考中 (替换现有 TypingIndicator)'
            )

            this.VariantCard(
              'C',
              'C · Assemble Cube',
              '三个面带 stagger 地散开 → 聚合, 暗示 AI 在拼接画面',
              '推荐: 生图占位 (≥ 56vp)'
            )

            this.VariantCard(
              'D',
              'D · 3D Spin Cube',
              '立方体绕 Y 轴 3D 旋转',
              '推荐: 中大尺寸 loading 替代方案 (32 - 80vp)'
            )

            this.ComparisonCard()

            Blank().height(40)
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 12 })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .width('100%')
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.themeBackground)
    }
    .hideTitleBar(true)
    .hideBackButton(true)
    .onBackPressed((): boolean => {
      this.handleBack()
      return true
    })
  }

  // ---------------------------------------------------------------------------
  // 顶部标题栏
  // ---------------------------------------------------------------------------
  @Builder
  private HeaderBar() {
    Row() {
      Button({ type: ButtonType.Circle, stateEffect: true }) {
        SymbolGlyph($r('sys.symbol.arrow_left'))
          .fontSize(20)
          .fontColor(['#24211C'])
      }
      .width(36)
      .height(36)
      .backgroundColor('rgba(0,0,0,0)')
      .onClick((): void => {
        this.handleBack()
      })

      Text('ChatCube 加载动效预览')
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor('#24211C')
        .margin({ left: 8 })
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text('DEV')
        .fontSize(10)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.themePrimary)
        .padding({ left: 8, right: 8, top: 3, bottom: 3 })
        .backgroundColor(this.themePrimaryLight)
        .borderRadius(6)
    }
    .width('100%')
    .height(56)
    .padding({ left: 12, right: 16 })
    .alignItems(VerticalAlign.Center)
  }

  // ---------------------------------------------------------------------------
  // 背景切换
  // ---------------------------------------------------------------------------
  @Builder
  private BackgroundToggleRow() {
    Row({ space: 8 }) {
      this.BackgroundChip('light', '浅底')
      this.BackgroundChip('bubble', 'AI 气泡')
      this.BackgroundChip('dark', '深底')
    }
    .width('100%')
  }

  @Builder
  private BackgroundChip(value: PreviewBackground, label: string) {
    Text(label)
      .fontSize(13)
      .fontWeight(this.bgVariant === value ? FontWeight.Medium : FontWeight.Regular)
      .fontColor(this.bgVariant === value ? '#FFFFFF' : '#6F6A60')
      .padding({ left: 14, right: 14, top: 7, bottom: 7 })
      .backgroundColor(this.bgVariant === value ? this.themePrimary : 'rgba(0,0,0,0.05)')
      .borderRadius(16)
      .onClick((): void => {
        this.bgVariant = value
      })
  }

  // ---------------------------------------------------------------------------
  // 变体卡片通用骨架
  // ---------------------------------------------------------------------------
  @Builder
  private VariantCard(variant: PreviewVariant, title: string, description: string, scene: string) {
    Column({ space: 12 }) {
      Column({ space: 4 }) {
        Text(title)
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor('#24211C')
          .width('100%')
        Text(description)
          .fontSize(13)
          .fontColor('#6F6A60')
          .width('100%')
        Text(scene)
          .fontSize(12)
          .fontColor(this.themePrimary)
          .width('100%')
      }
      .width('100%')

      // 演出舞台
      Column() {
        if (variant === 'A') {
          this.BuildLightShowcase()
        } else if (variant === 'B') {
          this.BuildBubbleShowcase()
        } else if (variant === 'C') {
          this.BuildAssembleShowcase()
        } else {
          this.BuildSpinShowcase()
        }
      }
      .width('100%')
      .padding({ top: 24, bottom: 24, left: 12, right: 12 })
      .backgroundColor(this.getStageColor())
      .borderRadius(14)
      .border({
        width: 0.5,
        color: this.getStageBorderColor()
      })
    }
    .width('100%')
    .padding(16)
    .backgroundColor(this.themeSurface)
    .borderRadius(18)
    .shadow({ radius: 12, color: 'rgba(0,0,0,0.05)', offsetY: 2 })
  }

  // ---------------------------------------------------------------------------
  // A: Light Cube 三种尺寸
  // ---------------------------------------------------------------------------
  @Builder
  private BuildLightShowcase() {
    Row({ space: 28 }) {
      this.LightSample(16, '16vp · 内联')
      this.LightSample(28, '28vp · 标题')
      this.LightSample(48, '48vp · 通用')
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private LightSample(size: number, label: string) {
    Column({ space: 8 }) {
      Column() {
        CubeSpinnerLight({ sizeVp: size, color: this.getSpinnerColor() })
      }
      .width(64)
      .height(64)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)

      Text(label)
        .fontSize(11)
        .fontColor(this.getStageLabelColor())
    }
  }

  // ---------------------------------------------------------------------------
  // B: Bubble Dots
  // ---------------------------------------------------------------------------
  @Builder
  private BuildBubbleShowcase() {
    Column({ space: 18 }) {
      Row() {
        CubeSpinnerBubble({ dotSize: 7, spacing: 5 })
      }
      .width('100%')
      .justifyContent(FlexAlign.Start)
      .padding({ left: 8 })

      Row({ space: 8 }) {
        Text('小型 (内联):')
          .fontSize(11)
          .fontColor(this.getStageLabelColor())
        CubeSpinnerBubble({ dotSize: 4, spacing: 2, useShadow: false })
      }
      .width('100%')
      .padding({ left: 8 })
    }
    .width('100%')
  }

  // ---------------------------------------------------------------------------
  // C: Assemble Cube
  // ---------------------------------------------------------------------------
  @Builder
  private BuildAssembleShowcase() {
    Column({ space: 12 }) {
      Row({ space: 36 }) {
        this.AssembleSample(56)
        this.AssembleSample(80)
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)

      Text('生成中…')
        .fontSize(13)
        .fontColor(this.getStageLabelColor())
    }
    .width('100%')
  }

  @Builder
  private AssembleSample(size: number) {
    Column() {
      CubeSpinnerAssemble({ sizeVp: size, color: this.getSpinnerColor() })
    }
    .width(size + 16)
    .height(size + 16)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  // ---------------------------------------------------------------------------
  // D: 3D Spin Cube
  // ---------------------------------------------------------------------------
  @Builder
  private BuildSpinShowcase() {
    Row({ space: 28 }) {
      this.SpinSample(28, '28vp')
      this.SpinSample(48, '48vp')
      this.SpinSample(72, '72vp')
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private SpinSample(size: number, label: string) {
    Column({ space: 8 }) {
      Column() {
        CubeSpinner3D({ sizeVp: size, color: this.getSpinnerColor() })
      }
      .width(80)
      .height(80)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)

      Text(label)
        .fontSize(11)
        .fontColor(this.getStageLabelColor())
    }
  }

  // ---------------------------------------------------------------------------
  // 当前 vs 推荐 对照
  // ---------------------------------------------------------------------------
  @Builder
  private ComparisonCard() {
    Column({ space: 12 }) {
      Text('当前 vs 推荐')
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor('#24211C')
        .width('100%')

      Text('左侧为当前应用里在用的系统 LoadingProgress, 右侧为对应推荐的 ChatCube 替代')
        .fontSize(12)
        .fontColor('#6F6A60')
        .width('100%')

      this.ComparisonRow('title', '标题生成中 (12vp)')

      this.ComparisonRow('imagegen', '生图占位 (44vp)')
    }
    .width('100%')
    .padding(16)
    .backgroundColor(this.themeSurface)
    .borderRadius(18)
    .shadow({ radius: 12, color: 'rgba(0,0,0,0.05)', offsetY: 2 })
  }

  @Builder
  private ComparisonRow(comparison: PreviewComparison, label: string) {
    Row() {
      Text(label)
        .fontSize(12)
        .fontColor('#6F6A60')
        .layoutWeight(1)

      Column() {
        if (comparison === 'title') {
          LoadingProgress()
            .width(12)
            .height(12)
            .color('#8A8178')
        } else {
          LoadingProgress()
            .width(44)
            .height(44)
            .color(this.themePrimary)
        }
      }
      .width(80)
      .height(80)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .backgroundColor('rgba(0,0,0,0.03)')
      .borderRadius(12)

      Text('→')
        .fontSize(14)
        .fontColor('#8A8178')
        .padding({ left: 8, right: 8 })

      Column() {
        if (comparison === 'title') {
          CubeSpinnerLight({ sizeVp: 14, color: this.themePrimary })
        } else {
          CubeSpinnerAssemble({ sizeVp: 56, color: this.themePrimary })
        }
      }
      .width(80)
      .height(80)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .backgroundColor(this.themePrimaryLight)
      .borderRadius(12)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }
}

@Builder
export function CubeSpinnerPreviewBuilder(name: string, param: Object) {
  NavDestination() {
    CubeSpinnerPreview()
  }
  .hideTitleBar(true)
  .hideBackButton(true)
  .onReady((context: NavDestinationContext): void => {
    cubeSpinnerPreviewPathStack = context.pathStack
  })
  .onBackPressed((): boolean => {
    if (cubeSpinnerPreviewPathStack !== null && cubeSpinnerPreviewPathStack.size() > 0) {
      cubeSpinnerPreviewPathStack.pop()
    }
    return true
  })
}
