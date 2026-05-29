import { LengthMetrics } from '@kit.ArkUI'
import { getAppUiState } from '../../state/AppUiState'

@ComponentV2
export struct ChatSuggestedQuestionsSection {
  @Param questions: string[] = []
  @Param contentMaxWidth: number = 99999
  @Event onQuestionClick: (question: string) => void = (_question: string): void => {}

  private get themePrimary(): string {
    return getAppUiState().themePrimary
  }

  private get themePrimaryLight(): string {
    return getAppUiState().themePrimaryLight
  }

  private get themeSurface(): string {
    return getAppUiState().themeSurface
  }

  private getEffectiveContentMaxWidth(): number {
    return this.contentMaxWidth > 0 ? this.contentMaxWidth : 99999
  }

  private getChipMaxWidth(): number {
    return Math.max(180, Math.min(this.getEffectiveContentMaxWidth() - 28, 520))
  }

  @Builder
  private QuestionChip(question: string) {
    Row() {
      Text(question)
        .fontSize(14)
        .lineHeight(19)
        .fontColor(this.themePrimary)
        .layoutWeight(1)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .height(38)
    .padding({ left: 14, right: 14 })
    .constraintSize({ maxWidth: this.getChipMaxWidth() })
    .backgroundColor(this.themePrimaryLight)
    .border({ width: 1, color: this.themePrimary })
    .borderRadius(19)
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      this.onQuestionClick(question)
    })
  }

  build() {
    Row() {
      Column() {
        Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(8), cross: LengthMetrics.vp(8) } }) {
          ForEach(this.questions, (question: string) => {
            this.QuestionChip(question)
          }, (question: string, index: number): string => `${index}_${question}`)
        }
        .width('100%')
      }
      .width('100%')
      .constraintSize({ maxWidth: this.getEffectiveContentMaxWidth() })
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .padding({ left: 14, right: 14, top: 5, bottom: 8 })
    .backgroundColor(this.themeSurface)
  }
}
