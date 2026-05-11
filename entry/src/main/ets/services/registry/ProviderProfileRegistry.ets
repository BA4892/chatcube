import { ApiStyle } from '../../models/ChatModels'
import {
  CompatibilityProviderInfo,
  ProviderProfileDef,
  ProviderProfileFallback,
  ProviderCompatibilityProfile,
  ModelDiscoveryStrategy,
  OpenAIStreamContentMode,
  ReasoningControlMode,
  ReasoningRequestStrategy,
  DEFAULT_PROFILE,
  MINIMAX_COMPATIBLE_MODELS
} from './types'
import { lookupProviderProfile } from './matcher'

// ============ 命中规则声明 ============
// 顺序很重要:更具体的 def 写在前面。匹配是 first-match-wins。
const PROVIDER_PROFILES: ProviderProfileDef[] = [
  // MiniMax 走 OpenAI 风格 —— 静态模型清单,累积式流,且要保留 assistant reasoning details
  {
    id: 'minimax_openai_style',
    apiStyle: ApiStyle.OPENAI,
    match: {
      providerIds: ['minimax'],
      baseUrlIncludesAny: ['api.minimaxi.com', 'api.minimax.chat', 'api.minimax.io']
    },
    profile: {
      modelDiscoveryStrategy: ModelDiscoveryStrategy.STATIC_CATALOG,
      staticModels: MINIMAX_COMPATIBLE_MODELS,
      defaultTestModel: MINIMAX_COMPATIBLE_MODELS[0],
      openAIStreamContentMode: OpenAIStreamContentMode.CUMULATIVE,
      preserveAssistantReasoningDetails: true,
      reasoningControlMode: ReasoningControlMode.TOGGLE,
      defaultReasoningRequestStrategy: ReasoningRequestStrategy.OPENAI_REASONING_SPLIT
    }
  },

  // MiniMax 走 Anthropic 风格 —— 静态清单 + bearer 重试,不暴露推理控制
  {
    id: 'minimax_anthropic_style',
    apiStyle: ApiStyle.ANTHROPIC,
    match: {
      providerIds: ['minimax'],
      baseUrlIncludesAny: ['api.minimaxi.com', 'api.minimax.chat', 'api.minimax.io']
    },
    profile: {
      modelDiscoveryStrategy: ModelDiscoveryStrategy.STATIC_CATALOG,
      staticModels: MINIMAX_COMPATIBLE_MODELS,
      defaultTestModel: MINIMAX_COMPATIBLE_MODELS[0],
      anthropicBearerRetryOnAuthFailure: true
    }
  },

  // Anthropic 官方 —— EFFORT + ANTHROPIC_THINKING
  {
    id: 'anthropic_official',
    apiStyle: ApiStyle.ANTHROPIC,
    match: {
      providerIds: ['anthropic'],
      baseUrlIncludesAny: ['api.anthropic.com']
    },
    profile: {
      reasoningControlMode: ReasoningControlMode.EFFORT,
      defaultReasoningRequestStrategy: ReasoningRequestStrategy.ANTHROPIC_THINKING
    }
  },

  // OpenAI 官方 —— EFFORT + OPENAI_REASONING_EFFORT
  {
    id: 'openai_official',
    apiStyle: ApiStyle.OPENAI,
    match: {
      providerIds: ['openai'],
      baseUrlIncludesAny: ['api.openai.com']
    },
    profile: {
      reasoningControlMode: ReasoningControlMode.EFFORT,
      defaultReasoningRequestStrategy: ReasoningRequestStrategy.OPENAI_REASONING_EFFORT,
      // 官方 Responses API 支持 include=reasoning.encrypted_content, 跨轮保持推理状态
      supportsOpenAIResponsesEncryptedReasoning: true
    }
  },

  // DeepSeek 官方 —— HIGH_MAX + DEEPSEEK_THINKING
  {
    id: 'deepseek_official',
    apiStyle: ApiStyle.OPENAI,
    match: {
      providerIds: ['deepseek'],
      baseUrlEqualsAny: ['https://api.deepseek.com/v1', 'https://api.deepseek.com']
    },
    profile: {
      reasoningControlMode: ReasoningControlMode.HIGH_MAX,
      defaultReasoningRequestStrategy: ReasoningRequestStrategy.DEEPSEEK_THINKING
    }
  },

  // 智谱 AI —— TOGGLE + ZHIPU_THINKING
  {
    id: 'zhipu_official',
    apiStyle: ApiStyle.OPENAI,
    match: {
      providerIds: ['zhipu'],
      baseUrlIncludesAny: ['open.bigmodel.cn']
    },
    profile: {
      reasoningControlMode: ReasoningControlMode.TOGGLE,
      defaultReasoningRequestStrategy: ReasoningRequestStrategy.ZHIPU_THINKING
    }
  },

  // DashScope / 阿里通义 —— EFFORT + DASHSCOPE_THINKING
  {
    id: 'dashscope',
    apiStyle: ApiStyle.OPENAI,
    match: {
      providerIds: ['qwen'],
      baseUrlIncludesAny: ['dashscope.aliyuncs.com', 'dashscope-intl.aliyuncs.com']
    },
    profile: {
      reasoningControlMode: ReasoningControlMode.EFFORT,
      defaultReasoningRequestStrategy: ReasoningRequestStrategy.DASHSCOPE_THINKING
    }
  },

  // 月之暗面 / Kimi —— TOGGLE + KIMI_THINKING
  {
    id: 'moonshot',
    apiStyle: ApiStyle.OPENAI,
    match: {
      providerIds: ['moonshot', 'kimi'],
      baseUrlIncludesAny: ['api.moonshot.cn', 'api.moonshot.ai', 'platform.moonshot']
    },
    profile: {
      reasoningControlMode: ReasoningControlMode.TOGGLE,
      defaultReasoningRequestStrategy: ReasoningRequestStrategy.KIMI_THINKING
    }
  },

  // OpenRouter —— EFFORT + OPENROUTER_REASONING
  {
    id: 'openrouter',
    apiStyle: ApiStyle.OPENAI,
    match: {
      providerIds: ['openrouter'],
      baseUrlIncludesAny: ['openrouter.ai']
    },
    profile: {
      reasoningControlMode: ReasoningControlMode.EFFORT,
      defaultReasoningRequestStrategy: ReasoningRequestStrategy.OPENROUTER_REASONING
    }
  },

  // 硅基流动 —— EFFORT + SILICONFLOW_THINKING
  {
    id: 'siliconflow',
    apiStyle: ApiStyle.OPENAI,
    match: {
      providerIds: ['siliconflow'],
      baseUrlIncludesAny: ['api.siliconflow.cn']
    },
    profile: {
      reasoningControlMode: ReasoningControlMode.EFFORT,
      defaultReasoningRequestStrategy: ReasoningRequestStrategy.SILICONFLOW_THINKING
    }
  },

  // 小米 MiMo —— TOGGLE + MIMO_THINKING
  {
    id: 'mimo',
    apiStyle: ApiStyle.OPENAI,
    match: {
      providerIds: ['mimo'],
      baseUrlIncludesAny: ['api.xiaomimimo.com', 'token-plan-cn.xiaomimimo.com']
    },
    profile: {
      reasoningControlMode: ReasoningControlMode.TOGGLE,
      defaultReasoningRequestStrategy: ReasoningRequestStrategy.MIMO_THINKING
    }
  },

  // Google 官方 —— EFFORT + GOOGLE_THINKING_CONFIG
  {
    id: 'google_official',
    apiStyle: ApiStyle.GOOGLE,
    match: {
      providerIds: ['gemini', 'google'],
      baseUrlIncludesAny: ['generativelanguage.googleapis.com']
    },
    profile: {
      reasoningControlMode: ReasoningControlMode.EFFORT,
      defaultReasoningRequestStrategy: ReasoningRequestStrategy.GOOGLE_THINKING_CONFIG
    }
  }
]

