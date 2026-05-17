/**
 * 模型能力派生工具
 * - capabilitiesUserModified === false:从 ModelAbilityRegistry 实时派生(规则升级自动跟随)
 * - capabilitiesUserModified === true:返回 model.capabilities 持久化值(用户手动覆盖)
 *
 * 单独成文件而非挂在 ModelInfo 上,避免 ChatModels → registry/types → ChatModels 的循环依赖
 */

import { ModelInfo, ModelCapabilities } from '../models/ChatModels'
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
