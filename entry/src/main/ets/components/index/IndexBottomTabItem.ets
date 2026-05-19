import { getAppUiState } from '../../state/AppUiState'
import { createButtonTouchHandler, getButtonAnimation, getButtonScale } from '../../utils/ButtonAnimationUtils'

@ComponentV2
export struct IndexBottomTabItem {
  @Param active: boolean = false
  @Param activeIcon: Resource = $r('sys.symbol.circle')
  @Param inactiveIcon: Resource = $r('sys.symbol.circle')
  @Param label: Resource = $r('app.string.tab_chat')
  @Param badgeCount: number = 0
  @Local pressed: boolean = false
  // 图标弹跳动画
  @Local iconScale: number = 1
  private get themePrimary(): string {
    return getAppUiState().themePrimary
  }

  @Monitor('active')
  onActiveChanged(): void {
    if (this.active) {
      // 选中时图标弹跳: 1 → 1.25 → 1
      this.getUIContext().animateTo({ duration: 150, curve: Curve.EaseOut }, () => {
        this.iconScale = 1.25
      })
      setTimeout((): void => {
        this.getUIContext().animateTo({ duration: 200, curve: Curve.EaseInOut }, () => {
          this.iconScale = 1
        })
      }, 150)
    }
  }

  build() {
    Column({ space: 2 }) {
      Stack({ alignContent: Alignment.Center }) {
        SymbolGlyph(this.active ? this.activeIcon : this.inactiveIcon)
          .fontSize(22)
          .fontColor(this.active ? [this.themePrimary] : [$r('app.color.text_secondary')])
          .scale({ x: this.iconScale, y: this.iconScale })

        if (this.badgeCount > 0) {
          Row() {
            Text(this.badgeCount > 99 ? '99+' : this.badgeCount.toString())
              .fontSize(9)
              .fontColor($r('sys.color.comp_background_list_card'))
              .fontWeight(FontWeight.Medium)
          }
          .height(14)
          .padding({ left: 4, right: 4 })
          .borderRadius(7)
          .backgroundColor($r('app.color.status_error'))
          .position({ x: 16, y: -8 })
        }
      }
      .width(28)
      .height(24)

      Text(this.label)
        .fontSize(10)
        .fontWeight(this.active ? FontWeight.Bold : FontWeight.Medium)
        .fontColor(this.active ? this.themePrimary : $r('app.color.text_secondary'))
        .animation({ duration: 200 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .scale(getButtonScale(this.pressed, {
      pressedScale: 0.92,
      animationDuration: 120,
      animationCurve: Curve.EaseOut
    }))
    .animation(getButtonAnimation({
      pressedScale: 0.92,
      animationDuration: 120,
      animationCurve: Curve.EaseOut
    }))
    .onTouch(createButtonTouchHandler((pressed: boolean) => {
      this.pressed = pressed
    }))
  }
}
