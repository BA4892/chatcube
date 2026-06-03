import { ThemeMode } from '../services/PreferencesService'
import { getSettingsManager } from './SettingsManager'
import { getProviderViewModel } from './ProviderViewModel'
import { getPresetProviderById } from '../config/PresetProviders'
import { ColorTheme } from '../models/ThemeColors'
import { DefaultModelConfig, ModelInfo, ModelProvider, ModelRole, OutputMode } from '../models/ChatModels'
import { buildSelectedModelsWithPreservedConfig } from '../config/ProviderModelActions'
import { getDefaultModelService } from '../services/DefaultModelService'
import { getAppStateManager } from './AppStateManager'
import { getEffectiveOutputMode } from '../utils/ModelCapabilityDeriver'

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

  private applyFetchedModels(provider: ModelProvider, fetchedModelIds: string[]): void {
    const newModels = buildSelectedModelsWithPreservedConfig(provider.models, fetchedModelIds)

    // 保留不在远端列表中的已有模型,和正式模型管理页的"获取模型"行为一致。
    const fetchedSet = new Set<string>(fetchedModelIds)
    const newModelIdSet = new Set<string>()
    for (let i = 0; i < newModels.length; i++) {
      newModelIdSet.add(newModels[i].id)
    }
    for (let i = 0; i < provider.models.length; i++) {
      const model = provider.models[i]
      if (!fetchedSet.has(model.id) && !newModelIdSet.has(model.id)) {
        newModels.push(model)
      }
    }

    provider.models = newModels
  }

  private findDefaultChatModel(provider: ModelProvider): ModelInfo | null {
    for (let i = 0; i < provider.models.length; i++) {
      const model = provider.models[i]
      if (getEffectiveOutputMode(model) === OutputMode.TEXT) {
        return model
      }
    }
    return null
  }

  private async persistDefaultChatModel(provider: ModelProvider, model: ModelInfo): Promise<void> {
    const modelName = model.name !== '' ? model.name : model.id
    const config = new DefaultModelConfig(model.id, provider.id, modelName, provider.name)
    await getDefaultModelService().setModel(ModelRole.CHAT, config)
    await getAppStateManager().setCurrentModel(model.id, modelName, provider.id)
  }

  // 把用户填的 API Key 写入预设服务商,获取模型列表,并自动设置默认聊天模型。
  // 返回:成功 true,失败 false(失败信息写入 lastError)
  async applyProvider(): Promise<boolean> {
    const providerId = this.selectedPresetProviderId
    const apiKey = this.apiKeyInput.trim()
    if (providerId === '' || apiKey === '') {
      this.lastError = '请选择服务商并填写 API Key'
      return false
    }
    const preset = getPresetProviderById(providerId)
    if (preset === null) {
      this.lastError = '未找到该预设服务商'
      return false
    }
    this.applyingProvider = true
    try {
      const vm = getProviderViewModel()
      await vm.initializeAllPresetProviders()
      const provider = await vm.getProviderByIdAsync(providerId)
      if (provider === null) {
        this.lastError = '服务商初始化失败，请稍后重试'
        return false
      }
      provider.apiKey = apiKey
      await vm.saveProvider(provider, false)

      const modelsResult = await vm.refreshModels(provider)
      if (!modelsResult.success) {
        this.lastError = modelsResult.errorMessage !== '' ? modelsResult.errorMessage : '获取模型失败'
        return false
      }
      if (modelsResult.models.length === 0) {
        this.lastError = '服务商没有返回可用模型'
        return false
      }

      this.applyFetchedModels(provider, modelsResult.models)
      const chatModel = this.findDefaultChatModel(provider)
      if (chatModel === null) {
        this.lastError = '未找到可用于对话的文本模型'
        return false
      }

      chatModel.isEnabled = true
      provider.isConnected = true
      await vm.saveProvider(provider, false)
      await this.persistDefaultChatModel(provider, chatModel)
      this.lastError = ''
      return true
    } catch (err) {
      console.error('OnboardingViewModel', `Failed to apply provider: ${JSON.stringify(err)}`)
      this.lastError = '保存服务商或获取模型失败'
      return false
    } finally {
      this.applyingProvider = false
    }
  }
}

export function getOnboardingViewModel(): OnboardingViewModel {
  return OnboardingViewModel.getInstance()
}
