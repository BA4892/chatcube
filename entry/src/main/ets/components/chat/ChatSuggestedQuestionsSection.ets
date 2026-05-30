import { buildDualEdgeFlowLightBorderEffect } from '../../utils/HdsVisualEffectUtil'

@ComponentV2
export struct ChatSuggestedQuestionsSection {
  @Param questions: string[] = []
  @Param selectedQuestion: string = ''
  @Param contentMaxWidth: number = 99999
  @Event onQuestionClick: (question: string) => void = (_question: string): void => {}

  private getEffectiveContentMaxWidth(): number {
    return this.contentMaxWidth > 0 ? this.contentMaxWidth : 99999
  }

  private getChipMaxWidth(): number {
    return Math.max(120, Math.min(this.getEffectiveContentMaxWidth() - 28, 520))
  }

  private isSelectedQuestion(question: string): boolean {
    return this.selectedQuestion.trim() === question.trim()
  }

  @Builder
  private GeneratedDivider() {
    Row({ space: 8 }) {
      SymbolGlyph($r('sys.symbol.wand_and_stars'))
        .fontSize(14)
        .fontColor([$r('app.color.markdown_text')])

      Divider()
        .color($r('app.color.divider'))
        .layoutWeight(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .margin({ bottom: 12 })
  }

  @Builder
  private QuestionChipText(question: string) {
    Text(question)
      .fontSize(14)
      .lineHeight(19)
      .fontColor($r('app.color.markdown_text'))
      .maxLines(2)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
  }

  @Builder
  private QuestionChip(question: string) {
    if (this.isSelectedQuestion(question)) {
      Row() {
        this.QuestionChipText(question)
      }
      .constraintSize({ maxWidth: this.getChipMaxWidth(), minHeight: 38 })
      .padding({ left: 14, right: 14, top: 8, bottom: 8 })
      .backgroundColor(Color.Transparent)
      .border({ width: 1, color: $r('app.color.divider') })
      .borderRadius(19)
      .clip(true)
      .visualEffect(buildDualEdgeFlowLightBorderEffect())
      .alignItems(VerticalAlign.Center)
      .onClick(() => {
        this.onQuestionClick(question)
      })
    } else {
      Row() {
        this.QuestionChipText(question)
      }
      .constraintSize({ maxWidth: this.getChipMaxWidth(), minHeight: 38 })
      .padding({ left: 14, right: 14, top: 8, bottom: 8 })
      .backgroundColor(Color.Transparent)
      .border({ width: 1, color: $r('app.color.divider') })
      .borderRadius(19)
      .clip(true)
      .alignItems(VerticalAlign.Center)
      .onClick(() => {
        this.onQuestionClick(question)
      })
    }
  }

  build() {
    Row() {
      Column() {
        this.GeneratedDivider()

        Scroll() {
          Row({ space: 8 }) {
            ForEach(this.questions, (question: string) => {
              this.QuestionChip(question)
            }, (question: string, index: number): string => `${index}_${question}`)
          }
          .justifyContent(FlexAlign.Start)
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        .width('100%')
        .align(Alignment.Start)
      }
      .width('100%')
      .constraintSize({ maxWidth: this.getEffectiveContentMaxWidth() })
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .padding({ left: 14, right: 14, top: 6, bottom: 8 })
    .backgroundColor(Color.Transparent)
  }
}
