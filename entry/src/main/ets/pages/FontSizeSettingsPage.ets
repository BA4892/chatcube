import { ThemeAppearanceSettingsView } from './ThemeModeSettingsPage'
import { getAppUiState } from '../state/AppUiState'

let fontSizeSettingsPathStack: NavPathStack | null = null

@Entry
@ComponentV2
struct FontSizeSettingsPage {
  @Param hostedInNavDestination: boolean = false

  private handleBack(): void {
    if (fontSizeSettingsPathStack !== null && fontSizeSettingsPathStack.size() > 0) {
      fontSizeSettingsPathStack.pop()
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
          fontSizeSettingsPathStack = context.pathStack
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
export function FontSizeSettingsPageBuilder(name: string, param: Object) {
  FontSizeSettingsPage({
    hostedInNavDestination: true
  })
}
