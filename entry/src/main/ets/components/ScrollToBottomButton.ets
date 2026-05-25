/**
 * 快速滚动按钮组件
 * 支持翻页 / 跳转到顶部 / 跳转到底部
 */

import {
  createButtonTouchHandler
} from '../utils/ButtonAnimationUtils'
import { getAppUiState } from '../state/AppUiState'
import { withColorAlpha } from '../utils/ColorAlphaUtils'

@ComponentV2
export struct ScrollToBottomButton {
  // 是否显示按钮
  @Param isVisible: boolean = false
  // 底部安全区域高度（vp）
  @Param bottomAvoidHeight: number = 0
  // 固定悬浮按钮距离底部的基准偏移（vp）
  @Param fixedBottomOffset: number = 128
  // 按钮方向：0=向下（到底部）, 1=向上（到顶部）, 保留给旧调用方
  @Param buttonDirection: number = 0
  @Param icon: Resource = $r('sys.symbol.chevron_down')
  // 额外纵向偏移（用于多按钮错位摆放）
  @Param extraOffsetY: number = 0
  @Param placeOnLeft: boolean = false
  // 点击回调
  @Event onClickAction: () => void = () => {}
  @Event onScrollToBottom: () => void = () => {}
  @Event onScrollToTop: () => void = () => {}

  // 按钮按下状态
  @Local private scrollBtnPressed: boolean = false
  // 滚动快捷按钮应跟随当前主题主色
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

  private get materialShadowColor(): string {
    return this.isDark ? 'rgba(0, 0, 0, 0.4)' : 'rgba(0, 0, 0, 0.12)'
  }

  private getButtonVisibleScale(): ScaleOptions {
    const pressedScale = this.scrollBtnPressed ? 0.95 : 1
    const visibleScale = this.isVisible ? 1 : 0.86
    const scale = pressedScale * visibleScale
    return { x: scale, y: scale }
  }

  build() {
    Button({ type: ButtonType.Circle }) {
      SymbolGlyph(this.icon)
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
      radius: this.scrollBtnPressed ? 16 : 8,
      color: this.scrollBtnPressed ? withColorAlpha(this.themePrimary, '33') : this.materialShadowColor,
      offsetX: 0,
      offsetY: this.scrollBtnPressed ? 4 : 2
    })
    .opacity(this.isVisible ? 1 : 0)
    .scale(this.getButtonVisibleScale())
    .animation({ duration: 180, curve: Curve.EaseOut })
    .hitTestBehavior(this.isVisible ? HitTestMode.Default : HitTestMode.None)
    .onTouch(createButtonTouchHandler((pressed: boolean) => {
      this.scrollBtnPressed = pressed
    }))
    .onClick(() => {
      if (!this.isVisible) {
        return
      }
      this.onClickAction()
      if (this.buttonDirection === 1) {
        this.onScrollToTop()
      } else {
        this.onScrollToBottom()
      }
    })
    .position({ x: this.placeOnLeft ? 0 : '100%', y: '100%' })
    .translate({
      x: this.placeOnLeft ? 16 : -56,
      y: -(this.fixedBottomOffset + this.bottomAvoidHeight) + this.extraOffsetY
    })
    .zIndex(12)
  }
}
