import { ReasoningLevel } from '../../models/ChatModels'
import {
  CompatibilityProviderInfo,
  ProviderCompatibilityProfile,
  ReasoningControlMode,
  ReasoningRequestStrategy
} from './types'
import { resolveProviderProfile } from './ProviderProfileRegistry'
import {
  isOpenAIReasoningEffortModel,
  supportsOpenAIXhighReasoningModel,
  isMiniMaxModelId,
  isDeepSeekV4Model,
  isDashScopeThinkingModelId,
  isKimiThinkingModelId,
  supportsZhipuThinkingModel,
  supportsGoogleThinkingModel,
  supportsSiliconFlowThinkingModel
} from './ModelProfileRegistry'

// ============ 公开 enum / interface / 常量 re-export(对外契约) ============
export {
  CompatibilityProviderInfo,
  ProviderCompatibilityProfile,
  ModelDiscoveryStrategy,
  AnthropicAuthStrategy,
  OpenAIStreamContentMode,
  ReasoningControlMode,
  ReasoningRequestStrategy,
  MINIMAX_COMPATIBLE_MODELS
} from './types'
export { normalizeCompatibilityBaseUrl } from './matcher'
export { isMiniMaxModelId } from './ModelProfileRegistry'

// ============ 公开函数 ============

export function resolveProviderCompatibilityProfile(info: CompatibilityProviderInfo): ProviderCompatibilityProfile {
  return resolveProviderProfile(info)
}

// 根据 provider profile 期望的 strategy + modelId 精化最终 strategy
export function resolveReasoningRequestStrategy(
  info: CompatibilityProviderInfo,
  modelId: string
): ReasoningRequestStrategy {
  const profile = resolveProviderProfile(info)
  switch (profile.defaultReasoningRequestStrategy) {
    case ReasoningRequestStrategy.OPENAI_REASONING_EFFORT:
      return isOpenAIReasoningEffortModel(modelId)
        ? ReasoningRequestStrategy.OPENAI_REASONING_EFFORT
        : ReasoningRequestStrategy.NONE
    case ReasoningRequestStrategy.OPENAI_COMPAT_REASONING_EFFORT:
      if (isMiniMaxModelId(modelId)) {
        return ReasoningRequestStrategy.OPENAI_REASONING_SPLIT
      }
      if (isDeepSeekV4Model(modelId)) {
        // DeepSeek V4 官方协议(thinking + reasoning_effort=high|max)只暴露 2 档,
        // 中转聚合服务(newapi/oneapi/aihubmix)透传 thinking 字段后由 DeepSeek 后端按官方协议处理。
        return ReasoningRequestStrategy.DEEPSEEK_THINKING
      }
      if (isDashScopeThinkingModelId(modelId)) {
        return ReasoningRequestStrategy.DASHSCOPE_THINKING
      }
      if (isKimiThinkingModelId(modelId)) {
        return ReasoningRequestStrategy.KIMI_THINKING
      }
      return ReasoningRequestStrategy.OPENAI_COMPAT_REASONING_EFFORT
    case ReasoningRequestStrategy.OPENAI_REASONING_SPLIT:
      return isMiniMaxModelId(modelId)
        ? ReasoningRequestStrategy.OPENAI_REASONING_SPLIT
        : ReasoningRequestStrategy.NONE
    case ReasoningRequestStrategy.OPENROUTER_REASONING:
      return ReasoningRequestStrategy.OPENROUTER_REASONING
    case ReasoningRequestStrategy.DEEPSEEK_THINKING:
      return ReasoningRequestStrategy.DEEPSEEK_THINKING
    case ReasoningRequestStrategy.MIMO_THINKING:
      return ReasoningRequestStrategy.MIMO_THINKING
    case ReasoningRequestStrategy.ZHIPU_THINKING:
      return supportsZhipuThinkingModel(modelId)
        ? ReasoningRequestStrategy.ZHIPU_THINKING
        : ReasoningRequestStrategy.NONE
    case ReasoningRequestStrategy.DASHSCOPE_THINKING:
      return ReasoningRequestStrategy.DASHSCOPE_THINKING
    case ReasoningRequestStrategy.KIMI_THINKING:
      return isKimiThinkingModelId(modelId)
        ? ReasoningRequestStrategy.KIMI_THINKING
        : ReasoningRequestStrategy.NONE
    case ReasoningRequestStrategy.GOOGLE_THINKING_CONFIG:
      return supportsGoogleThinkingModel(modelId)
        ? ReasoningRequestStrategy.GOOGLE_THINKING_CONFIG
        : ReasoningRequestStrategy.NONE
    case ReasoningRequestStrategy.SILICONFLOW_THINKING:
      return supportsSiliconFlowThinkingModel(modelId)
        ? ReasoningRequestStrategy.SILICONFLOW_THINKING
        : ReasoningRequestStrategy.NONE
    default:
      return profile.defaultReasoningRequestStrategy
  }
}

