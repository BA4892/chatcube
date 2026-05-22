import { ImagePromptTemplate } from '../models/ImagePromptTemplateModels'
import { ImageGenerationViewModel } from '../viewmodels/ImageGenerationViewModel'
import { getAppUiState } from '../state/AppUiState'
import { showToast } from '../utils/ToastUtil'

let imagePromptTemplateManagerPathStack: NavPathStack | null = null

@Entry
@ComponentV2
struct ImagePromptTemplateManagerPage {
  @Local viewModel: ImageGenerationViewModel = ImageGenerationViewModel.getInstance()
  @Local searchText: string = ''
  @Local editingId: string = ''
  @Local editingTitle: string = ''
  @Local editingPrompt: string = ''
  @Local creatingTemplate: boolean = false
  @Local syncingRemote: boolean = false

  private get themePrimary(): string {
    return getAppUiState().themePrimary
  }

  private get themeSurface(): string {
    return getAppUiState().themeSurface
  }

  private get themeBackground(): string {
    return getAppUiState().themeBackground
  }

  aboutToAppear(): void {
    this.viewModel.refreshPromptTemplates().catch((error: Object): void => {
      console.error('ImagePromptTemplateManagerPage', `Load prompt templates failed: ${JSON.stringify(error)}`)
    })
  }

  private px2vp(px: number): number {
    return px / (this.getUIContext().getHostContext()?.resourceManager.getDeviceCapabilitySync().screenDensity ?? 3) * 160
  }

  private getTopPadding(): number {
    return this.px2vp(getAppUiState().topAvoidHeight)
  }

  private getBottomPadding(): number {
    return Math.max(this.px2vp(getAppUiState().bottomAvoidHeight), 16)
  }

  private handleBack(): void {
    if (imagePromptTemplateManagerPathStack !== null && imagePromptTemplateManagerPathStack.size() > 0) {
      imagePromptTemplateManagerPathStack.pop()
    }
  }

  private isEditing(): boolean {
    return this.creatingTemplate || this.editingId !== '' || this.editingTitle !== '' || this.editingPrompt !== ''
  }

  private canSave(): boolean {
    return this.editingTitle.trim() !== '' && this.editingPrompt.trim() !== ''
  }

  private startCreate(): void {
    this.creatingTemplate = true
    this.editingId = ''
    this.editingTitle = ''
    this.editingPrompt = ''
  }

  private startEdit(template: ImagePromptTemplate): void {
    this.creatingTemplate = false
    this.editingId = template.id
    this.editingTitle = template.title
    this.editingPrompt = template.prompt
  }

  private cancelEdit(): void {
    this.creatingTemplate = false
    this.editingId = ''
    this.editingTitle = ''
    this.editingPrompt = ''
  }

  private saveEditing(): void {
    if (!this.canSave()) {
      return
    }
    const previous = this.findTemplate(this.editingId)
    const template = new ImagePromptTemplate()
    template.id = this.editingId
    template.title = this.editingTitle.trim()
    template.prompt = this.editingPrompt.trim()
    template.enabled = previous !== null ? previous.enabled : true
    template.builtin = previous !== null ? previous.builtin : false
    template.order = previous !== null ? previous.order : 0
    template.createdAt = previous !== null ? previous.createdAt : 0
    template.updatedAt = Date.now()
    this.viewModel.savePromptTemplate(template).then((): void => {
      this.cancelEdit()
      showToast(this.getUIContext(), $r('app.string.image_prompt_template_saved'))
    }).catch((error: Object): void => {
      console.error('ImagePromptTemplateManagerPage', `Save prompt template failed: ${JSON.stringify(error)}`)
      showToast(this.getUIContext(), $r('app.string.image_prompt_template_save_failed'))
    })
  }

  private findTemplate(id: string): ImagePromptTemplate | null {
    if (id === '') {
      return null
    }
    for (let i = 0; i < this.viewModel.promptTemplates.length; i++) {
      if (this.viewModel.promptTemplates[i].id === id) {
        return this.viewModel.promptTemplates[i]
      }
    }
    return null
  }

  private matchesSearch(template: ImagePromptTemplate): boolean {
    const keyword = this.searchText.trim().toLowerCase()
    if (keyword === '') {
      return true
    }
    return template.title.toLowerCase().includes(keyword) || template.prompt.toLowerCase().includes(keyword)
  }

  private getFilteredTemplates(): ImagePromptTemplate[] {
    const result: ImagePromptTemplate[] = []
    for (let i = 0; i < this.viewModel.promptTemplates.length; i++) {
      if (this.matchesSearch(this.viewModel.promptTemplates[i])) {
        result.push(this.viewModel.promptTemplates[i])
      }
    }
    return result
  }

