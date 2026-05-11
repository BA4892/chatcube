import { ModelProfileDef } from './types'
import { lookupBestModelDef } from './matcher'

// ============ 各推理能力簇 ============
//
// 设计:每个能力对应一组 ModelProfileDef + 一个 boolean 查询函数。
// 上层(CompatibilityResolver)按照 provider 决定的 strategy 调用对应函数,
// 由这层告诉它"该模型是否真的支持这条 strategy"。

// ---- OpenAI 风格 reasoning_effort:o1 / o3 / o4 / gpt-5 系列 ----
const OPENAI_REASONING_EFFORT_MODELS: ModelProfileDef[] = [
  { id: 'openai_o1', match: [{ startsWith: 'o1' }] },
  { id: 'openai_o3', match: [{ startsWith: 'o3' }] },
  { id: 'openai_o4', match: [{ startsWith: 'o4' }] },
  { id: 'openai_gpt5', match: [{ startsWith: 'gpt-5' }] }
]

// ---- OpenAI 风格 xhigh effort 子集:gpt-5.4 / gpt-5.3-codex / gpt-5.3-chat-latest / gpt-5.2 ----
const OPENAI_XHIGH_REASONING_MODELS: ModelProfileDef[] = [
  { id: 'gpt5_4', match: [{ startsWith: 'gpt-5.4' }] },
  { id: 'gpt5_3_codex', match: [{ startsWith: 'gpt-5.3-codex' }] },
  { id: 'gpt5_3_chat_latest', match: [{ startsWith: 'gpt-5.3-chat-latest' }] },
  { id: 'gpt5_2', match: [{ startsWith: 'gpt-5.2' }] }
]

// ---- MiniMax 模型(abab / minimax 前缀,大小写无关) ----
const MINIMAX_MODELS: ModelProfileDef[] = [
  { id: 'abab_series', match: [{ startsWith: 'abab' }] },
  { id: 'minimax_series', match: [{ startsWith: 'minimax' }] }
]

// ---- DashScope thinking:Qwen / QwQ / QvQ 前缀;也包括 `/qwen` `/qwq` `/qvq` 子串(中转格式) ----
const DASHSCOPE_THINKING_MODELS: ModelProfileDef[] = [
  { id: 'qwen_prefix', match: [{ startsWith: 'qwen' }] },
  { id: 'qwq_prefix', match: [{ startsWith: 'qwq' }] },
  { id: 'qvq_prefix', match: [{ startsWith: 'qvq' }] },
  // 中转格式:`<vendor>/qwen3-...` `<vendor>/qwq-...` 等。tokens 子序列足够覆盖
  { id: 'qwen_path', match: [{ tokens: ['/', 'qwen'] }] },
  { id: 'qwq_path', match: [{ tokens: ['/', 'qwq'] }] },
  { id: 'qvq_path', match: [{ tokens: ['/', 'qvq'] }] }
]

// ---- Kimi thinking:kimi-k2-thinking / kimi-k2.5 / kimi-k2.6 ----
const KIMI_THINKING_MODELS: ModelProfileDef[] = [
  { id: 'kimi_k2_thinking', match: [{ tokens: ['kimi', 'k', '2', 'thinking'] }] },
  { id: 'kimi_k2_5', match: [{ tokens: ['kimi', 'k', '2', '.', '5'] }] }
]

// ---- 智谱 GLM thinking ----
const ZHIPU_THINKING_MODELS: ModelProfileDef[] = [
  { id: 'glm', match: [{ startsWith: 'glm' }] }
]

// ---- Google Gemini thinking:`models/` 前缀已在查询入口剥离 ----
const GOOGLE_THINKING_MODELS: ModelProfileDef[] = [
  { id: 'gemini_2_5', match: [{ startsWith: 'gemini-2.5' }] },
  { id: 'gemini_3', match: [{ startsWith: 'gemini-3' }] },
  { id: 'gemini_robotics', match: [{ startsWith: 'gemini-robotics' }] }
]

// ---- SiliconFlow thinking:命名空间式 model id 清单 ----
const SILICONFLOW_THINKING_MODELS: ModelProfileDef[] = [
  { id: 'sf_glm5_pro', match: [{ startsWith: 'pro/zai-org/glm-5' }] },
  { id: 'sf_glm47_pro', match: [{ startsWith: 'pro/zai-org/glm-4.7' }] },
  { id: 'sf_glm46', match: [{ startsWith: 'zai-org/glm-4.6' }] },
  { id: 'sf_glm45v', match: [{ startsWith: 'zai-org/glm-4.5v' }] },
  { id: 'sf_dsv32', match: [{ startsWith: 'deepseek-ai/deepseek-v3.2' }] },
  { id: 'sf_dsv32_pro', match: [{ startsWith: 'pro/deepseek-ai/deepseek-v3.2' }] },
  { id: 'sf_dsv31_terminus', match: [{ startsWith: 'deepseek-ai/deepseek-v3.1-terminus' }] },
  { id: 'sf_dsv31_terminus_pro', match: [{ startsWith: 'pro/deepseek-ai/deepseek-v3.1-terminus' }] },
  { id: 'sf_qwen3_path', match: [{ startsWith: 'qwen/qwen3' }] },
  { id: 'sf_hunyuan_a13b', match: [{ exactId: 'tencent/hunyuan-a13b-instruct' }] }
]

// ============ 工具:剥离 Google 的 models/ 前缀 ============

function stripGoogleModelsPrefix(modelId: string): string {
  const trimmed = modelId.trim()
  const lower = trimmed.toLowerCase()
  if (lower.startsWith('models/')) {
    return trimmed.substring(7)
  }
  return trimmed
}

// ============ 公开查询函数 ============

export function isOpenAIReasoningEffortModel(modelId: string): boolean {
  return lookupBestModelDef(modelId, OPENAI_REASONING_EFFORT_MODELS) !== null
}

export function supportsOpenAIXhighReasoningModel(modelId: string): boolean {
  return lookupBestModelDef(modelId, OPENAI_XHIGH_REASONING_MODELS) !== null
}

export function isMiniMaxModelId(modelId: string): boolean {
  return lookupBestModelDef(modelId, MINIMAX_MODELS) !== null
}

export function isDashScopeThinkingModelId(modelId: string): boolean {
  return lookupBestModelDef(modelId, DASHSCOPE_THINKING_MODELS) !== null
}

export function isKimiThinkingModelId(modelId: string): boolean {
  return lookupBestModelDef(modelId, KIMI_THINKING_MODELS) !== null
}

export function supportsZhipuThinkingModel(modelId: string): boolean {
  return lookupBestModelDef(modelId, ZHIPU_THINKING_MODELS) !== null
}

export function supportsGoogleThinkingModel(modelId: string): boolean {
  const stripped = stripGoogleModelsPrefix(modelId)
  return lookupBestModelDef(stripped, GOOGLE_THINKING_MODELS) !== null
}

export function supportsSiliconFlowThinkingModel(modelId: string): boolean {
  return lookupBestModelDef(modelId, SILICONFLOW_THINKING_MODELS) !== null
}
