import { common } from '@kit.AbilityKit'
import { getOnboardingPresetPrompts, PresetPrompt, resolvePromptBody } from '../../config/PresetPrompts'
import { IndexRecommendedPromptsCard } from '../index/IndexRecommendedPromptsCard'

/**
 * Onboarding 第 3 步:推荐提示词。
 * 复用 IndexRecommendedPromptsCard,只展示前 4 条。
 * 点击卡片 → 通过 @Event onPickPrompt 把 prefill 文本传给 Overlay,
 * Overlay 关闭 Onboarding 并把文本传给主页用于新对话 prefill。
 */
@ComponentV2
export struct OnboardingStepPrompts {
  @Event onPickPrompt: (text: string) => void = () => {}

  build() {
    Column({ space: 24 }) {
      Column({ space: 8 }) {
        Text($r('app.string.onboarding_step3_title'))
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Text($r('app.string.onboarding_step3_desc'))
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
      .padding({ left: 24, right: 24 })

      IndexRecommendedPromptsCard({
        prompts: getOnboardingPresetPrompts(),
        onPromptClick: (prompt: PresetPrompt): void => {
          const context = this.getUIContext().getHostContext() as common.Context | undefined
          if (context === undefined || context === null) {
            return
          }
          const bodyText = resolvePromptBody(prompt, context)
          if (bodyText === '') {
            return
          }
          this.onPickPrompt(bodyText)
        }
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
