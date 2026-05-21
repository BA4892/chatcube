/**
 * ChatCube 品牌 Loading 动效组件 — 围绕 app icon 卡通形象设计
 *
 * 四种变体 (export 名保留, 实现已重写):
 *   A) CubeSpinnerLight     - 笑脸眨眼: 主题色圆角脸 + 双白点眼睛
 *                             眼睛在睁眼态 (●●) ↔ 笑眯眯态 (⌒⌒) 之间循环
 *                             适合: 标题旁小指示器、通用 loading (12 - 32vp)
 *
 *   B) CubeSpinnerBubble    - 立体气泡: TypingDots 气泡 + 后侧暗色厚度面 + 微 Y 轴摆动
 *                             视觉上像 icon 上的右前对话面在轻微转动
 *                             适合: 聊天里 AI 思考中
 *
 *   C) CubeSpinnerAssemble  - 老虎机方块: 正方形圆角外壳 (呼应 app icon 底座)
 *                             3 个 reel 错峰滚动, 中间穿插圆环 / 菱形 / 迷你笑脸 ChatCube,
 *                             最终全部停在三个白点 — 呼应 icon 上的三点
 *                             适合: 生图占位 (≥ 56vp)
 *
 *   D) CubeSpinner3D        - 跑步小人: 完整 ChatCube 形象 (身子 + 双手 + 双腿 + 椭圆阴影)
 *                             两脚两手交替摆动, 整体上下跳, 阴影同步缩放
 *                             适合: 中大尺寸 (≥ 64vp), 加载等待场景
 *
 * 实现要点:
 *   - 仅用 Path / Column / Row 等基础组件, 无外部资源
 *   - 用 animateTo iterations: -1 走系统动画线程, 不挤占 JS 计时器
 *   - 动画启动必须挂在 .onAppear() (参考 ScrollToBottomLoadingButton.ets)
 *   - 老虎机停顿感用 cubicBezier(0, 0.7, 0.4, 1) 实现"快滚 → 慢停 → 重启"
 */

import { getAppUiState } from '../../state/AppUiState'
import { TypingDots } from '../TypingDots'
import { curves } from '@kit.ArkUI'

// =============================================================================
// 变体 A: CubeSpinnerLight - 笑脸眨眼 + 微呼吸
// =============================================================================
@ComponentV2
export struct CubeSpinnerLight {
  @Param sizeVp: number = 32
  @Param color: string = ''
  @Local private blinkPhase: number = 0  // 0 = 睁眼, 1 = 笑眯眯
  @Local private breathScale: number = 1.0
  private blinkTimer: number = -1
  private started: boolean = false

  private get faceColor(): string {
    return this.color !== '' ? this.color : getAppUiState().themePrimary
  }

  aboutToDisappear(): void {
    if (this.blinkTimer !== -1) {
      clearInterval(this.blinkTimer)
      this.blinkTimer = -1
    }
  }

  private startAnimations(): void {
    if (this.started) return
    this.started = true
    this.startBreath()
    this.startBlinkLoop()
  }

  private startBreath(): void {
    try {
      this.getUIContext().animateTo({
        duration: 1600,
        curve: Curve.EaseInOut,
        iterations: -1,
        playMode: PlayMode.Alternate,
        expectedFrameRateRange: { min: 30, max: 120, expected: 60 }
      }, (): void => {
        this.breathScale = 1.04
      })
    } catch (_error) {
    }
  }

