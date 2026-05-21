import { ModelProvider, OutputMode } from '../../models/ChatModels'
import { ModelSelectorContent } from '../ModelSelector'
import { CubeSpinnerLight } from '../loading/CubeSpinner'

@ComponentV2
export struct ImageGenerationModelSheet {
  @Param providers: ModelProvider[] = []
  @Param isProvidersLoaded: boolean = false
  @Param currentModelId: string = ''
  @Param currentProviderId: string = ''
  @Event onSelectModel: (providerId: string, modelId: string, modelName: string) => void =
    (_providerId: string, _modelId: string, _modelName: string): void => {}

  build() {
    Column() {
      if (!this.isProvidersLoaded) {
        Column() {
          CubeSpinnerLight({ sizeVp: 32 })
          Text($r('app.string.loading'))
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
            .margin({ top: 14 })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        ModelSelectorContent({
          providers: this.providers,
          currentModelId: this.currentModelId,
          currentProviderId: this.currentProviderId,
          showEditEntry: false,
          showFavoriteActions: true,
          showFavoriteFilter: true,
          includeModelIdInSearch: true,
          emptyStateMode: 'default',
          hasOutputModeFilter: true,
          outputModeFilter: OutputMode.IMAGE,
          emptyTitle: $r('app.string.image_generation_no_available_model'),
          emptyDescription: $r('app.string.image_generation_no_available_model_hint'),
          onSelectModel: (providerId: string, modelId: string, modelName: string): void => {
            this.onSelectModel(providerId, modelId, modelName)
          }
        })
      }
    }
    .width('100%')
    .height('100%')
  }
}
