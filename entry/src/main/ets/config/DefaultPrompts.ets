// 默认 Prompt 模板

export class DefaultPrompts {
  // 标题生成 Prompt（参考 RikkaHub 的标题摘要提示词）
  static readonly TITLE_PROMPT: string = `I will give you some dialogue content in the \`<content>\` block.
You need to summarize the conversation between user and assistant into a short title.
1. The title language should be consistent with the user's primary language
2. Do not use punctuation or other special symbols
3. Reply directly with the title
4. Summarize using {locale} language
5. The title should not exceed 10 characters

<content>
{content}
</content>`

  // 翻译 Prompt
  static readonly TRANSLATE_PROMPT: string = `You are a translation expert, skilled in translating various languages, and maintaining accuracy, faithfulness, and elegance in translation.
Next, I will send you text. Please translate it into {target_lang}, and return the translation result directly, without adding any explanations or other content.

Please translate the <source_text> section:
<source_text>
{source_text}
</source_text>`

  // 推荐候选词 Prompt（参考 RikkaHub 的用户视角续聊建议）
  static readonly SUGGESTION_PROMPT: string = `I will provide you with some chat content in the \`<content>\` block, including conversations between the User and the AI assistant.
You need to act as the **User** to reply to the assistant, generating 3~5 appropriate and contextually relevant responses to the assistant.

Rules:
1. Reply directly with suggestions, do not add any formatting, and separate suggestions with newlines, no need to add markdown list formats.
2. Use {locale} language.
3. Ensure each suggestion is valid.
4. Each suggestion should not exceed 10 characters.
5. Imitate the user's previous conversational style.
6. Act as a User, not an Assistant!

<content>
{content}
</content>`

  // 默认翻译目标语言
  static readonly DEFAULT_TARGET_LANGUAGE: string = 'Chinese'

  // 硅基流动默认配置（免费模型）
  static readonly SILICONFLOW_PROVIDER_ID: string = 'siliconflow'
  static readonly SILICONFLOW_TRANSLATE_MODEL: string = 'THUDM/GLM-4-9B-0414'
}