  private startBlinkLoop(): void {
    if (this.blinkTimer !== -1) return
    let phase: number = 0
    this.blinkTimer = setInterval((): void => {
      phase = (phase + 1) % 2
      const targetPhase: number = phase
      try {
        this.getUIContext().animateTo({
          duration: 220,
          curve: Curve.EaseInOut
        }, (): void => {
          this.blinkPhase = targetPhase
        })
      } catch (_error) {
        this.blinkPhase = targetPhase
      }
    }, 1400)
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      // 脸面背景
      Column()
        .width(this.sizeVp)
        .height(this.sizeVp * 0.92)
        .backgroundColor(this.faceColor)
        .borderRadius(this.sizeVp * 0.22)
      // 双眼
      Row({ space: this.sizeVp * 0.20 }) {
        this.Eye()
        this.Eye()
      }
    }
    .width(this.sizeVp)
    .height(this.sizeVp)
    .scale({ x: this.breathScale, y: this.breathScale, centerX: '50%', centerY: '50%' })
    .onAppear((): void => {
      this.startAnimations()
    })
  }

  // 单只眼: 睁眼 = 实心圆白点, 笑眼 = 上凸弧 ⌒
  @Builder
  private Eye() {
    Stack({ alignContent: Alignment.Center }) {
      // 睁眼态
      Column()
        .width(this.sizeVp * 0.16)
        .height(this.sizeVp * 0.16)
        .borderRadius(this.sizeVp * 0.08)
        .backgroundColor('#FFFFFF')
        .opacity(this.blinkPhase === 0 ? 1 : 0)
      // 笑眼态 (上凸弧)
      Path()
        .width(this.sizeVp * 0.22)
        .height(this.sizeVp * 0.16)
        .commands(`M 0 ${this.sizeVp * 0.12} Q ${this.sizeVp * 0.11} 0 ${this.sizeVp * 0.22} ${this.sizeVp * 0.12}`)
        .stroke('#FFFFFF')
        .strokeWidth(this.sizeVp * 0.05)
        .strokeLineCap(LineCapStyle.Round)
        .fillOpacity(0)
        .opacity(this.blinkPhase === 0 ? 0 : 1)
    }
    .width(this.sizeVp * 0.22)
    .height(this.sizeVp * 0.20)
  }
}

// =============================================================================
// 变体 B: CubeSpinnerBubble - 立体气泡 (TypingDots + 厚度面 + Y 轴微摆)
// =============================================================================
@ComponentV2
export struct CubeSpinnerBubble {
  @Param dotSize: number = 7
  @Param spacing: number = 5
  @Param bubbleColor: string = ''
  @Param useShadow: boolean = true
  @Local private bubbleScale: number = 0.96
  @Local private tiltY: number = -3
  private started: boolean = false

  private get bgColor(): string {
    return this.bubbleColor !== '' ? this.bubbleColor : getAppUiState().themeAiBubble
  }

  // 后侧"厚度"色 (用主题色, 半透明)
  private get sideColor(): string {
    return getAppUiState().themePrimary
  }

  private startAnimations(): void {
    if (this.started) return
    this.started = true
    try {
      this.getUIContext().animateTo({
        duration: 1000,
        curve: Curve.EaseInOut,
        iterations: -1,
        playMode: PlayMode.Alternate,
        expectedFrameRateRange: { min: 30, max: 120, expected: 60 }
      }, (): void => {
        this.bubbleScale = 1.04
      })
      // 微小 Y 轴 3D 摆动 ±3°
      this.getUIContext().animateTo({
        duration: 1800,
        curve: Curve.EaseInOut,
        iterations: -1,
        playMode: PlayMode.Alternate,
        expectedFrameRateRange: { min: 30, max: 120, expected: 60 }
      }, (): void => {
        this.tiltY = 3
      })
    } catch (_error) {
      this.bubbleScale = 1.0
      this.tiltY = 0
    }
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      // 后面"厚度": 同尺寸气泡, 暗色 + 半透明 + 偏移
      // 用 opacity 0 的 TypingDots 撑出与前面气泡相同的尺寸
      Row() {
        TypingDots({ dotSize: this.dotSize, spacing: this.spacing })
          .opacity(0)
      }
      .padding({ left: 14, right: 14, top: 10, bottom: 10 })
      .backgroundColor(this.sideColor)
      .borderRadius({ topLeft: 4, topRight: 18, bottomLeft: 18, bottomRight: 18 })
      .opacity(0.55)
      .translate({ x: 5, y: 5 })

      // 前面气泡
      Row() {
        TypingDots({ dotSize: this.dotSize, spacing: this.spacing })
      }
      .padding({ left: 14, right: 14, top: 10, bottom: 10 })
      .backgroundColor(this.bgColor)
      .borderRadius({ topLeft: 4, topRight: 18, bottomLeft: 18, bottomRight: 18 })
      .clip(true)
      .shadow(this.useShadow ? {
        radius: 8,
        color: 'rgba(0, 0, 0, 0.05)',
        offsetX: 0,
        offsetY: 1
      } : { radius: 0, color: 'rgba(0,0,0,0)', offsetX: 0, offsetY: 0 })
    }
    .scale({ x: this.bubbleScale, y: this.bubbleScale, centerX: '50%', centerY: '50%' })
    .rotate({ x: 0, y: 1, z: 0, angle: this.tiltY, centerX: '50%', centerY: '50%' })
    .onAppear((): void => {
      this.startAnimations()
    })
  }
}