// 用户覆盖字段(字符串)→ enum;支持旧别名(thinking_budget 之类)
function parseReasoningStrategyOverride(rawOverride?: string): ReasoningRequestStrategy | null {
  switch (rawOverride) {
    case ReasoningRequestStrategy.NONE:
      return ReasoningRequestStrategy.NONE
    case ReasoningRequestStrategy.OPENAI_REASONING_EFFORT:
      return ReasoningRequestStrategy.OPENAI_REASONING_EFFORT
    case ReasoningRequestStrategy.OPENAI_COMPAT_REASONING_EFFORT:
      return ReasoningRequestStrategy.OPENAI_COMPAT_REASONING_EFFORT
    case ReasoningRequestStrategy.OPENAI_REASONING_SPLIT:
      return ReasoningRequestStrategy.OPENAI_REASONING_SPLIT
    case ReasoningRequestStrategy.OPENROUTER_REASONING:
      return ReasoningRequestStrategy.OPENROUTER_REASONING
    case ReasoningRequestStrategy.ANTHROPIC_THINKING:
      return ReasoningRequestStrategy.ANTHROPIC_THINKING
    case ReasoningRequestStrategy.DEEPSEEK_THINKING:
      return ReasoningRequestStrategy.DEEPSEEK_THINKING
    case ReasoningRequestStrategy.MIMO_THINKING:
      return ReasoningRequestStrategy.MIMO_THINKING
    case ReasoningRequestStrategy.ZHIPU_THINKING:
      return ReasoningRequestStrategy.ZHIPU_THINKING
    case ReasoningRequestStrategy.DASHSCOPE_THINKING:
    case 'dashscope_thinking_budget':
      return ReasoningRequestStrategy.DASHSCOPE_THINKING
    case ReasoningRequestStrategy.KIMI_THINKING:
      return ReasoningRequestStrategy.KIMI_THINKING
    case ReasoningRequestStrategy.GOOGLE_THINKING_CONFIG:
      return ReasoningRequestStrategy.GOOGLE_THINKING_CONFIG
    case ReasoningRequestStrategy.SILICONFLOW_THINKING:
    case 'siliconflow_thinking_budget':
      return ReasoningRequestStrategy.SILICONFLOW_THINKING
    default:
      return null
  }
}

function getReasoningControlModeForStrategy(strategy: ReasoningRequestStrategy): ReasoningControlMode {
  switch (strategy) {
    case ReasoningRequestStrategy.OPENAI_REASONING_EFFORT:
    case ReasoningRequestStrategy.OPENAI_COMPAT_REASONING_EFFORT:
    case ReasoningRequestStrategy.OPENROUTER_REASONING:
    case ReasoningRequestStrategy.ANTHROPIC_THINKING:
    case ReasoningRequestStrategy.DASHSCOPE_THINKING:
    case ReasoningRequestStrategy.GOOGLE_THINKING_CONFIG:
    case ReasoningRequestStrategy.SILICONFLOW_THINKING:
      return ReasoningControlMode.EFFORT
    case ReasoningRequestStrategy.DEEPSEEK_THINKING:
      return ReasoningControlMode.HIGH_MAX
    case ReasoningRequestStrategy.OPENAI_REASONING_SPLIT:
    case ReasoningRequestStrategy.MIMO_THINKING:
    case ReasoningRequestStrategy.ZHIPU_THINKING:
    case ReasoningRequestStrategy.KIMI_THINKING:
      return ReasoningControlMode.TOGGLE
    default:
      return ReasoningControlMode.NONE
  }
}

