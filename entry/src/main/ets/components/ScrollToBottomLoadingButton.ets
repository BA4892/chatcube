/**
 * 带 Loading 外环旋转动效的底部居中"回到底部"按钮
 * 仅在 AI 流式生成中且用户不在底部时显示
 */

import {
  createButtonTouchHandler,
  getButtonScale,
  getButtonAnimation
} from '../utils/ButtonAnimationUtils'
import { getAppUiState } from '../state/AppUiState'

@ComponentV2
export struct ScrollToBottomLoadingButton {
  @Param isVisible: boolean = false
  // 按钮"左上角距屏幕底"基线(vp), 与 ScrollToBottomButton 共享同一基线
  @Param fixedBottomOffset: number = 128
  @Param bottomAvoidHeight: number = 0
  @Event onScrollToBottom: () => void = () => {}

  @Local private btnPressed: boolean = false
  @Local private loadingAngle: number = 0
  private spinStartToken: number = 0
  private spinStartTimerId: number = -1

  private get themePrimary(): string {
    return getAppUiState().themePrimary
  }

  private get isDark(): boolean {
    return getAppUiState().isDarkMode
  }

  private get materialBg(): string {
    return this.isDark ? 'rgba(30, 30, 30, 0.72)' : 'rgba(255, 255, 255, 0.72)'
  }

  private get materialBorder(): string {
    return this.isDark ? 'rgba(255, 255, 255, 0.08)' : 'rgba(0, 0, 0, 0.06)'
  }

  aboutToDisappear(): void {
    this.cancelPendingSpinStart()
    this.spinStartToken++
  }

  @Monitor('isVisible')
  onVisibleChange(): void {
    if (this.isVisible) {
      this.startSpinAnimation()
      return
    }
    this.cancelPendingSpinStart()
    this.spinStartToken++
    this.loadingAngle = 0
  }

  private cancelPendingSpinStart(): void {
    if (this.spinStartTimerId < 0) {
      return
    }
    clearTimeout(this.spinStartTimerId)
    this.spinStartTimerId = -1
  }

  private startSpinAnimation(): void {
    this.cancelPendingSpinStart()
    const token = this.spinStartToken + 1
    this.spinStartToken = token
    this.loadingAngle = 0
    this.spinStartTimerId = setTimeout(() => {
      this.spinStartTimerId = -1
      if (!this.isVisible || token !== this.spinStartToken) {
        return
      }
      this.getUIContext()?.animateTo({
        duration: 1000,
        curve: Curve.Linear,
        iterations: -1,
        playMode: PlayMode.Normal,
        expectedFrameRateRange: { min: 30, max: 120, expected: 60 }
      }, () => {
        this.loadingAngle = 360
      })
    }, 0)
  }

  build() {
    if (this.isVisible) {
      Stack({ alignContent: Alignment.Center }) {
        Progress({ value: 25, total: 100, type: ProgressType.Ring })
          .width(48)
          .height(48)
          .color(this.themePrimary)
          .backgroundColor('transparent')
          .style({ strokeWidth: 2.5 })
          .rotate({ angle: this.loadingAngle })
          .onAppear(() => {
            this.startSpinAnimation()
          })

        Button({ type: ButtonType.Circle }) {
          SymbolGlyph($r('sys.symbol.chevron_down'))
            .fontSize(20)
            .fontColor([this.themePrimary])
        }
        .width(40)
        .height(40)
        .backgroundColor(this.materialBg)
        .backgroundBlurStyle(BlurStyle.COMPONENT_REGULAR)
        .border({
          width: 0.5,
          color: this.materialBorder
        })
        .shadow({
          radius: 8,
          color: this.isDark ? 'rgba(0,0,0,0.4)' : 'rgba(0,0,0,0.12)',
          offsetX: 0,
          offsetY: 2
        })
        .scale(getButtonScale(this.btnPressed))
        .animation(getButtonAnimation())
        .onTouch(createButtonTouchHandler((pressed: boolean) => {
          this.btnPressed = pressed
        }))
        .onClick(() => {
          this.onScrollToBottom()
        })
      }
      .position({ x: '50%', y: '100%' })
      .translate({
        x: '-50%',
        y: -(this.fixedBottomOffset + this.bottomAvoidHeight)
      })
      .transition(
        TransitionEffect.OPACITY.combine(
          TransitionEffect.scale({ x: 0.8, y: 0.8 })
        ).animation({ duration: 200, curve: Curve.EaseOut })
      )
      .zIndex(13)
    }
  }
}