// =============================================================================
// 老虎机内部组件: 单个 reel
// =============================================================================
@ComponentV2
struct SlotReel {
  @Param dotSize: number = 8
  @Param dotColor: string = '#FFFFFF'
  @Param accentColor: string = ''   // 迷你笑脸眼睛颜色 (传入主题色 = 外壳背景, 让眼睛看起来像从外壳抠出的 dot)
  @Param delayMs: number = 0
  @Local private translateY: number = 0
  private started: boolean = false

  // 一个位置占的纵向间距 (留 60% 间隙, 看起来有 "下一个元素来了" 的感觉)
  private get dotStep(): number {
    return this.dotSize * 1.6
  }

  private get eyeColor(): string {
    return this.accentColor !== '' ? this.accentColor : getAppUiState().themePrimary
  }

  private startReel(): void {
    if (this.started) return
    this.started = true
    try {
      this.getUIContext().animateTo({
        duration: 1500,
        curve: curves.cubicBezierCurve(0, 0.7, 0.4, 1.0),
        iterations: -1,
        delay: this.delayMs,
        playMode: PlayMode.Normal,
        expectedFrameRateRange: { min: 30, max: 120, expected: 60 }
      }, (): void => {
        // 滚动 5 个 dotStep。序列起点 (索引 0) 与终点 (索引 5) 都是白点, 循环回弹无缝
        this.translateY = -this.dotStep * 5
      })
    } catch (_error) {
    }
  }

  build() {
    Column() {
      Column() {
        // 错峰老虎机动画: 起点白点 → 环 → 迷你笑脸 → 菱形 → 环 → 白点终止
        // 三个 reel 同步后, 终点永远是三个白点 (呼应 app icon)
        this.Dot()
        this.Ring()
        this.MiniFace()
        this.Diamond()
        this.Ring()
        this.Dot()
      }
      .translate({ y: this.translateY })
    }
    .width(this.dotSize * 1.4)
    .height(this.dotSize * 1.4)  // viewport 只显示 1 个元素区域
    .clip(true)
    .onAppear((): void => {
      this.startReel()
    })
  }

  // 索引 0 / 5: 白点 (品牌起止 — icon 上的三点)
  @Builder
  private Dot() {
    Column()
      .width(this.dotSize)
      .height(this.dotSize)
      .borderRadius(this.dotSize / 2)
      .backgroundColor(this.dotColor)
      .margin({
        top: (this.dotStep - this.dotSize) / 2,
        bottom: (this.dotStep - this.dotSize) / 2
      })
  }

  // 索引 1 / 4: 环 (空心圆点, 滚动中闪一下)
  @Builder
  private Ring() {
    Column()
      .width(this.dotSize)
      .height(this.dotSize)
      .borderRadius(this.dotSize / 2)
      .border({ width: this.dotSize * 0.22, color: this.dotColor })
      .margin({
        top: (this.dotStep - this.dotSize) / 2,
        bottom: (this.dotStep - this.dotSize) / 2
      })
  }

