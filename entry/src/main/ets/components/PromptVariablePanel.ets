import { getAppUiState } from '../state/AppUiState'

export class PromptVariableItem {
  token: string
  description: ResourceStr

  constructor(token: string, description: ResourceStr) {
    this.token = token
    this.description = description
  }
}

export function appendPromptVariableText(text: string, token: string): string {
  if (text.length === 0) {
    return token
  }
  return text.endsWith('\n') ? `${text}${token}` : `${text}\n${token}`
}

@ComponentV2
export struct PromptVariablePanel {
  @Param title: ResourceStr = $r('app.string.prompt_template_available_variables')
  @Param variables: PromptVariableItem[] = []
  @Param variableEnabled: boolean = true
  @Event onVariableClick: (token: string) => void = (_token: string): void => {}

  private get themePrimary(): string {
    return getAppUiState().themePrimary
  }

  private get themePrimaryLight(): string {
    return getAppUiState().themePrimaryLight
  }

  build() {
    Column({ space: 10 }) {
      Text(this.title)
        .fontSize(13)
        .fontColor($r('app.color.text_secondary'))
        .width('100%')

      Column({ space: 8 }) {
        ForEach(this.variables, (item: PromptVariableItem) => {
          this.VariableRow(item)
        }, (item: PromptVariableItem) => item.token)
      }
      .width('100%')
    }
    .width('100%')
    .padding(16)
    .backgroundColor(getAppUiState().themeSurface)
    .borderRadius(12)
    .opacity(this.variableEnabled ? 1 : 0.5)
  }

  @Builder
  private VariableRow(item: PromptVariableItem) {
    Row({ space: 8 }) {
      Row() {
        Text(item.token)
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.themePrimary)
      }
      .height(28)
      .padding({ left: 10, right: 10 })
      .backgroundColor(this.themePrimaryLight)
      .borderRadius(14)
      .border({ width: 1, color: this.themePrimary })
      .onClick(() => {
        if (this.variableEnabled) {
          this.onVariableClick(item.token)
        }
      })

      Text(item.description)
        .fontSize(12)
        .fontColor($r('app.color.text_tertiary'))
        .layoutWeight(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }
}