export function resolveReasoningControlMode(
  info: CompatibilityProviderInfo,
  modelId: string,
  modelSupportsReasoning: boolean,
  rawOverride?: string
): ReasoningControlMode {
  if (!modelSupportsReasoning) {
    return ReasoningControlMode.NONE
  }

  const overrideStrategy = parseReasoningStrategyOverride(rawOverride)
  if (overrideStrategy !== null) {
    return getReasoningControlModeForStrategy(overrideStrategy)
  }

  const profile = resolveProviderProfile(info)
  if (profile.reasoningControlMode === ReasoningControlMode.NONE) {
    return ReasoningControlMode.NONE
  }

  const strategy = resolveReasoningRequestStrategy(info, modelId)
  return getReasoningControlModeForStrategy(strategy)
}

export function resolveReasoningRequestStrategyWithOverride(
  info: CompatibilityProviderInfo,
  modelId: string,
  rawOverride?: string
): ReasoningRequestStrategy {
  const overrideStrategy = parseReasoningStrategyOverride(rawOverride)
  if (overrideStrategy !== null) {
    return overrideStrategy
  }
  return resolveReasoningRequestStrategy(info, modelId)
}

export function supportsReasoningControl(
  info: CompatibilityProviderInfo,
  modelId: string,
  modelSupportsReasoning: boolean,
  rawOverride?: string
): boolean {
  return resolveReasoningControlMode(info, modelId, modelSupportsReasoning, rawOverride) !== ReasoningControlMode.NONE
}

export function supportsReasoningXhighControl(
  info: CompatibilityProviderInfo,
  modelId: string,
  modelSupportsReasoning: boolean,
  rawOverride?: string
): boolean {
  const controlMode = resolveReasoningControlMode(info, modelId, modelSupportsReasoning, rawOverride)
  if (controlMode !== ReasoningControlMode.EFFORT && controlMode !== ReasoningControlMode.HIGH_MAX) {
    return false
  }
  if (controlMode === ReasoningControlMode.HIGH_MAX) {
    return true
  }
  const strategy = resolveReasoningRequestStrategyWithOverride(info, modelId, rawOverride)
  if (strategy === ReasoningRequestStrategy.OPENAI_COMPAT_REASONING_EFFORT) {
    return true
  }
  if (strategy === ReasoningRequestStrategy.OPENAI_REASONING_EFFORT) {
    return supportsOpenAIXhighReasoningModel(modelId)
  }
  return false
}

export function normalizeReasoningLevelForControl(
  level: ReasoningLevel,
  controlMode: ReasoningControlMode = ReasoningControlMode.EFFORT
): ReasoningLevel {
  if (controlMode === ReasoningControlMode.NONE) {
    return ReasoningLevel.OFF
  }
  if (level === ReasoningLevel.OFF) {
    return ReasoningLevel.OFF
  }
  if (controlMode === ReasoningControlMode.TOGGLE) {
    return ReasoningLevel.AUTO
  }
  if (controlMode === ReasoningControlMode.HIGH_MAX) {
    switch (level) {
      case ReasoningLevel.AUTO:
      case ReasoningLevel.XHIGH:
        return level
      case ReasoningLevel.LOW:
      case ReasoningLevel.MEDIUM:
      case ReasoningLevel.HIGH:
      default:
        return ReasoningLevel.HIGH
    }
  }
  switch (level) {
    case ReasoningLevel.AUTO:
    case ReasoningLevel.LOW:
    case ReasoningLevel.MEDIUM:
    case ReasoningLevel.HIGH:
    case ReasoningLevel.XHIGH:
      return level
    default:
      return ReasoningLevel.AUTO
  }
}
