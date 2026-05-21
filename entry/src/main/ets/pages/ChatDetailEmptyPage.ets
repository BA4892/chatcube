import { IndexEmptyStateCard } from '../components/index/IndexEmptyStateCard'
import { AppStorageKeys } from '../config/AppStorageKeys'
import { getAppUiState, setAppUiStateValue } from '../state/AppUiState'

@ComponentV2
struct ChatDetailEmptyPage {
  private get themeBackground(): string {
    return getAppUiState().themeBackground
  }

  build() {
    NavDestination() {
      Column() {
        IndexEmptyStateCard({
          icon: $r('sys.symbol.ellipsis_message'),
          title: $r('app.string.tablet_chat_detail_empty_title'),
          description: $r('app.string.tablet_chat_detail_empty_desc'),
          showButton: true,
          buttonText: $r('app.string.new_chat'),
          onButtonClick: (): void => {
            setAppUiStateValue(AppStorageKeys.OPEN_NEW_CHAT, Date.now())
          }
        })
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.themeBackground)
    }
    .hideTitleBar(true)
  }
}

@Builder
export function ChatDetailEmptyPageBuilder(name: string, param: Object) {
  ChatDetailEmptyPage()
}
