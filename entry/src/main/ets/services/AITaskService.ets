// AI 任务服务 - 处理标题生成和翻译
import { getAIApiService, AIApiService, AIApiConfig, RequestMessage } from './AIApiService'
import { getDefaultModelService, DefaultModelService } from './DefaultModelService'
import { getProviderViewModel, ProviderViewModel } from '../viewmodels/ProviderViewModel'
import { ReasoningRequestStrategy } from './registry/CompatibilityResolver'
import { ModelRole, ReasoningLevel } from '../models/ChatModels'
import { getEffectiveApiKey } from '../config/PresetProviders'
import { getEffectiveCapabilities } from '../utils/ModelCapabilityDeriver'

// 翻译/标题生成结果
export interface AITaskResult {
  success: boolean
  content: string
  errorMessage: string
}

export interface AITitleGenerationResult {
  success: boolean
  title: string
  usedFallback: boolean
  errorMessage: string
  retryable: boolean
}

// AI 任务服务 - 单例模式
export class AITaskService {
  private static instance: AITaskService | null = null
  private aiApiService: AIApiService
  private defaultModelService: DefaultModelService
  private providerViewModel: ProviderViewModel

  private constructor() {
    this.aiApiService = getAIApiService()
    this.defaultModelService = getDefaultModelService()
    this.providerViewModel = getProviderViewModel()
  }

  static getInstance(): AITaskService {
    if (AITaskService.instance === null) {
      AITaskService.instance = new AITaskService()
    }
    return AITaskService.instance
  }

  private truncateContentForSuggestedQuestions(content: string): string {
    const maxChars = 4000
    const maxLines = 80
    const lines = content.split('\n')
    let result = ''
    let lineCount = 0

    for (let i = Math.max(0, lines.length - maxLines); i < lines.length; i++) {
      if (lineCount >= maxLines) {
        break
      }
      const line = lines[i]
      const nextLength = result.length + line.length + (result === '' ? 0 : 1)
      if (nextLength > maxChars) {
        const remaining = maxChars - result.length
        if (remaining > 0) {
          if (result !== '') {
            result += '\n'
          }
          result += line.substring(0, remaining)
        }
        break
      }
      if (result !== '') {
        result += '\n'
      }
      result += line
      lineCount++
    }

    return result
  }

  // 检测文本语言（简单判断：中文字符占比）
  private detectLanguage(text: string): string {
    const chineseRegex = /[\u4e00-\u9fa5]/g
    const chineseMatches = text.match(chineseRegex)
    const chineseCount = chineseMatches !== null ? chineseMatches.length : 0
    const totalChars = text.replace(/\s/g, '').length

    if (totalChars === 0) {
      return 'Chinese'
    }

    // 中文字符占比超过 30% 认为是中文
    const chineseRatio = chineseCount / totalChars
    return chineseRatio > 0.3 ? 'Chinese' : 'English'
  }

  // 获取标题语言（优先 App 设置，其次自动检测）
  private getTitleLocale(content: string): string {
    return this.detectLanguage(content)
  }

  private getSuggestedQuestionsLocale(content: string, locale?: string): string {
    if (locale !== undefined && locale !== '') {
      return locale
    }
    return this.detectLanguage(content)
  }

