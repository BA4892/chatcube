import {
  InputMode,
  ModelCapabilities,
  ModelInfo,
  ModelInfoExtendedJson,
  ModelType,
  OutputMode
} from '../models/ChatModels'

function toModelType(raw?: string): ModelType {
  return raw === 'embedding' ? ModelType.EMBEDDING : ModelType.CHAT
}

function toInputMode(raw?: string): InputMode {
  return raw === InputMode.VISION ? InputMode.VISION : InputMode.TEXT
}

function toOutputMode(raw?: string): OutputMode {
  return raw === OutputMode.IMAGE ? OutputMode.IMAGE : OutputMode.TEXT
}

export function applyModelDraft(target: ModelInfo, draft: ModelInfoExtendedJson): void {
  target.name = draft.name
  target.contextLength = draft.contextLength
  target.isEnabled = draft.isEnabled
  target.isRecommended = draft.isRecommended

  if (draft.modelType !== undefined) {
    target.modelType = toModelType(draft.modelType)
  }
  if (draft.inputMode !== undefined) {
    target.inputMode = toInputMode(draft.inputMode)
  }
  if (draft.outputMode !== undefined) {
    target.outputMode = toOutputMode(draft.outputMode)
  }
  if (draft.capabilities !== undefined) {
    target.capabilities = ModelCapabilities.fromJson(draft.capabilities)
  }
  if (draft.reasoningStrategyOverride !== undefined) {
    target.reasoningStrategyOverride = draft.reasoningStrategyOverride
  }
}
