/**
 * AskUserCard - ask_user 工具专属 UI
 *
 * 解析 toolCall.arguments 里的 questions, 按 selection_type 渲染:
 *  - 'single': FilterChip 单选 + 可选自定义答案
 *  - 'multi':  多个 chip 可多选
 *  - 'text' / 其他: 选项 chip(可选) + 自由文本输入
 * 用户可以只回答一部分, 未回答问题会作为 skipped_ids 回传; 也可以整轮跳过。
 */

import { ToolCall } from '../models/ChatModels'
import { getAppUiState } from '../state/AppUiState'
import { withColorAlpha } from '../utils/ColorAlphaUtils'

interface AskUserQuestion {
  id: string
  question: string
  options: string[]
  selectionType: string
}

interface AskUserArgs {
  questions?: Object[]
}

interface AskUserAnswerItem {
  question: string
  selection_type: string
  selected_options: string[]
  custom_answer: string
  answer: string
  skipped: boolean
}

interface AskUserAnswerPayload {
  answers: Record<string, AskUserAnswerItem>
  answered_ids: string[]
  skipped_ids: string[]
  summary: string
}

@ComponentV2
export struct AskUserCard {
  @Param toolCall: ToolCall = new ToolCall()
  @Param isAnswered: boolean = false
  @Param answeredPayload: string = ''
  // 提交回调, ChatPage 里转发到 ToolExecutionService 的 approval/answer 流程
  @Event onAnswer: (toolCallId: string, answerJson: string) => void = () => {}

  // key: question id -> 已选/已输入答案; single/text 用 textAnswers, multi 用 multiAnswers
  @Local textAnswers: Map<string, string> = new Map()
  @Local multiAnswers: Map<string, Set<string>> = new Map()
  @Local customAnswers: Map<string, string> = new Map()

  private get themePrimary(): string {
    return getAppUiState().themePrimary
  }

  private get themeAiBubble(): string {
    return getAppUiState().themeAiBubble
  }

  private get isDarkMode(): boolean {
    return getAppUiState().isDarkMode
  }

  private parseQuestions(): AskUserQuestion[] {
    const out: AskUserQuestion[] = []
    try {
      const parsed = JSON.parse(this.toolCall.arguments) as AskUserArgs
      const rawQs = parsed.questions
      if (!Array.isArray(rawQs)) {
        return out
      }
      const list = rawQs as Object[]
      for (let i = 0; i < list.length; i++) {
        const obj = list[i] as Record<string, Object>
        if (obj === null || obj === undefined) {
          continue
        }
        const id = (obj['id'] as string | undefined) ?? `q_${i}`
        const question = (obj['question'] as string | undefined) ?? ''
        const selectionType = (obj['selection_type'] as string | undefined) ?? 'text'
        const options: string[] = []
        const rawOpts = obj['options'] as Object
        if (Array.isArray(rawOpts)) {
          const arr = rawOpts as string[]
          for (let j = 0; j < arr.length; j++) {
            const v = arr[j]
            if (typeof v === 'string' && v !== '') {
              options.push(v)
            }
          }
        }
        out.push({ id: id, question: question, options: options, selectionType: selectionType })
      }
    } catch (_e) {}
    return out
  }

  private toggleMulti(qid: string, option: string): void {
    const current = this.multiAnswers.get(qid)
    const nextSet = new Set<string>()
    if (current !== undefined) {
      current.forEach((value: string) => {
        nextSet.add(value)
      })
    }
    if (nextSet.has(option)) {
      nextSet.delete(option)
    } else {
      nextSet.add(option)
    }
    const nextMap = new Map<string, Set<string>>()
    this.multiAnswers.forEach((value: Set<string>, key: string) => {
      nextMap.set(key, value)
    })
    nextMap.set(qid, nextSet)
    this.multiAnswers = nextMap
  }

  private buildSelectedOptions(q: AskUserQuestion): string[] {
    if (q.selectionType === 'multi') {
      return Array.from(this.multiAnswers.get(q.id) ?? new Set<string>())
    }
    if (q.selectionType === 'single') {
      const selected = this.textAnswers.get(q.id) ?? ''
      return selected.trim() !== '' ? [selected.trim()] : []
    }
    return []
  }

  private buildQuestionAnswer(q: AskUserQuestion, selectedOptions: string[], customAnswer: string): string {
    if (q.selectionType === 'text') {
      return customAnswer
    }
    if (selectedOptions.length > 0 && customAnswer !== '') {
      return `${selectedOptions.join(', ')}；${customAnswer}`
    }
    if (selectedOptions.length > 0) {
      return selectedOptions.join(', ')
    }
    return customAnswer
  }

  private buildPayload(questions: AskUserQuestion[], skipAll: boolean = false): string {
    const answers: Record<string, AskUserAnswerItem> = {}
    const answeredIds: string[] = []
    const skippedIds: string[] = []
    for (let i = 0; i < questions.length; i++) {
      const q = questions[i]
      const selectedOptions = skipAll ? [] : this.buildSelectedOptions(q)
      const customAnswer = skipAll ? '' : ((q.selectionType === 'text'
        ? (this.textAnswers.get(q.id) ?? '')
        : (this.customAnswers.get(q.id) ?? '')).trim())
      const answer = this.buildQuestionAnswer(q, selectedOptions, customAnswer).trim()
      const skipped = answer === ''
      if (skipped) {
        skippedIds.push(q.id)
      } else {
        answeredIds.push(q.id)
      }
      answers[q.id] = {
        question: q.question,
        selection_type: q.selectionType,
        selected_options: selectedOptions,
        custom_answer: customAnswer,
        answer: answer,
        skipped: skipped
      }
    }
    const payload: AskUserAnswerPayload = {
      answers: answers,
      answered_ids: answeredIds,
      skipped_ids: skippedIds,
      summary: answeredIds.length > 0
        ? `用户回答了 ${answeredIds.length} 个问题，跳过 ${skippedIds.length} 个问题`
        : '用户跳过了本次询问'
    }
    return JSON.stringify(payload)
  }