  private syncRemoteBuiltins(): void {
    if (this.syncingRemote) {
      return
    }
    this.syncingRemote = true
    this.viewModel.syncRemotePromptTemplates().then((): void => {
      showToast(this.getUIContext(), $r('app.string.image_prompt_template_sync_success'))
    }).catch((error: Object): void => {
      console.error('ImagePromptTemplateManagerPage', `Sync remote prompt templates failed: ${JSON.stringify(error)}`)
      showToast(this.getUIContext(), $r('app.string.image_prompt_template_sync_failed'))
    }).finally((): void => {
      this.syncingRemote = false
      this.cancelEdit()
    })
  }

  private resetBuiltins(): void {
    this.viewModel.resetBuiltinPromptTemplates().then((): void => {
      this.cancelEdit()
      showToast(this.getUIContext(), $r('app.string.image_prompt_template_reset_success'))
    }).catch((error: Object): void => {
      console.error('ImagePromptTemplateManagerPage', `Reset prompt templates failed: ${JSON.stringify(error)}`)
      showToast(this.getUIContext(), $r('app.string.image_prompt_template_reset_failed'))
    })
  }

  build() {
    Column() {
      this.Header()
      this.Content()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeBackground)
  }

  @Builder
  private Header() {
    Row() {
      Button() {
        SymbolGlyph($r('sys.symbol.chevron_left'))
          .fontSize(22)
          .fontColor([$r('app.color.text_primary')])
      }
      .type(ButtonType.Circle)
      .width(40)
      .height(40)
      .backgroundColor(Color.Transparent)
      .onClick(() => {
        this.handleBack()
      })

      Text($r('app.string.image_prompt_template_manage'))
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
        .textAlign(TextAlign.Center)

      Blank()
        .width(40)
        .height(40)
    }
    .width('100%')
    .height(56 + this.getTopPadding())
    .padding({ left: 12, right: 12, top: this.getTopPadding() })
    .backgroundColor(this.themeBackground)
  }

  @Builder
  private Content() {
    Column({ space: 12 }) {
      Search({ value: this.searchText, placeholder: $r('app.string.image_prompt_template_search_placeholder') })
        .height(42)
        .backgroundColor(this.themeSurface)
        .onChange((value: string): void => {
          this.searchText = value
        })

      Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap }) {
        this.ActionButton($r('sys.symbol.arrow_clockwise'), $r('app.string.image_prompt_template_sync_remote'), true, (): void => {
          this.syncRemoteBuiltins()
        }, !this.syncingRemote)
        this.ActionButton($r('sys.symbol.arrow_counterclockwise'), $r('app.string.image_prompt_template_reset_builtins'), false, (): void => {
          this.resetBuiltins()
        }, !this.syncingRemote)
        this.ActionButton($r('sys.symbol.plus'), $r('app.string.image_prompt_template_add'), false, (): void => {
          this.startCreate()
        }, !this.syncingRemote)
      }
      .width('100%')

      if (this.isEditing()) {
        this.Editor()
      }

