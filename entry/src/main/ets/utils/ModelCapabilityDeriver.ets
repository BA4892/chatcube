/**
 * 模型能力派生工具
 * - capabilitiesUserModified === false:从 ModelAbilityRegistry 实时派生(规则升级自动跟随)
 * - capabilitiesUserModified === true:返回 model.capabilities 持久化值(用户手动覆盖)
 *
 * 单独成文件而非挂在 ModelInfo 上,避免 ChatModels → registry/types → ChatModels 的循环依赖
 */

import { InputMode, ModelInfo, ModelCapabilities, OutputMode } from '../models/ChatModels'
import { lookupModelAbilities, ModelAbility, ModelModality } from '../services/registry/ModelAbilityRegistry'

export function deriveModelCapabilities(modelId: string): ModelCapabilities {
  const result = lookupModelAbilities(modelId)
  const cap = new ModelCapabilities()
  cap.supportsTools = result.abilities.includes(ModelAbility.TOOL)
  cap.supportsReasoning = result.abilities.includes(ModelAbility.REASONING)
  cap.supportsVision = result.inputModalities.includes(ModelModality.IMAGE)
  cap.supportsWebSearch = false
  cap.supportsStreaming = true
  return cap
}

export function getEffectiveCapabilities(model: ModelInfo): ModelCapabilities {
  if (model.capabilitiesUserModified) {
    return model.capabilities
  }
  return deriveModelCapabilities(model.id)
}

export function deriveModelInputMode(modelId: string): InputMode {
  const result = lookupModelAbilities(modelId)
  return result.inputModalities.includes(ModelModality.IMAGE) ? InputMode.VISION : InputMode.TEXT
}

export function deriveModelOutputMode(modelId: string): OutputMode {
  const result = lookupModelAbilities(modelId)
  if (result.abilities.includes(ModelAbility.IMAGE_GENERATION) ||
    result.outputModalities.includes(ModelModality.IMAGE)) {
    return OutputMode.IMAGE
  }
  return OutputMode.TEXT
}

export function getEffectiveOutputMode(model: ModelInfo): OutputMode {
  if (model.capabilitiesUserModified) {
    return model.outputMode
  }
  const derived = deriveModelOutputMode(model.id)
  return derived === OutputMode.IMAGE ? OutputMode.IMAGE : model.outputMode
}

export function applyDerivedModelDefaults(model: ModelInfo): void {
  if (model.capabilitiesUserModified) {
    return
  }
  model.capabilities = deriveModelCapabilities(model.id)
  const derivedInputMode = deriveModelInputMode(model.id)
  if (derivedInputMode === InputMode.VISION) {
    model.inputMode = InputMode.VISION
  }
  const derivedOutputMode = deriveModelOutputMode(model.id)
  if (derivedOutputMode === OutputMode.IMAGE) {
    model.outputMode = OutputMode.IMAGE
  }
}