  // 索引 2: 迷你 ChatCube 笑脸 (品牌彩蛋)
  @Builder
  private MiniFace() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width(this.dotSize)
        .height(this.dotSize)
        .borderRadius(this.dotSize * 0.22)
        .backgroundColor(this.dotColor)
      Row({ space: this.dotSize * 0.20 }) {
        Column()
          .width(this.dotSize * 0.18)
          .height(this.dotSize * 0.18)
          .borderRadius(this.dotSize * 0.09)
          .backgroundColor(this.eyeColor)
        Column()
          .width(this.dotSize * 0.18)
          .height(this.dotSize * 0.18)
          .borderRadius(this.dotSize * 0.09)
          .backgroundColor(this.eyeColor)
      }
    }
    .margin({
      top: (this.dotStep - this.dotSize) / 2,
      bottom: (this.dotStep - this.dotSize) / 2
    })
  }

  // 索引 3: 菱形 (圆角小方块旋转 45°)
  @Builder
  private Diamond() {
    Column()
      .width(this.dotSize * 0.72)
      .height(this.dotSize * 0.72)
      .borderRadius(this.dotSize * 0.12)
      .backgroundColor(this.dotColor)
      .rotate({ angle: 45 })
      .margin({
        top: (this.dotStep - this.dotSize * 0.72) / 2,
        bottom: (this.dotStep - this.dotSize * 0.72) / 2
      })
  }
}

// =============================================================================
// 变体 C: CubeSpinnerAssemble - 老虎机 (3 个 reel 错峰滚动)
// =============================================================================
@ComponentV2
export struct CubeSpinnerAssemble {
  @Param sizeVp: number = 64
  @Param color: string = ''

  private get bgColor(): string {
    return this.color !== '' ? this.color : getAppUiState().themePrimary
  }

  private get dotSize(): number {
    return this.sizeVp * 0.18
  }

  private get reelSpacing(): number {
    return this.sizeVp * 0.08
  }

  build() {
    // 外壳: 正方形圆角 (与 HarmonyOS app icon 圆角一致), reel 行 H/V 居中
    Column() {
      Row({ space: this.reelSpacing }) {
        SlotReel({ dotSize: this.dotSize, dotColor: '#FFFFFF', accentColor: this.bgColor, delayMs: 0 })
        SlotReel({ dotSize: this.dotSize, dotColor: '#FFFFFF', accentColor: this.bgColor, delayMs: 200 })
        SlotReel({ dotSize: this.dotSize, dotColor: '#FFFFFF', accentColor: this.bgColor, delayMs: 400 })
      }
    }
    .width(this.sizeVp)
    .height(this.sizeVp)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(this.bgColor)
    .borderRadius(this.sizeVp * 0.22)
    .clip(true)
  }
}

// =============================================================================
// 变体 D: CubeSpinner3D - 跑步小人 (身子 + 双手 + 双腿 + 椭圆阴影)
// =============================================================================
@ComponentV2
export struct CubeSpinner3D {
  @Param sizeVp: number = 80
  @Param color: string = ''
  @Param limbColor: string = '#2D3142'
  @Local private bodyY: number = 0
  @Local private shadowScaleX: number = 1.0
  @Local private leftLegAngle: number = -22
  @Local private rightLegAngle: number = 22
  @Local private leftArmAngle: number = 22
  @Local private rightArmAngle: number = -22
  private started: boolean = false

  private get bodyBg(): string {
    return this.color !== '' ? this.color : getAppUiState().themePrimary
  }