  private handleSubmit(questions: AskUserQuestion[]): void {
    const payload = this.buildPayload(questions)
    this.onAnswer(this.toolCall.id, payload)
  }

  private handleSkipAll(questions: AskUserQuestion[]): void {
    const payload = this.buildPayload(questions, true)
    this.onAnswer(this.toolCall.id, payload)
  }

  private hasAnyAnswer(questions: AskUserQuestion[]): boolean {
    for (let i = 0; i < questions.length; i++) {
      const q = questions[i]
      if (this.buildSelectedOptions(q).length > 0) {
        return true
      }
      const textAnswer = this.textAnswers.get(q.id) ?? ''
      const customAnswer = this.customAnswers.get(q.id) ?? ''
      if (textAnswer.trim() !== '' || customAnswer.trim() !== '') {
        return true
      }
    }
    return false
  }

  private getQuestionBackgroundColor(): string {
    return this.isDarkMode ? withColorAlpha(this.themePrimary, '18') : withColorAlpha(this.themePrimary, '12')
  }

  private getChipBackgroundColor(selected: boolean): ResourceColor {
    return selected ? this.themePrimary : $r('app.color.surface')
  }

  build() {
    Column({ space: 10 }) {
      Row() {
        SymbolGlyph($r('sys.symbol.message'))
          .fontSize(14)
          .fontColor([this.themePrimary])
        Text(this.parseQuestions().length > 1 ? '我有几个问题想确认一下' : '我有个问题想确认一下')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .margin({ left: 6 })
        Blank()
        if (this.isAnswered) {
          Text('已回答')
            .fontSize(10)
            .fontColor(Color.White)
            .backgroundColor($r('app.color.status_success'))
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .borderRadius(6)
        }
      }
      .width('100%')

      ForEach(this.parseQuestions(), (q: AskUserQuestion, index: number) => {
        Column({ space: 6 }) {
          Text(q.question !== '' ? q.question : `问题 ${index + 1}`)
            .fontSize(13)
            .fontColor($r('app.color.text_primary'))
            .width('100%')

          if (q.options.length > 0) {
            Flex({ wrap: FlexWrap.Wrap }) {
              ForEach(q.options, (opt: string) => {
                this.OptionChip(q, opt)
              }, (opt: string) => opt)
            }
          }

          if (q.selectionType === 'text') {
            TextInput({
              text: this.textAnswers.get(q.id) ?? '',
              placeholder: '输入你的回答'
            })
              .width('100%')
              .height(36)
              .fontSize(13)
              .backgroundColor($r('app.color.background'))
              .borderRadius(8)
              .enabled(!this.isAnswered)
              .onChange((value: string) => {
                this.textAnswers.set(q.id, value)
              })
          } else {
            TextInput({
              text: this.customAnswers.get(q.id) ?? '',
              placeholder: '自定义答案，可留空'
            })
              .width('100%')
              .height(34)
              .fontSize(12)
              .fontColor($r('app.color.text_primary'))
              .placeholderColor($r('app.color.text_tertiary'))
              .backgroundColor($r('app.color.surface'))
              .borderRadius(8)
              .enabled(!this.isAnswered)
              .onChange((value: string) => {
                this.customAnswers.set(q.id, value)
              })
          }
        }
        .width('100%')
        .padding(10)
        .backgroundColor(this.getQuestionBackgroundColor())
        .borderRadius(10)
      }, (q: AskUserQuestion) => q.id)

      if (!this.isAnswered) {
        Row({ space: 8 }) {
          Button('跳过')
            .height(32)
            .padding({ left: 14, right: 14 })
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
            .backgroundColor($r('app.color.surface'))
            .border({ width: 0.5, color: $r('app.color.divider') })
            .onClick(() => {
              this.handleSkipAll(this.parseQuestions())
            })

          Button('提交')
            .height(32)
            .padding({ left: 16, right: 16 })
            .fontSize(13)
            .fontColor(Color.White)
            .backgroundColor(this.themePrimary)
            .enabled(this.hasAnyAnswer(this.parseQuestions()))
            .onClick(() => {
              this.handleSubmit(this.parseQuestions())
            })
        }
        .width('100%')
        .justifyContent(FlexAlign.End)
      }
    }
    .width('100%')
    .padding(12)
    .backgroundColor(this.themeAiBubble)
    .borderRadius(12)
    .border({ width: 1, color: $r('app.color.divider') })
  }

  @Builder
  private OptionChip(q: AskUserQuestion, option: string) {
    Row() {
      Text(option)
        .fontSize(12)
        .fontColor(this.isOptionSelected(q, option) ? Color.White : $r('app.color.text_primary'))
    }
    .padding({ left: 10, right: 10, top: 6, bottom: 6 })
    .margin({ right: 6, bottom: 6 })
    .backgroundColor(this.getChipBackgroundColor(this.isOptionSelected(q, option)))
    .borderRadius(12)
    .border({ width: 0.5, color: $r('app.color.divider') })
    .onClick(() => {
      if (this.isAnswered) {
        return
      }
      if (q.selectionType === 'multi') {
        this.toggleMulti(q.id, option)
      } else {
        this.textAnswers.set(q.id, option)
      }
    })
  }

  private isOptionSelected(q: AskUserQuestion, option: string): boolean {
    if (q.selectionType === 'multi') {
      const set = this.multiAnswers.get(q.id)
      return set !== undefined && set.has(option)
    }
    return this.textAnswers.get(q.id) === option
  }
}
