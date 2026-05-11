import { DEFAULT_PRIMARY_COLOR } from '../config/ThemeDefaults'

export const DEFAULT_ASSISTANT_ID: string = 'default'
export const ASSISTANT_CONTEXT_MESSAGE_SIZE_MAX: number = 100
export const ASSISTANT_MAX_TOKENS_LIMIT: number = 200000

@ObservedV2
export class Assistant {
  @Trace id: string = ''
  @Trace name: string = ''
  @Trace avatarSymbol: string = ''
  @Trace color: string = ''
  @Trace systemPrompt: string = ''
  @Trace defaultProviderId: string = ''
  @Trace defaultModelId: string = ''
  @Trace defaultModelName: string = ''
  @Trace temperatureEnabled: boolean = false
  @Trace temperature: number = 0.7
  @Trace topPEnabled: boolean = false
  @Trace topP: number = 1.0
  @Trace presencePenaltyEnabled: boolean = false
  @Trace presencePenalty: number = 0
  @Trace frequencyPenaltyEnabled: boolean = false
  @Trace frequencyPenalty: number = 0
  @Trace contextMessageSize: number = 0
  @Trace maxTokens: number = 0
  @Trace reasoningLevel: string = ''
  @Trace customHeadersJson: string = ''
  @Trace customBodiesJson: string = ''
  @Trace mcpServerIdsJson: string = ''
  @Trace quickMessageIdsJson: string = ''
  @Trace presetMessagesJson: string = ''
  @Trace tagsJson: string = ''
  @Trace isDefault: boolean = false
  @Trace createdAt: number = 0
  @Trace updatedAt: number = 0
  @Trace sortOrder: number = 0

  constructor(id: string = '', name: string = '') {
    const now = Date.now()
    this.id = id
    this.name = name
    this.avatarSymbol = 'AI'
    this.color = DEFAULT_PRIMARY_COLOR
    this.systemPrompt = ''
    this.defaultProviderId = ''
    this.defaultModelId = ''
    this.defaultModelName = ''
    this.temperatureEnabled = false
    this.temperature = 0.7
    this.topPEnabled = false
    this.topP = 1.0
    this.presencePenaltyEnabled = false
    this.presencePenalty = 0
    this.frequencyPenaltyEnabled = false
    this.frequencyPenalty = 0
    this.contextMessageSize = 0
    this.maxTokens = 0
    this.reasoningLevel = ''
    this.customHeadersJson = ''
    this.customBodiesJson = ''
    this.mcpServerIdsJson = ''
    this.quickMessageIdsJson = ''
    this.presetMessagesJson = ''
    this.tagsJson = ''
    this.isDefault = id === DEFAULT_ASSISTANT_ID
    this.createdAt = now
    this.updatedAt = now
    this.sortOrder = this.isDefault ? 0 : now
  }
}

export function createDefaultAssistant(): Assistant {
  const assistant = new Assistant(DEFAULT_ASSISTANT_ID, '默认助手')
  assistant.avatarSymbol = 'AI'
  assistant.color = DEFAULT_PRIMARY_COLOR
  assistant.isDefault = true
  assistant.sortOrder = 0
  return assistant
}
