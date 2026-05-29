import { ThemeAppearanceSettingsView } from './ThemeModeSettingsPage'
import { getAppUiState } from '../state/AppUiState'

let colorThemeSettingsPathStack: NavPathStack | null = null

@Entry
@ComponentV2
struct ColorThemeSettingsPage {
  @Param hostedInNavDestination: boolean = false

  private handleBack(): void {
    if (colorThemeSettingsPathStack !== null && colorThemeSettingsPathStack.size() > 0) {
      colorThemeSettingsPathStack.pop()
    }
  }

  build() {
    Column() {
      ThemeAppearanceSettingsView({
        compactTitle: $r('app.string.settings_appearance'),
        hostedInNavDestination: this.hostedInNavDestination,
        onCompactBack: () => {
          this.handleBack()
        },
        onDestinationReady: (context: NavDestinationContext) => {
          colorThemeSettingsPathStack = context.pathStack
        },
        onDestinationBack: (): boolean => {
          this.handleBack()
          return true
        }
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(getAppUiState().themeBackground)
  }
}

@Builder
export function ColorThemeSettingsPageBuilder(name: string, param: Object) {
  ColorThemeSettingsPage({
    hostedInNavDestination: true
  })
}
