import { getPresetProviders, PresetProviderDef } from '../../config/PresetProviders'
import { getAppUiState } from '../../state/AppUiState'
import { getOnboardingViewModel, OnboardingViewModel } from '../../viewmodels/OnboardingViewModel'

/**
 * Onboarding 第 2 步:选服务商 + 填 API Key。
 * 不复用 ProviderDetailSheet/Page(30+ 字段过重),只做最小化的"选预设 + 单字段表单"。
 */
@ComponentV2
export struct OnboardingStepProvider {
  private vm: OnboardingViewModel = getOnboardingViewModel()

  private get themePrimary(): string {
    return getAppUiState().themePrimary
  }

  private get themeSurface(): string {
    return getAppUiState().themeSurface
  }

  build() {
    Column({ space: 16 }) {
      Column({ space: 8 }) {
        Text($r('app.string.onboarding_step2_title'))
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Text($r('app.string.onboarding_step2_desc'))
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
      .padding({ left: 24, right: 24 })

      Scroll() {
        Grid() {
          ForEach(getPresetProviders(), (provider: PresetProviderDef) => {
            GridItem() {
              this.ProviderCard(provider)
            }
          }, (provider: PresetProviderDef) => provider.id)
        }
        .columnsTemplate('1fr 1fr')
        .columnsGap(12)
        .rowsGap(12)
        .padding({ left: 24, right: 24 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)

      if (this.vm.selectedPresetProviderId !== '') {
        this.ApiKeyInputArea()
      }
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private ProviderCard(provider: PresetProviderDef) {
    Row({ space: 10 }) {
      Row() {
        Text(provider.textIcon)
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
      }
      .width(36)
      .height(36)
      .borderRadius(10)
      .backgroundColor(provider.textIconBgColor)
      .justifyContent(FlexAlign.Center)

      Text(provider.name)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
    }
    .width('100%')
    .padding(12)
    .borderRadius(12)
    .backgroundColor(this.themeSurface)
    .border({
      width: this.vm.selectedPresetProviderId === provider.id ? 2 : 1,
      color: this.vm.selectedPresetProviderId === provider.id ? this.themePrimary : $r('app.color.divider')
    })
    .scale(this.vm.selectedPresetProviderId === provider.id ? { x: 1.02, y: 1.02 } : { x: 1.0, y: 1.0 })
    .animation({ duration: 200, curve: Curve.EaseOut })
    .onClick(() => {
      this.vm.selectProvider(provider.id)
    })
  }

  @Builder
  private ApiKeyInputArea() {
    Column({ space: 8 }) {
      Text($r('app.string.onboarding_step2_apikey_label'))
        .fontSize(13)
        .fontColor($r('app.color.text_secondary'))
      TextInput({
        text: this.vm.apiKeyInput,
        placeholder: $r('app.string.onboarding_step2_apikey_placeholder')
      })
        .type(InputType.Password)
        .fontSize(15)
        .height(48)
        .borderRadius(12)
        .backgroundColor(this.themeSurface)
        .padding({ left: 14, right: 14 })
        .onChange((value: string) => {
          this.vm.apiKeyInput = value
          this.vm.lastError = ''
        })

      if (this.vm.lastError !== '') {
        Row({ space: 6 }) {
          SymbolGlyph($r('sys.symbol.exclamationmark_circle'))
            .fontSize(14)
            .fontColor([$r('app.color.status_error')])
          Text(this.vm.lastError)
            .fontSize(12)
            .fontColor($r('app.color.status_error'))
            .layoutWeight(1)
        }
        .width('100%')
        .padding({ top: 2 })
      }
    }
    .width('100%')
    .padding({ left: 24, right: 24, top: 4, bottom: 8 })
    .alignItems(HorizontalAlign.Start)
    .transition(TransitionEffect.OPACITY.combine(TransitionEffect.translate({ y: 8 }))
      .animation({ duration: 220, curve: Curve.EaseOut }))
  }
}
