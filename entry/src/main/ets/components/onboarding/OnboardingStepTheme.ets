import { ThemeMode } from '../../services/PreferencesService'
import { ALL_THEMES, ThemeInfo } from '../../models/ThemeColors'
import { getAppUiState } from '../../state/AppUiState'
import { withColorAlpha } from '../../utils/ColorAlphaUtils'
import { getOnboardingViewModel, OnboardingViewModel } from '../../viewmodels/OnboardingViewModel'

interface ThemeOption {
  mode: ThemeMode
  label: Resource
  symbol: Resource
}

const THEME_OPTIONS: ThemeOption[] = [
  { mode: ThemeMode.SYSTEM, label: $r('app.string.onboarding_theme_system'), symbol: $r('sys.symbol.gearshape') },
  { mode: ThemeMode.LIGHT, label: $r('app.string.onboarding_theme_light'), symbol: $r('sys.symbol.lightbulb') },
  { mode: ThemeMode.DARK, label: $r('app.string.onboarding_theme_dark'), symbol: $r('sys.symbol.cloud') }
]

@ComponentV2
export struct OnboardingStepTheme {
  private vm: OnboardingViewModel = getOnboardingViewModel()

  private get themePrimary(): string {
    return getAppUiState().themePrimary
  }

  private get themeSurface(): string {
    return getAppUiState().themeSurface
  }

  private getThemeSwatchColor(theme: ThemeInfo): string {
    // previewColors[2] 是设计选定的主色样品
    return theme.previewColors.length > 2 ? theme.previewColors[2] : theme.light.primary
  }

  build() {
    Scroll() {
      Column({ space: 24 }) {
        Column({ space: 8 }) {
          Text($r('app.string.onboarding_step1_title'))
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
          Text($r('app.string.onboarding_step1_desc'))
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')

        Column({ space: 12 }) {
          ForEach(THEME_OPTIONS, (option: ThemeOption) => {
            this.ThemeRow(option)
          }, (option: ThemeOption) => option.mode)
        }
        .width('100%')

        Column({ space: 12 }) {
          Text($r('app.string.onboarding_step1_color_label'))
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_secondary'))

          Scroll() {
            Row({ space: 14 }) {
              ForEach(ALL_THEMES, (theme: ThemeInfo) => {
                this.ColorSwatch(theme)
              }, (theme: ThemeInfo) => theme.id)
            }
            .padding({ left: 2, right: 2, top: 4, bottom: 4 })
          }
          .scrollable(ScrollDirection.Horizontal)
          .scrollBar(BarState.Off)
          .width('100%')
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
      }
      .width('100%')
      .padding({ left: 24, right: 24, bottom: 16 })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }

  @Builder
  private ThemeRow(option: ThemeOption) {
    Row({ space: 14 }) {
      Row() {
        SymbolGlyph(option.symbol)
          .fontSize(22)
          .fontColor([this.themePrimary])
      }
      .width(44)
      .height(44)
      .borderRadius(12)
      .backgroundColor(withColorAlpha(this.themePrimary, '1A'))
      .justifyContent(FlexAlign.Center)

      Text(option.label)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)

      if (this.vm.selectedThemeMode === option.mode) {
        SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
          .fontSize(22)
          .fontColor([this.themePrimary])
      }
    }
    .width('100%')
    .padding(16)
    .borderRadius(14)
    .backgroundColor(this.themeSurface)
    .border({
      width: this.vm.selectedThemeMode === option.mode ? 2 : 1,
      color: this.vm.selectedThemeMode === option.mode ? this.themePrimary : $r('app.color.divider')
    })
    .scale(this.vm.selectedThemeMode === option.mode ? { x: 1.0, y: 1.0 } : { x: 0.99, y: 0.99 })
    .animation({ duration: 200, curve: Curve.EaseOut })
    .onClick(() => {
      this.vm.applyTheme(option.mode)
    })
  }

  @Builder
  private ColorSwatch(theme: ThemeInfo) {
    Stack() {
      Row()
        .width(44)
        .height(44)
        .borderRadius(22)
        .backgroundColor(this.getThemeSwatchColor(theme))
        .border({
          width: this.vm.selectedColorTheme === theme.id ? 3 : 0,
          color: Color.White
        })
        .shadow(this.vm.selectedColorTheme === theme.id ? {
          radius: 12,
          color: withColorAlpha(this.getThemeSwatchColor(theme), '66'),
          offsetX: 0,
          offsetY: 4
        } : {
          radius: 4,
          color: '#1A000000',
          offsetX: 0,
          offsetY: 1
        })

      if (this.vm.selectedColorTheme === theme.id) {
        SymbolGlyph($r('sys.symbol.checkmark'))
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor([Color.White])
      }
    }
    .width(48)
    .height(48)
    .scale(this.vm.selectedColorTheme === theme.id ? { x: 1.08, y: 1.08 } : { x: 1.0, y: 1.0 })
    .animation({ duration: 220, curve: Curve.EaseOut })
    .onClick(() => {
      this.vm.applyColorTheme(theme.id)
    })
  }
}
