import { getAppUiState } from '../../state/AppUiState'
import { withColorAlpha } from '../../utils/ColorAlphaUtils'
import {
  getOnboardingViewModel,
  OnboardingStep,
  OnboardingViewModel
} from '../../viewmodels/OnboardingViewModel'
import { OnboardingStepTheme } from './OnboardingStepTheme'
import { OnboardingStepProvider } from './OnboardingStepProvider'
import { OnboardingStepPrompts } from './OnboardingStepPrompts'

/**
 * 首次启动引导覆盖层(全屏)。
 * 由 pages/Index.ets 的 Stack 根级条件渲染。
 *
 * 完成时触发 onCompleted(prefillText):
 *   - prefillText !== '' → 调用方应用 prefillText 打开新对话
 *   - prefillText === '' → 调用方仅关闭 overlay,落地主页
 */
@ComponentV2
export struct OnboardingOverlay {
  @Event onCompleted: (prefillText: string) => void = () => {}

  private vm: OnboardingViewModel = getOnboardingViewModel()

  private get themePrimary(): string {
    return getAppUiState().themePrimary
  }

  private get themeBackground(): string {
    return getAppUiState().themeBackground
  }

  private get themeSurface(): string {
    return getAppUiState().themeSurface
  }

  private get topAvoidHeight(): number {
    return getAppUiState().topAvoidHeight
  }

  private get bottomAvoidHeight(): number {
    return getAppUiState().bottomAvoidHeight
  }

  private isProviderStepReady(): boolean {
    return this.vm.selectedPresetProviderId !== '' && this.vm.apiKeyInput.trim() !== ''
  }

  build() {
    Column() {
      Column()
        .width('100%')
        .height(this.topAvoidHeight)

      this.ProgressBar()

      Column() {
        if (this.vm.currentStep === OnboardingStep.THEME) {
          Column() {
            OnboardingStepTheme()
          }
          .width('100%')
          .height('100%')
          .transition(TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: 16 }))
            .animation({ duration: 280, curve: Curve.EaseOut }))
        } else if (this.vm.currentStep === OnboardingStep.PROVIDER) {
          Column() {
            OnboardingStepProvider()
          }
          .width('100%')
          .height('100%')
          .transition(TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: 16 }))
            .animation({ duration: 280, curve: Curve.EaseOut }))
        } else {
          Column() {
            OnboardingStepPrompts({
              onPickPrompt: (text: string): void => {
                this.onCompleted(text)
              }
            })
          }
          .width('100%')
          .height('100%')
          .transition(TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: 16 }))
            .animation({ duration: 280, curve: Curve.EaseOut }))
        }
      }
      .layoutWeight(1)
      .width('100%')
      .padding({ top: 32, bottom: 16 })

      this.BottomButtonBar()

      Column()
        .width('100%')
        .height(this.bottomAvoidHeight)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeBackground)
    .animation({ duration: 260, curve: Curve.EaseInOut })
  }

  @Builder
  private ProgressBar() {
    Row({ space: 8 }) {
      ForEach([1, 2, 3], (step: number) => {
        Row()
          .layoutWeight(1)
          .height(4)
          .borderRadius(2)
          .backgroundColor(
            step <= this.vm.currentStep ? this.themePrimary : withColorAlpha(this.themePrimary, '33')
          )
          .animation({ duration: 260, curve: Curve.EaseInOut })
      }, (step: number) => `progress-${step}`)
    }
    .width('100%')
    .padding({ left: 24, right: 24, top: 12 })
  }

  @Builder
  private BottomButtonBar() {
    Row({ space: 12 }) {
      if (this.vm.currentStep === OnboardingStep.THEME) {
        Button($r('app.string.onboarding_next'))
          .primaryStyle(this.themePrimary)
          .layoutWeight(1)
          .onClick(() => {
            this.vm.nextStep()
          })
      } else if (this.vm.currentStep === OnboardingStep.PROVIDER) {
        Button($r('app.string.onboarding_skip_provider'))
          .secondaryStyle(this.themeSurface)
          .layoutWeight(1)
          .onClick(() => {
            this.vm.nextStep()
          })

        Button($r('app.string.onboarding_next'))
          .primaryStyle(this.themePrimary)
          .layoutWeight(1)
          .enabled(this.isProviderStepReady())
          .opacity(this.isProviderStepReady() ? 1 : 0.5)
          .onClick(() => {
            this.handleProviderNext()
          })
      } else {
        Button($r('app.string.onboarding_prev'))
          .secondaryStyle(this.themeSurface)
          .layoutWeight(1)
          .onClick(() => {
            this.vm.prevStep()
          })

        Button($r('app.string.onboarding_skip_prompts'))
          .primaryStyle(this.themePrimary)
          .layoutWeight(1)
          .onClick(() => {
            this.onCompleted('')
          })
      }
    }
    .width('100%')
    .padding({ left: 24, right: 24, top: 12, bottom: 12 })
  }

  private async handleProviderNext(): Promise<void> {
    if (this.vm.applyingProvider) {
      return
    }
    const ok = await this.vm.applyProvider()
    if (ok) {
      this.vm.nextStep()
    }
  }
}

@Extend(Button)
function primaryStyle(color: string) {
  .height(48)
  .fontSize(15)
  .fontWeight(FontWeight.Medium)
  .fontColor(Color.White)
  .backgroundColor(color)
  .borderRadius(14)
}

@Extend(Button)
function secondaryStyle(bg: string) {
  .height(48)
  .fontSize(15)
  .fontWeight(FontWeight.Medium)
  .fontColor($r('app.color.text_primary'))
  .backgroundColor(bg)
  .borderRadius(14)
  .border({ width: 1, color: $r('app.color.divider') })
}
