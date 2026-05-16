import { PresetPrompt } from '../../config/PresetPrompts'
import { getAppUiState } from '../../state/AppUiState'
import { withColorAlpha } from '../../utils/ColorAlphaUtils'

/**
 * 推荐提示词卡片(2 列 Grid)。
 * 用于主页会话列表空状态、平板分栏右侧空状态、首启 Onboarding 第 3 步。
 */
@ComponentV2
export struct IndexRecommendedPromptsCard {
  @Param prompts: PresetPrompt[] = []
  @Event onPromptClick: (prompt: PresetPrompt) => void = () => {}

  private get themePrimary(): string {
    return getAppUiState().themePrimary
  }

  private get themeSurface(): string {
    return getAppUiState().themeSurface
  }

  build() {
    Grid() {
      ForEach(this.prompts, (prompt: PresetPrompt) => {
        GridItem() {
          this.PromptCard(prompt)
        }
      }, (prompt: PresetPrompt) => prompt.id)
    }
    .columnsTemplate('1fr 1fr')
    .columnsGap(12)
    .rowsGap(12)
    .padding({ left: 16, right: 16 })
    .width('100%')
  }

  @Builder
  private PromptCard(prompt: PresetPrompt) {
    Column() {
      Row() {
        SymbolGlyph(prompt.symbol)
          .fontSize(20)
          .fontColor([this.themePrimary])
      }
      .width(36)
      .height(36)
      .borderRadius(10)
      .backgroundColor(withColorAlpha(this.themePrimary, '1A'))
      .justifyContent(FlexAlign.Center)

      Text(prompt.title)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .margin({ top: 12 })
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .alignItems(HorizontalAlign.Start)
    .padding(14)
    .width('100%')
    .borderRadius(14)
    .backgroundColor(this.themeSurface)
    .border({ width: 1, color: $r('app.color.divider') })
    .onClick(() => {
      this.onPromptClick(prompt)
    })
  }
}
