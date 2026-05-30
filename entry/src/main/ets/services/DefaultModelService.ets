// 默认模型配置服务
import { DefaultModelConfig, ModelRole } from '../models/ChatModels'
import { DefaultPrompts } from '../config/DefaultPrompts'
import { getAppSettingsStore, AppSettingsStore } from '../state/AppSettingsStore'

// 默认模型服务 - 单例模式
//
// 已迁移到 AppSettingsStore：
// - 5 个 role 的 DefaultModelConfig（chat / title / suggestion / translate / image）
// - 4 个 Prompt 模板字段（title / suggestion / translate 模板 + translateTargetLanguage）
//
// 本服务目前只剩 Prompt 格式化 + facade 委托，
// 方便后续进一步拆解或合并到 Store
export class DefaultModelService {
  private static instance: DefaultModelService | null = null
  private store: AppSettingsStore

  private constructor() {
    this.store = getAppSettingsStore()
  }

  static getInstance(): DefaultModelService {
    if (DefaultModelService.instance === null) {
      DefaultModelService.instance = new DefaultModelService()
    }
    return DefaultModelService.instance
  }

  // 初始化加载配置（幂等）
  async initialize(): Promise<void> {
    await this.loadConfig()
  }

  // 加载所有配置（model + prompt 都走 Store）
  async loadConfig(): Promise<void> {
    await this.store.ensureDefaultModelsInitialized()
    await this.store.ensurePromptsInitialized()
  }

  // ============================================================================
  // Model（委托 Store）
  // ============================================================================

  getModel(role: ModelRole): DefaultModelConfig {
    return this.store.getDefaultModel(role)
  }

  async setModel(role: ModelRole, config: DefaultModelConfig): Promise<void> {
    await this.store.setDefaultModel(role, config)
  }

  getTitlePrompt(content: string, locale: string): string {
    let prompt = this.store.getTitlePromptTemplate()
    prompt = prompt.replace('{content}', content)
    prompt = prompt.replace('{locale}', locale)
    return prompt
  }

  getTranslatePrompt(sourceText: string, targetLang: string = ''): string {
    const lang = targetLang !== '' ? targetLang : this.store.getTranslateTargetLanguage()
    let prompt = this.store.getTranslatePromptTemplate()
    prompt = prompt.replace('{source_text}', sourceText)
    prompt = prompt.replace('{target_lang}', lang)
    return prompt
  }

  getSuggestionPrompt(content: string, locale: string): string {
    let prompt = this.store.getSuggestionPromptTemplate()
    prompt = prompt.replace('{content}', content)
    prompt = prompt.replace('{locale}', locale)
    return prompt
  }

  getTitlePromptTemplate(): string {
    return this.store.getTitlePromptTemplate()
  }

  getSuggestionPromptTemplate(): string {
    return this.store.getSuggestionPromptTemplate()
  }

  getTranslatePromptTemplate(): string {
    return this.store.getTranslatePromptTemplate()
  }

  getTranslateTargetLanguage(): string {
    return this.store.getTranslateTargetLanguage()
  }

  async setTitlePromptTemplate(prompt: string): Promise<void> {
    await this.store.setTitlePromptTemplate(prompt)
  }

  async setTranslatePromptTemplate(prompt: string): Promise<void> {
    await this.store.setTranslatePromptTemplate(prompt)
  }

  async setSuggestionPromptTemplate(prompt: string): Promise<void> {
    await this.store.setSuggestionPromptTemplate(prompt)
  }

  async resetTitlePrompt(): Promise<void> {
    await this.store.resetTitlePromptTemplate()
  }

  async resetSuggestionPrompt(): Promise<void> {
    await this.store.resetSuggestionPromptTemplate()
  }

  async resetTranslatePrompt(): Promise<void> {
    await this.store.resetTranslatePromptTemplate()
  }

  isDefaultTitlePrompt(): boolean {
    return this.store.getTitlePromptTemplate() === DefaultPrompts.TITLE_PROMPT
  }

  isDefaultTranslatePrompt(): boolean {
    return this.store.getTranslatePromptTemplate() === DefaultPrompts.TRANSLATE_PROMPT
  }

  isDefaultSuggestionPrompt(): boolean {
    return this.store.getSuggestionPromptTemplate() === DefaultPrompts.SUGGESTION_PROMPT
  }
}

// 导出单例实例获取方法
export function getDefaultModelService(): DefaultModelService {
  return DefaultModelService.getInstance()
}
