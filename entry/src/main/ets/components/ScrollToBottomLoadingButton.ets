/**
 * 带系统 LoadingProgress 的底部居中"回到底部"按钮
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

  build() {
    if (this.isVisible) {
      Stack({ alignContent: Alignment.Center }) {
        Button({ type: ButtonType.Circle }) {
          Stack({ alignContent: Alignment.Center }) {
            LoadingProgress()
              .width(26)
              .height(26)
              .color(this.themePrimary)

            SymbolGlyph($r('sys.symbol.chevron_down'))
              .fontSize(13)
              .fontColor([this.themePrimary])
          }
        }
        .width(48)
        .height(48)
        .backgroundColor(this.materialBg)
        .backgroundBlurStyle(BlurStyle.COMPONENT_REGULAR)
        .border({
          width: 0.5,
          color: this.materialBorder
        })
        .shadow({ radius: 8, color: this.isDark ? 'rgba(0,0,0,0.4)' : 'rgba(0,0,0,0.12)', offsetX: 0, offsetY: 2 })
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
    }
  }
}
