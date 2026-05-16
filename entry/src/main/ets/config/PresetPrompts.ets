/**
 * 推荐提示词预设
 * 用于首次启动引导第 3 步、主页空状态、平板分栏右侧空状态。
 */

import { common } from '@kit.AbilityKit'

export interface PresetPrompt {
  // 唯一 id,用作 ForEach key(避免单纯 index 复用陷阱)
  id: string
  // 卡片显示标题
  title: Resource
  // 实际填入输入框的提示词文本
  body: Resource
  // 分类(用于排序/未来分组,目前不展示)
  category: PresetPromptCategory
  // SymbolGlyph 资源(走 $r 编译时绑定,避免动态字符串)
  symbol: Resource
}

export enum PresetPromptCategory {
  WRITING = 'writing',
  TRANSLATE = 'translate',
  CODING = 'coding',
  LEARNING = 'learning',
  CREATIVE = 'creative'
}

// 推荐提示词列表
// 顺序即展示顺序;前 4 条用于 Onboarding Step3,全部 6 条用于主页/平板空状态。
const PRESET_PROMPTS: PresetPrompt[] = [
  {
    id: 'writing.polish',
    title: $r('app.string.preset_prompt_writing_polish_title'),
    body: $r('app.string.preset_prompt_writing_polish_body'),
    category: PresetPromptCategory.WRITING,
    symbol: $r('sys.symbol.text_alignleft')
  },
  {
    id: 'translate.zh_en',
    title: $r('app.string.preset_prompt_translate_zh_en_title'),
    body: $r('app.string.preset_prompt_translate_zh_en_body'),
    category: PresetPromptCategory.TRANSLATE,
    symbol: $r('sys.symbol.character_textbox')
  },
  {
    id: 'code.explain',
    title: $r('app.string.preset_prompt_code_explain_title'),
    body: $r('app.string.preset_prompt_code_explain_body'),
    category: PresetPromptCategory.CODING,
    symbol: $r('sys.symbol.wrench_and_screwdriver')
  },
  {
    id: 'learn.explain5',
    title: $r('app.string.preset_prompt_learn_explain5_title'),
    body: $r('app.string.preset_prompt_learn_explain5_body'),
    category: PresetPromptCategory.LEARNING,
    symbol: $r('sys.symbol.lightbulb')
  },
  {
    id: 'creative.brainstorm',
    title: $r('app.string.preset_prompt_creative_brainstorm_title'),
    body: $r('app.string.preset_prompt_creative_brainstorm_body'),
    category: PresetPromptCategory.CREATIVE,
    symbol: $r('sys.symbol.wand_and_stars')
  },
  {
    id: 'summary.long',
    title: $r('app.string.preset_prompt_summary_long_title'),
    body: $r('app.string.preset_prompt_summary_long_body'),
    category: PresetPromptCategory.WRITING,
    symbol: $r('sys.symbol.list_bullet')
  }
]

export function getPresetPrompts(): PresetPrompt[] {
  return PRESET_PROMPTS.slice()
}

// Onboarding Step3 展示的子集(前 4 条,减少认知负担)
export function getOnboardingPresetPrompts(): PresetPrompt[] {
  return PRESET_PROMPTS.slice(0, 4)
}

/**
 * 把 prompt 的正文 Resource 转成当前 locale 的实际字符串。
 * 内部用 resourceManager.getStringSync,失败时返回空串。
 */
export function resolvePromptBody(prompt: PresetPrompt, context: common.Context): string {
  try {
    return context.resourceManager.getStringSync(prompt.body)
  } catch (err) {
    console.error('PresetPrompts', `Failed to resolve prompt body: ${JSON.stringify(err)}`)
    return ''
  }
}

/**
 * 构造 OPEN_NEW_CHAT_WITH_PROMPT 的 AppStorage payload(JSON 字符串)。
 * 携带 timestamp 触发变化检测、text 是 prefill 文本。
 */
export function buildOpenNewChatWithPromptPayload(text: string): string {
  const payload: OpenNewChatWithPromptPayload = { ts: Date.now(), text: text }
  return JSON.stringify(payload)
}

export interface OpenNewChatWithPromptPayload {
  ts: number
  text: string
}

/**
 * 解析 OPEN_NEW_CHAT_WITH_PROMPT payload。无效 JSON 返回 null。
 */
export function parseOpenNewChatWithPromptPayload(raw: string): OpenNewChatWithPromptPayload | null {
  if (raw === '') {
    return null
  }
  try {
    const obj = JSON.parse(raw) as OpenNewChatWithPromptPayload
    if (typeof obj.ts !== 'number' || typeof obj.text !== 'string') {
      return null
    }
    return obj
  } catch (err) {
    console.error('PresetPrompts', `Failed to parse prompt payload: ${JSON.stringify(err)}`)
    return null
  }
}
