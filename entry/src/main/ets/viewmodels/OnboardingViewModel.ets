import { ThemeMode } from '../services/PreferencesService'
import { getSettingsManager } from './SettingsManager'
import { getProviderViewModel } from './ProviderViewModel'
import { getPresetProviderById } from '../config/PresetProviders'
import { ColorTheme } from '../models/ThemeColors'

/**
 * 首次启动引导的步骤。
 */
export enum OnboardingStep {
  THEME = 1,
  PROVIDER = 2,
  PROMPTS = 3
}

export const ONBOARDING_TOTAL_STEPS: number = 3

/**
 * 首次启动引导视图模型(单例)。
 * 跨 OnboardingOverlay + 3 个子组件共享状态。
 */
@ObservedV2
export class OnboardingViewModel {
  private static instance: OnboardingViewModel | null = null

  @Trace currentStep: OnboardingStep = OnboardingStep.THEME
  @Trace selectedThemeMode: ThemeMode = ThemeMode.SYSTEM
  @Trace selectedColorTheme: ColorTheme = ColorTheme.DEFAULT
  @Trace selectedPresetProviderId: string = ''
  @Trace apiKeyInput: string = ''
  @Trace applyingProvider: boolean = false
  @Trace lastError: string = ''

  private constructor() {
  }

  static getInstance(): OnboardingViewModel {
    if (OnboardingViewModel.instance === null) {
      OnboardingViewModel.instance = new OnboardingViewModel()
    }
    return OnboardingViewModel.instance
  }

  // 启动 / 重置 Onboarding 状态
  start(currentThemeMode: ThemeMode, currentColorTheme: ColorTheme): void {
    this.currentStep = OnboardingStep.THEME
    this.selectedThemeMode = currentThemeMode
    this.selectedColorTheme = currentColorTheme
    this.selectedPresetProviderId = ''
    this.apiKeyInput = ''
    this.applyingProvider = false
    this.lastError = ''
  }

  nextStep(): void {
    if (this.currentStep === OnboardingStep.THEME) {
      this.currentStep = OnboardingStep.PROVIDER
    } else if (this.currentStep === OnboardingStep.PROVIDER) {
      this.currentStep = OnboardingStep.PROMPTS
    }
  }

  prevStep(): void {
    if (this.currentStep === OnboardingStep.PROMPTS) {
      this.currentStep = OnboardingStep.PROVIDER
    } else if (this.currentStep === OnboardingStep.PROVIDER) {
      this.currentStep = OnboardingStep.THEME
    }
  }

  // 主题切换:走 SettingsManager 触发全局 callback,UI 立即变化
  async applyTheme(mode: ThemeMode): Promise<void> {
    this.selectedThemeMode = mode
    try {
      await getSettingsManager().setThemeMode(mode)
    } catch (err) {
      console.error('OnboardingViewModel', `Failed to apply theme: ${JSON.stringify(err)}`)
    }
  }

  // 配色切换:走 SettingsManager 触发全局 callback,主色调实时更新
  async applyColorTheme(theme: ColorTheme): Promise<void> {
    this.selectedColorTheme = theme
    try {
      await getSettingsManager().setColorTheme(theme)
    } catch (err) {
      console.error('OnboardingViewModel', `Failed to apply color theme: ${JSON.stringify(err)}`)
    }
  }

  selectProvider(presetId: string): void {
    if (this.selectedPresetProviderId !== presetId) {
      this.apiKeyInput = ''
    }
    this.selectedPresetProviderId = presetId
    this.lastError = ''
  }

  // 把用户填的 API Key 写入预设服务商(已由 initializeAllPresetProviders 创建)并启用
  // 返回:成功 true,失败 false(失败信息写入 lastError)
  async applyProvider(): Promise<boolean> {
    const providerId = this.selectedPresetProviderId
    const apiKey = this.apiKeyInput.trim()
    if (providerId === '' || apiKey === '') {
      this.lastError = 'invalid_input'
      return false
    }
    const preset = getPresetProviderById(providerId)
    if (preset === null) {
      this.lastError = 'preset_not_found'
      return false
    }
    this.applyingProvider = true
    try {
      const vm = getProviderViewModel()
      const provider = vm.getProviderById(providerId)
      if (provider === null) {
        this.lastError = 'provider_not_initialized'
        return false
      }
      provider.apiKey = apiKey
      await vm.saveProvider(provider, false)
      await vm.updateProviderEnabled(providerId, true)
      this.lastError = ''
      return true
    } catch (err) {
      console.error('OnboardingViewModel', `Failed to apply provider: ${JSON.stringify(err)}`)
      this.lastError = 'save_failed'
      return false
    } finally {
      this.applyingProvider = false
    }
  }
}

export function getOnboardingViewModel(): OnboardingViewModel {
  return OnboardingViewModel.getInstance()
}