  private startAnimations(): void {
    if (this.started) return
    this.started = true
    try {
      // 身子上下跳 (320ms 半周期 -> 跑步频率 ~ 1.5 步/秒)
      this.getUIContext().animateTo({
        duration: 320,
        curve: Curve.EaseInOut,
        iterations: -1,
        playMode: PlayMode.Alternate,
        expectedFrameRateRange: { min: 30, max: 120, expected: 60 }
      }, (): void => {
        this.bodyY = -this.sizeVp * 0.04
      })
      // 阴影同步缩放 (身子在空中时阴影最小)
      this.getUIContext().animateTo({
        duration: 320,
        curve: Curve.EaseInOut,
        iterations: -1,
        playMode: PlayMode.Alternate,
        expectedFrameRateRange: { min: 30, max: 120, expected: 60 }
      }, (): void => {
        this.shadowScaleX = 0.72
      })
      // 双腿 + 双手反相摆动 (与跑步姿态: 左腿前 ↔ 右手前)
      this.getUIContext().animateTo({
        duration: 320,
        curve: Curve.EaseInOut,
        iterations: -1,
        playMode: PlayMode.Alternate,
        expectedFrameRateRange: { min: 30, max: 120, expected: 60 }
      }, (): void => {
        this.leftLegAngle = 22
        this.rightLegAngle = -22
        this.leftArmAngle = -22
        this.rightArmAngle = 22
      })
    } catch (_error) {
    }
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 1. 椭圆阴影 (位于底部, 不随 body 上下跳, 但同步缩放)
      Column()
        .width(this.sizeVp * 0.5)
        .height(this.sizeVp * 0.07)
        .borderRadius(this.sizeVp * 0.035)
        .backgroundColor('rgba(0, 0, 0, 0.18)')
        .position({ x: this.sizeVp * 0.25, y: this.sizeVp * 0.92 })
        .scale({ x: this.shadowScaleX, y: 1, centerX: '50%', centerY: '50%' })

      // 2. 整个小人 (身子 + 四肢一起上下跳, 但阴影留在原地)
      Stack() {
        // 2a. 左腿 (绕髋部旋转, 显示在身子下方)
        this.Leg(this.sizeVp * 0.40, this.sizeVp * 0.55, this.leftLegAngle)
        // 2b. 右腿
        this.Leg(this.sizeVp * 0.54, this.sizeVp * 0.55, this.rightLegAngle)
        // 2c. 左手 (绕肩旋转, 在身子两侧)
        this.Arm(this.sizeVp * 0.18, this.sizeVp * 0.25, this.leftArmAngle)
        // 2d. 右手
        this.Arm(this.sizeVp * 0.78, this.sizeVp * 0.25, this.rightArmAngle)
        // 2e. 身子: 圆角脸 + 双白眼 (放最后, 盖住四肢根部)
        Stack({ alignContent: Alignment.Center }) {
          Column()
            .width(this.sizeVp * 0.55)
            .height(this.sizeVp * 0.50)
            .borderRadius(this.sizeVp * 0.14)
            .backgroundColor(this.bodyBg)
          Row({ space: this.sizeVp * 0.12 }) {
            Column()
              .width(this.sizeVp * 0.07)
              .height(this.sizeVp * 0.07)
              .borderRadius(this.sizeVp * 0.035)
              .backgroundColor('#FFFFFF')
            Column()
              .width(this.sizeVp * 0.07)
              .height(this.sizeVp * 0.07)
              .borderRadius(this.sizeVp * 0.035)
              .backgroundColor('#FFFFFF')
          }
        }
        .width(this.sizeVp * 0.55)
        .height(this.sizeVp * 0.50)
        .position({ x: this.sizeVp * 0.225, y: this.sizeVp * 0.10 })
      }
      .width(this.sizeVp)
      .height(this.sizeVp)
      .translate({ y: this.bodyY })
    }
    .width(this.sizeVp)
    .height(this.sizeVp)
    .onAppear((): void => {
      this.startAnimations()
    })
  }

  // 手臂: 一根细条 + 末端小圆 (手), 绕顶端旋转
  @Builder
  private Arm(x: number, y: number, angle: number) {
    Column() {
      Column()
        .width(this.sizeVp * 0.04)
        .height(this.sizeVp * 0.18)
        .borderRadius(this.sizeVp * 0.02)
        .backgroundColor(this.limbColor)
      Column()
        .width(this.sizeVp * 0.07)
        .height(this.sizeVp * 0.07)
        .borderRadius(this.sizeVp * 0.035)
        .backgroundColor(this.limbColor)
        .margin({ top: -this.sizeVp * 0.015 })
    }
    .position({ x, y })
    .rotate({ angle, centerX: this.sizeVp * 0.02, centerY: 0 })
  }

  // 腿: 一根细条 + 末端扁椭圆 (脚), 绕顶端旋转
  @Builder
  private Leg(x: number, y: number, angle: number) {
    Column() {
      Column()
        .width(this.sizeVp * 0.05)
        .height(this.sizeVp * 0.18)
        .borderRadius(this.sizeVp * 0.025)
        .backgroundColor(this.limbColor)
      Column()
        .width(this.sizeVp * 0.10)
        .height(this.sizeVp * 0.05)
        .borderRadius(this.sizeVp * 0.025)
        .backgroundColor(this.limbColor)
        .margin({ top: -this.sizeVp * 0.01, left: -this.sizeVp * 0.02 })
    }
    .position({ x, y })
    .rotate({ angle, centerX: this.sizeVp * 0.025, centerY: 0 })
  }
}