// 仅按 apiStyle 命中的兜底,放在尾巴
const PROVIDER_FALLBACKS: ProviderProfileFallback[] = [
  // Anthropic 风格的第三方中转:bearer 重试兜底,不开推理控制
  {
    id: 'anthropic_third_party_fallback',
    apiStyle: ApiStyle.ANTHROPIC,
    profile: {
      anthropicBearerRetryOnAuthFailure: true
    }
  },
  // OpenAI 兼容中转(各家 newapi / oneapi / 自建网关):EFFORT + OPENAI_COMPAT
  {
    id: 'openai_compat_fallback',
    apiStyle: ApiStyle.OPENAI,
    profile: {
      reasoningControlMode: ReasoningControlMode.EFFORT,
      defaultReasoningRequestStrategy: ReasoningRequestStrategy.OPENAI_COMPAT_REASONING_EFFORT
    }
  }
]

// ============ 合并 + 公开函数 ============

function mergeWithDefault(partial: Partial<ProviderCompatibilityProfile>): ProviderCompatibilityProfile {
  return {
    modelDiscoveryStrategy: partial.modelDiscoveryStrategy !== undefined
      ? partial.modelDiscoveryStrategy
      : DEFAULT_PROFILE.modelDiscoveryStrategy,
    staticModels: partial.staticModels !== undefined ? partial.staticModels : DEFAULT_PROFILE.staticModels,
    defaultTestModel: partial.defaultTestModel !== undefined
      ? partial.defaultTestModel
      : DEFAULT_PROFILE.defaultTestModel,
    anthropicAuthStrategy: partial.anthropicAuthStrategy !== undefined
      ? partial.anthropicAuthStrategy
      : DEFAULT_PROFILE.anthropicAuthStrategy,
    anthropicBearerRetryOnAuthFailure: partial.anthropicBearerRetryOnAuthFailure !== undefined
      ? partial.anthropicBearerRetryOnAuthFailure
      : DEFAULT_PROFILE.anthropicBearerRetryOnAuthFailure,
    openAIStreamContentMode: partial.openAIStreamContentMode !== undefined
      ? partial.openAIStreamContentMode
      : DEFAULT_PROFILE.openAIStreamContentMode,
    preserveAssistantReasoningDetails: partial.preserveAssistantReasoningDetails !== undefined
      ? partial.preserveAssistantReasoningDetails
      : DEFAULT_PROFILE.preserveAssistantReasoningDetails,
    reasoningControlMode: partial.reasoningControlMode !== undefined
      ? partial.reasoningControlMode
      : DEFAULT_PROFILE.reasoningControlMode,
    defaultReasoningRequestStrategy: partial.defaultReasoningRequestStrategy !== undefined
      ? partial.defaultReasoningRequestStrategy
      : DEFAULT_PROFILE.defaultReasoningRequestStrategy,
    supportsOpenAIResponsesEncryptedReasoning: partial.supportsOpenAIResponsesEncryptedReasoning !== undefined
      ? partial.supportsOpenAIResponsesEncryptedReasoning
      : DEFAULT_PROFILE.supportsOpenAIResponsesEncryptedReasoning
  }
}

// 给定一个 provider info,返回完整的 profile(已经与 DEFAULT_PROFILE 合并);未命中任何 def/fallback 时返回 DEFAULT_PROFILE 副本
export function resolveProviderProfile(info: CompatibilityProviderInfo): ProviderCompatibilityProfile {
  const hit = lookupProviderProfile(info, PROVIDER_PROFILES, PROVIDER_FALLBACKS)
  if (hit === null) {
    return mergeWithDefault({})
  }
  return mergeWithDefault(hit.profile)
}