      this.TemplateList()
    }
    .width('100%')
    .layoutWeight(1)
    .padding({ left: 16, right: 16, bottom: this.getBottomPadding() })
  }

  @Builder
  private ActionButton(icon: Resource, label: Resource, showsSyncProgress: boolean, action: () => void, enabled: boolean) {
    Button({ type: ButtonType.Capsule, stateEffect: false }) {
      Row({ space: 6 }) {
        if (this.syncingRemote && showsSyncProgress) {
          LoadingProgress()
            .width(15)
            .height(15)
            .color(this.themePrimary)
        } else {
          SymbolGlyph(icon)
            .fontSize(15)
            .fontColor([enabled ? this.themePrimary : $r('app.color.text_tertiary')])
        }
        Text(label)
          .fontSize(13)
          .fontColor(enabled ? $r('app.color.text_primary') : $r('app.color.text_tertiary'))
      }
      .padding({ left: 12, right: 12 })
    }
    .height(34)
    .margin({ right: 8, bottom: 8 })
    .backgroundColor(this.themeSurface)
    .enabled(enabled)
    .onClick(() => {
      action()
    })
  }

  @Builder
  private Editor() {
    Column({ space: 10 }) {
      TextInput({ text: this.editingTitle, placeholder: $r('app.string.image_prompt_template_title_placeholder') })
        .height(42)
        .fontSize(14)
        .fontColor($r('app.color.text_primary'))
        .backgroundColor(this.themeSurface)
        .borderRadius(10)
        .onChange((value: string): void => {
          this.editingTitle = value
        })

      TextArea({ text: this.editingPrompt, placeholder: $r('app.string.image_prompt_template_prompt_placeholder') })
        .fontSize(14)
        .fontColor($r('app.color.text_primary'))
        .backgroundColor(this.themeSurface)
        .borderRadius(10)
        .constraintSize({ minHeight: 92, maxHeight: 150 })
        .onChange((value: string): void => {
          this.editingPrompt = value
        })

      Row({ space: 8 }) {
        Button($r('app.string.cancel'))
          .height(38)
          .layoutWeight(1)
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .backgroundColor(this.themeSurface)
          .onClick(() => {
            this.cancelEdit()
          })
        Button($r('app.string.save'))
          .height(38)
          .layoutWeight(1)
          .fontSize(14)
          .fontColor(Color.White)
          .backgroundColor(this.canSave() ? this.themePrimary : $r('app.color.text_tertiary'))
          .enabled(this.canSave())
          .onClick(() => {
            this.saveEditing()
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding(12)
    .backgroundColor($r('app.color.code_background'))
    .borderRadius(12)
  }

  @Builder
  private TemplateList() {
    if (this.getFilteredTemplates().length === 0) {
      Column({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.magnifyingglass'))
          .fontSize(32)
          .fontColor([$r('app.color.text_tertiary')])
        Text($r('app.string.image_prompt_template_no_results'))
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    } else {
      List({ space: 10 }) {
        ForEach(this.getFilteredTemplates(), (template: ImagePromptTemplate): void => {
          ListItem() {
            this.TemplateRow(template)
          }
        }, (template: ImagePromptTemplate): string => template.id)
      }
      .width('100%')
      .layoutWeight(1)
      .height('100%')
      .scrollBar(BarState.Off)
    }
  }

  @Builder
  private TemplateRow(template: ImagePromptTemplate) {
    Column({ space: 8 }) {
      Row() {
        Row({ space: 6 }) {
          Text(template.title)
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          if (template.builtin) {
            Text($r('app.string.image_prompt_template_builtin'))
              .fontSize(10)
              .fontColor(this.themePrimary)
              .padding({ left: 6, right: 6, top: 2, bottom: 2 })
              .backgroundColor(getAppUiState().themePrimaryLight)
              .borderRadius(7)
          }
        }
        .layoutWeight(1)

        Toggle({ type: ToggleType.Switch, isOn: template.enabled })
          .selectedColor(this.themePrimary)
          .onChange((isOn: boolean): void => {
            this.viewModel.setPromptTemplateEnabled(template.id, isOn).catch((error: Object): void => {
              console.error('ImagePromptTemplateManagerPage', `Toggle prompt template failed: ${JSON.stringify(error)}`)
            })
          })
      }
      .width('100%')

      Text(template.prompt)
        .fontSize(12)
        .fontColor($r('app.color.text_secondary'))
        .maxLines(3)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')

      Row({ space: 8 }) {
        Button($r('app.string.image_prompt_template_edit'))
          .height(30)
          .padding({ left: 12, right: 12 })
          .fontSize(12)
          .fontColor(this.themePrimary)
          .backgroundColor(getAppUiState().themePrimaryLight)
          .onClick(() => {
            this.startEdit(template)
          })
        if (!template.builtin) {
          Button($r('app.string.delete'))
            .height(30)
            .padding({ left: 12, right: 12 })
            .fontSize(12)
            .fontColor($r('app.color.status_error'))
            .backgroundColor($r('app.color.code_background'))
            .onClick(() => {
              this.viewModel.deletePromptTemplate(template.id).catch((error: Object): void => {
                console.error('ImagePromptTemplateManagerPage', `Delete prompt template failed: ${JSON.stringify(error)}`)
              })
              if (this.editingId === template.id) {
                this.cancelEdit()
              }
            })
        }
      }
      .width('100%')
      .justifyContent(FlexAlign.End)
    }
    .width('100%')
    .padding(12)
    .backgroundColor(this.themeSurface)
    .borderRadius(12)
  }
}

@Builder
export function ImagePromptTemplateManagerPageBuilder(_name: string, _param: Object) {
  NavDestination() {
    ImagePromptTemplateManagerPage()
  }
  .hideTitleBar(true)
  .hideBackButton(true)
  .onReady((context: NavDestinationContext) => {
    imagePromptTemplateManagerPathStack = context.pathStack
  })
  .onBackPressed((): boolean => {
    if (imagePromptTemplateManagerPathStack !== null && imagePromptTemplateManagerPathStack.size() > 0) {
      imagePromptTemplateManagerPathStack.pop()
    }
    return true
  })
}
