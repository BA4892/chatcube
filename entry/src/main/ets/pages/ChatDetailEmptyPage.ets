import { IndexEmptyStateCard } from '../components/index/IndexEmptyStateCard'
import { IndexRecommendedPromptsCard } from '../components/index/IndexRecommendedPromptsCard'
import {
  buildOpenNewChatWithPromptPayload,
  getPresetPrompts,
  PresetPrompt,
  resolvePromptBody
} from '../config/PresetPrompts'
import { AppStorageKeys } from '../config/AppStorageKeys'
import { common } from '@kit.AbilityKit'
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

        IndexRecommendedPromptsCard({
          prompts: getPresetPrompts(),
          onPromptClick: (prompt: PresetPrompt): void => {
            const context = this.getUIContext().getHostContext() as common.Context | undefined
            if (context === undefined || context === null) {
              return
            }
            const bodyText = resolvePromptBody(prompt, context)
            if (bodyText === '') {
              return
            }
            setAppUiStateValue(AppStorageKeys.OPEN_NEW_CHAT_WITH_PROMPT,
              buildOpenNewChatWithPromptPayload(bodyText))
          }
        })
          .margin({ bottom: 24 })
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