  // 清理标题（去引号、换行、前缀、思考标签）
  private cleanTitle(rawTitle: string): string {
    let title = rawTitle.trim()

    // 去除模型思考标签（Qwen3 等模型的 <think>...</think>）
    title = title.replace(/<think>[\s\S]*?<\/think>/g, '').trim()

    // 去除首尾引号
    title = title.replace(/^["'""'']+|["'""'']+$/g, '')

    // 去除换行，只取第一行有效内容
    const lines = title.split(/[\r\n]+/)
    title = ''
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i].trim()
      if (line !== '') {
        title = line
        break
      }
    }

    // 去除多余空格
    title = title.replace(/\s+/g, ' ')

    // 去除常见前缀
    const prefixes = ['标题：', '标题:', 'Title:', 'Title：', '主题：', '主题:']
    for (let i = 0; i < prefixes.length; i++) {
      if (title.startsWith(prefixes[i])) {
        title = title.substring(prefixes[i].length).trim()
        break
      }
    }

    // 再次去除引号（去前缀后可能暴露出引号）
    title = title.replace(/^["'""'']+|["'""'']+$/g, '')

    return title.trim()
  }

  private cleanSuggestedQuestionsResponse(raw: string): string {
    let content = raw.trim()
    content = content.replace(/<think>[\s\S]*?<\/think>/g, '').trim()
    if (content.startsWith('```')) {
      const firstLineEnd = content.indexOf('\n')
      if (firstLineEnd >= 0) {
        content = content.substring(firstLineEnd + 1).trim()
      }
      if (content.endsWith('```')) {
        content = content.substring(0, content.length - 3).trim()
      }
    }
    return content
  }

  private parseSuggestedQuestions(raw: string): string[] {
    const content = this.cleanSuggestedQuestionsResponse(raw)
    if (content === '') {
      return []
    }
    const questions: string[] = []
    const lines = content.split(/[\r\n]+/)
    for (let i = 0; i < lines.length && questions.length < 3; i++) {
      this.appendSuggestedQuestion(questions, lines[i])
    }
    return questions
  }

  private appendSuggestedQuestion(questions: string[], rawQuestion: string): void {
    let question = rawQuestion.trim().replace(/\s+/g, ' ')
    question = question.replace(/^[-*•]\s*/, '').trim()
    question = question.replace(/^\d+[.)、]\s*/, '').trim()
    question = question.replace(/^["'""'']+|["'""'']+$/g, '').trim()
    if (question === '' || question.length > 40) {
      return
    }
    const punctuationOnly = /^[\s\p{P}]+$/u
    if (punctuationOnly.test(question)) {
      return
    }
    if (questions.indexOf(question) >= 0) {
      return
    }
    questions.push(question)
  }

  // 验证标题有效性
  private isValidTitle(title: string): boolean {
    if (title === '') {
      return false
    }
    // 不能全是标点符号
    const punctuationOnly = /^[\s\p{P}]+$/u
    if (punctuationOnly.test(title)) {
      return false
    }
    return true
  }

  private isRetryableTitleError(message: string): boolean {
    const normalized = message.toLowerCase()
    return !normalized.includes('api key') &&
      !normalized.includes('未配置') &&
      !normalized.includes('not configured') &&
      !normalized.includes('provider not found') &&
      !normalized.includes('model not configured')
  }

  private buildTitleFailureResult(
    errorMessage: string,
    retryable: boolean
  ): AITitleGenerationResult {
    return {
      success: false,
      title: '',
      usedFallback: false,
      errorMessage: errorMessage,
      retryable: retryable
    }
  }

  async generateTitleResult(conversationContent: string, locale?: string): Promise<AITitleGenerationResult> {
    const titleModel = this.defaultModelService.getModel(ModelRole.TITLE)
    const effectiveLocale = locale !== undefined && locale !== '' ? locale : this.getTitleLocale(conversationContent)

    if (!titleModel.isConfigured()) {
      const message = 'Title model not configured'
      console.error('AITaskService', message)
      return this.buildTitleFailureResult(message, false)
    }

    // 获取供应商信息（使用异步方法，确保缓存已加载）
    const provider = await this.providerViewModel.getProviderByIdAsync(titleModel.providerId)

    if (provider === null) {
      const message = 'Provider not found: ' + titleModel.providerId
      console.error('AITaskService', message)
      return this.buildTitleFailureResult(message, false)
    }

    // 获取有效的 API Key（优先用户配置，其次预设）
    const effectiveApiKey = getEffectiveApiKey(provider.id, provider.apiKey)
    if (effectiveApiKey === '') {
      const message = 'No API Key configured for provider: ' + provider.id
      console.error('AITaskService', message)
      return this.buildTitleFailureResult(message, false)
    }

    // 构建 API 配置
    const apiConfig: AIApiConfig = {
      providerId: provider.id,
      providerType: provider.type,
      apiStyle: provider.apiStyle,
      apiKey: effectiveApiKey,
      baseUrl: provider.baseUrl,
      apiPath: provider.apiPath !== '' ? provider.apiPath : undefined,
      openaiTransport: provider.openaiTransport,
      customHeadersJson: provider.customHeadersJson || undefined
    }

    for (let i = 0; i < provider.models.length; i++) {
      if (provider.models[i].id === titleModel.modelId) {
        apiConfig.modelReasoningStrategyOverride = ReasoningRequestStrategy.NONE
        break
      }
    }

    const messages: RequestMessage[] = [
      new RequestMessage('user', this.defaultModelService.getTitlePrompt(conversationContent, effectiveLocale))
    ]

    try {
      const result = await this.aiApiService.sendChatRequest(
        apiConfig,
        messages,
        titleModel.modelId,
        0.3,
        100,
        ReasoningLevel.OFF
      )
      if (result.success) {
        // 清理标题
        const title = this.cleanTitle(result.content)

        // 验证标题有效性
        if (this.isValidTitle(title)) {
          return {
            success: true,
            title: title,
            usedFallback: false,
            errorMessage: '',
            retryable: false
          }
        } else {
          console.warn('AITaskService', 'Generated title invalid: ' + title)
          return this.buildTitleFailureResult('Generated title invalid', false)
        }
      } else {
        console.error('AITaskService', 'Failed to generate title: ' + result.errorMessage)
        return this.buildTitleFailureResult(
          result.errorMessage,
          this.isRetryableTitleError(result.errorMessage)
        )
      }
    } catch (error) {
      const message = JSON.stringify(error)
      console.error('AITaskService', 'Error generating title: ' + message)
      return this.buildTitleFailureResult(
        message,
        this.isRetryableTitleError(message)
      )
    }
  }

  // 生成对话标题（兼容旧调用方，仅返回最终标题文本）
  async generateTitle(conversationContent: string, locale?: string): Promise<string> {
    const result = await this.generateTitleResult(conversationContent, locale)
    return result.title
  }

  async generateSuggestedQuestions(conversationContent: string, locale?: string): Promise<string[]> {
    const suggestionModel = this.defaultModelService.getModel(ModelRole.SUGGESTION)
    if (!suggestionModel.isConfigured()) {
      console.warn('AITaskService', 'Suggestion model not configured')
      return []
    }
    const provider = await this.providerViewModel.getProviderByIdAsync(suggestionModel.providerId)

    if (provider === null) {
      console.error('AITaskService', 'Provider not found for suggested questions: ' + suggestionModel.providerId)
      return []
    }

    const effectiveApiKey = getEffectiveApiKey(provider.id, provider.apiKey)
    if (effectiveApiKey === '') {
      console.error('AITaskService', 'No API Key configured for suggested questions provider: ' + provider.id)
      return []
    }

    const truncatedContent = this.truncateContentForSuggestedQuestions(conversationContent)
    if (truncatedContent.trim() === '') {
      return []
    }
    const effectiveLocale = this.getSuggestedQuestionsLocale(truncatedContent, locale)

    const apiConfig: AIApiConfig = {
      providerId: provider.id,
      providerType: provider.type,
      apiStyle: provider.apiStyle,
      apiKey: effectiveApiKey,
      baseUrl: provider.baseUrl,
      apiPath: provider.apiPath !== '' ? provider.apiPath : undefined,
      openaiTransport: provider.openaiTransport,
      customHeadersJson: provider.customHeadersJson || undefined
    }

    for (let i = 0; i < provider.models.length; i++) {
      if (provider.models[i].id === suggestionModel.modelId) {
        apiConfig.modelReasoningStrategyOverride = ReasoningRequestStrategy.NONE
        break
      }
    }

    const messages: RequestMessage[] = [
      new RequestMessage('user', this.defaultModelService.getSuggestionPrompt(truncatedContent, effectiveLocale))
    ]

    try {
      const result = await this.aiApiService.sendChatRequest(
        apiConfig,
        messages,
        suggestionModel.modelId,
        0.4,
        300,
        ReasoningLevel.OFF
      )
      if (!result.success) {
        console.warn('AITaskService', 'Failed to generate suggested questions: ' + result.errorMessage)
        return []
      }
      return this.parseSuggestedQuestions(result.content)
    } catch (error) {
      console.error('AITaskService', 'Error generating suggested questions: ' + JSON.stringify(error))
      return []
    }
  }

  // 翻译文本
  async translateText(sourceText: string, targetLang: string = ''): Promise<AITaskResult> {
    const translateModel = this.defaultModelService.getModel(ModelRole.TRANSLATE)

    // 获取供应商信息（使用异步方法，确保缓存已加载）
    const provider = await this.providerViewModel.getProviderByIdAsync(translateModel.providerId)

    if (provider === null) {
      console.error('AITaskService', 'Provider not found: ' + translateModel.providerId)
      return { success: false, content: '', errorMessage: '未找到翻译模型对应的服务商' }
    }

    // 获取有效的 API Key（优先用户配置，其次预设）
    const effectiveApiKey = getEffectiveApiKey(provider.id, provider.apiKey)
    if (effectiveApiKey === '') {
      console.error('AITaskService', 'No API Key configured for provider: ' + provider.id)
      return { success: false, content: '', errorMessage: `请为 ${provider.name} 配置 API Key` }
    }

    // 构建 API 配置
    const apiConfig: AIApiConfig = {
      providerId: provider.id,
      providerType: provider.type,
      apiStyle: provider.apiStyle,
      apiKey: effectiveApiKey,
      baseUrl: provider.baseUrl,
      apiPath: provider.apiPath !== '' ? provider.apiPath : undefined,
      openaiTransport: provider.openaiTransport,
      customHeadersJson: provider.customHeadersJson || undefined
    }
    for (let i = 0; i < provider.models.length; i++) {
      if (provider.models[i].id === translateModel.modelId) {
        apiConfig.modelReasoningStrategyOverride = ''
        apiConfig.modelSupportsReasoning = getEffectiveCapabilities(provider.models[i]).supportsReasoning
        break
      }
    }

    // 构建 Prompt
    const prompt = this.defaultModelService.getTranslatePrompt(sourceText, targetLang)
    const messages: RequestMessage[] = [
      new RequestMessage('user', prompt)
    ]

    try {
      const result = await this.aiApiService.sendChatRequest(
        apiConfig,
        messages,
        translateModel.modelId,
        0.3,  // 低温度以获得更准确的翻译
        4096  // 翻译可能需要较多 token
      )

      if (result.success) {
        return { success: true, content: result.content.trim(), errorMessage: '' }
      } else {
        // 检查是否是 401 认证错误
        let errorMessage = result.errorMessage
        if (errorMessage.includes('401') || errorMessage.toLowerCase().includes('unauthorized') || errorMessage.toLowerCase().includes('authentication')) {
          errorMessage = `API Key 认证失败，请检查 ${provider.name} 的 API Key 是否正确`
        }
        console.error('AITaskService', 'Failed to translate: ' + result.errorMessage)
        return { success: false, content: '', errorMessage: errorMessage }
      }
    } catch (error) {
      console.error('AITaskService', 'Error translating: ' + JSON.stringify(error))
      return { success: false, content: '', errorMessage: '翻译失败：' + JSON.stringify(error) }
    }
  }

  async optimizeImagePrompt(sourcePrompt: string, isEditing: boolean, referenceImageCount: number): Promise<AITaskResult> {
    const normalizedPrompt = sourcePrompt.trim()
    if (normalizedPrompt === '') {
      return { success: false, content: '', errorMessage: '请输入需要优化的提示词' }
    }

    const chatModel = this.defaultModelService.getModel(ModelRole.CHAT)
    if (!chatModel.isConfigured()) {
      return { success: false, content: '', errorMessage: '请先配置默认聊天模型' }
    }

    const provider = await this.providerViewModel.getProviderByIdAsync(chatModel.providerId)
    if (provider === null) {
      return { success: false, content: '', errorMessage: '未找到默认聊天模型对应的服务商' }
    }

    const effectiveApiKey = getEffectiveApiKey(provider.id, provider.apiKey)
    if (effectiveApiKey === '') {
      return { success: false, content: '', errorMessage: `请为 ${provider.name} 配置 API Key` }
    }

    const apiConfig: AIApiConfig = {
      providerId: provider.id,
      providerType: provider.type,
      apiStyle: provider.apiStyle,
      apiKey: effectiveApiKey,
      baseUrl: provider.baseUrl,
      apiPath: provider.apiPath !== '' ? provider.apiPath : undefined,
      openaiTransport: provider.openaiTransport,
      customHeadersJson: provider.customHeadersJson || undefined
    }

    for (let i = 0; i < provider.models.length; i++) {
      if (provider.models[i].id === chatModel.modelId) {
        apiConfig.modelReasoningStrategyOverride = ReasoningRequestStrategy.NONE
        break
      }
    }

    const taskDesc = isEditing ?
      `图像编辑。当前已有 ${referenceImageCount} 张参考图,提示词应聚焦需要保留和需要调整的内容。` :
      '文生图。提示词应完整描述主体、场景、构图、光线、风格和关键细节。'
    const messages: RequestMessage[] = [
      new RequestMessage('system',
        '你是图像生成提示词优化器。请将用户输入改写成可直接用于图像生成或图像编辑模型的高质量提示词。' +
          '必须保留用户原始意图,可以补充清晰的视觉细节、构图、镜头、光线、材质、氛围和质量要求。' +
          '不要添加解释、标题、编号、Markdown、代码块或引号。只输出优化后的提示词正文。'),
      new RequestMessage('user', `任务类型: ${taskDesc}\n原始提示词:\n${normalizedPrompt}`)
    ]

    try {
      const result = await this.aiApiService.sendChatRequest(
        apiConfig,
        messages,
        chatModel.modelId,
        0.4,
        900,
        ReasoningLevel.OFF
      )
      if (!result.success) {
        return { success: false, content: '', errorMessage: this.formatImagePromptOptimizeError(result.errorMessage) }
      }
      const optimizedPrompt = this.cleanOptimizedImagePrompt(result.content)
      if (optimizedPrompt === '') {
        return { success: false, content: '', errorMessage: '提示词优化失败：模型未返回可用提示词' }
      }
      return { success: true, content: optimizedPrompt, errorMessage: '' }
    } catch (error) {
      console.error('AITaskService', 'Error optimizing image prompt: ' + JSON.stringify(error))
      return { success: false, content: '', errorMessage: '提示词优化失败：' + JSON.stringify(error) }
    }
  }

  private cleanOptimizedImagePrompt(rawPrompt: string): string {
    let prompt = rawPrompt.trim()
    prompt = prompt.replace(/<think>[\s\S]*?<\/think>/g, '').trim()
    prompt = prompt.replace(/^```[a-zA-Z]*\s*/g, '').replace(/```$/g, '').trim()

    const lines = prompt.split(/[\r\n]+/)
    const cleanedLines: string[] = []
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i].trim()
      if (line !== '') {
        cleanedLines.push(line.replace(/^[-*•\d.、\s]+/, '').trim())
      }
    }
    prompt = cleanedLines.join(' ')

    const prefixes = ['优化后的提示词：', '优化后的提示词:', '优化提示词：', '优化提示词:', 'Prompt:', 'Prompt：']
    for (let i = 0; i < prefixes.length; i++) {
      if (prompt.startsWith(prefixes[i])) {
        prompt = prompt.substring(prefixes[i].length).trim()
        break
      }
    }
    prompt = prompt.replace(/^["'""'']+|["'""'']+$/g, '').trim()
    return prompt
  }

  private formatImagePromptOptimizeError(errorMessage: string): string {
    const normalized = errorMessage.trim()
    if (normalized === '' || normalized === 'No output in response' || normalized === 'No choices in response' ||
      normalized === 'No content in response' || normalized === 'No candidates in response') {
      return '提示词优化失败：模型未返回可用提示词'
    }
    if (normalized.startsWith('Failed to parse response') || normalized.indexOf('无法解析响应') >= 0 ||
      normalized.indexOf('返回内容格式异常') >= 0) {
      return '提示词优化失败：模型返回内容格式异常'
    }
    return normalized
  }
}

// 导出单例实例获取方法
export function getAITaskService(): AITaskService {
  return AITaskService.getInstance()
}
