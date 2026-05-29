import { ImagePromptTemplate } from '../models/ImagePromptTemplateModels'
import { ImageGenerationViewModel } from '../viewmodels/ImageGenerationViewModel'
import { getAppUiState } from '../state/AppUiState'
import { showToast } from '../utils/ToastUtil'
import {
  HdsNavigation,
  HdsNavDestination,
  HdsNavDestinationTitleMode,
  HdsNavigationTitleBarOptions,
  HdsNavigationTitleMode
} from '@kit.UIDesignKit'
import {
  buildHdsTopNavigationTitleBarOptionsForNativePage,
  getHdsTopNavigationContentTopPadding,
  getHdsStatusBarContentColor
} from '../utils/HdsVisualEffectUtil'

let imagePromptTemplateManagerPathStack: NavPathStack | null = null

enum ImagePromptTemplateFilterMode {
  ALL = 'all',
  MINE = 'mine',
  BUILTIN = 'builtin'
}

@Entry
@ComponentV2
struct ImagePromptTemplateManagerPage {
  @Param hostedInNavDestination: boolean = false
  @Local viewModel: ImageGenerationViewModel = ImageGenerationViewModel.getInstance()
  @Local searchText: string = ''
  @Local filterMode: ImagePromptTemplateFilterMode = ImagePromptTemplateFilterMode.ALL
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

  private get windowWidthVp(): number {
    return getAppUiState().windowWidthVp
  }

  private get windowHeightVp(): number {
    return getAppUiState().windowHeightVp
  }

  private get materialType(): number {
    return getAppUiState().materialType
  }

  private get materialLevel(): number {
    return getAppUiState().materialLevel
  }

  aboutToAppear(): void {
    this.viewModel.refreshPromptTemplates().catch((error: Object): void => {
      console.error('ImagePromptTemplateManagerPage', `Load prompt templates failed: ${JSON.stringify(error)}`)
    })
  }

  private px2vp(px: number): number {
    return px / (this.getUIContext().getHostContext()?.resourceManager.getDeviceCapabilitySync().screenDensity ?? 3) * 160
  }

  private getBottomPadding(): number {
    return Math.max(this.px2vp(getAppUiState().bottomAvoidHeight), 16)
  }

  private getCompactContentTopPadding(): number {
    return getHdsTopNavigationContentTopPadding(this.px2vp(getAppUiState().topAvoidHeight), this.windowWidthVp,
      this.windowHeightVp)
  }

  private getCompactTitleBarOptions(): HdsNavigationTitleBarOptions {
    return buildHdsTopNavigationTitleBarOptionsForNativePage(this.materialType, this.materialLevel, this.windowWidthVp,
      this.windowHeightVp, $r('app.string.image_prompt_template_manage'), (): void => {
        this.handleBack()
      })
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

  private matchesFilter(template: ImagePromptTemplate): boolean {
    if (this.filterMode === ImagePromptTemplateFilterMode.MINE) {
      return !template.builtin
    }
    if (this.filterMode === ImagePromptTemplateFilterMode.BUILTIN) {
      return template.builtin
    }
    return true
  }

  private getFilteredTemplates(): ImagePromptTemplate[] {
    const result: ImagePromptTemplate[] = []
    for (let i = 0; i < this.viewModel.promptTemplates.length; i++) {
      if (this.matchesFilter(this.viewModel.promptTemplates[i]) && this.matchesSearch(this.viewModel.promptTemplates[i])) {
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

  private useTemplate(template: ImagePromptTemplate): void {
    if (template.prompt.trim() === '') {
      return
    }
    this.viewModel.updatePrompt(template.prompt)
    showToast(this.getUIContext(), $r('app.string.image_prompt_template_applied'))
    this.handleBack()
  }

  build() {
    if (this.hostedInNavDestination) {
      this.NavDestinationRoot()
    } else {
      this.StandaloneRoot()
    }
  }

  @Builder
  private PageRootContent() {
    Column() {
      Blank()
        .width('100%')
        .height(this.getCompactContentTopPadding())

      this.Content()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeBackground)
  }

  @Builder
  private NavDestinationRoot() {
    HdsNavDestination() {
      this.PageRootContent()
    }
    .titleBar(this.getCompactTitleBarOptions())
    .titleMode(HdsNavDestinationTitleMode.MINI)
    .systemBarStyle(
      { statusBarContentColor: getHdsStatusBarContentColor() },
      { statusBarContentColor: getHdsStatusBarContentColor() }
    )
    .hideBackButton(false)
    .hideToolBar(true)
    .backgroundColor(this.themeBackground)
    .onReady((context: NavDestinationContext) => {
      imagePromptTemplateManagerPathStack = context.pathStack
    })
    .onBackPressed((): boolean => {
      this.handleBack()
      return true
    })
  }

  @Builder
  private StandaloneRoot() {
    HdsNavigation() {
      this.PageRootContent()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeBackground)
    .titleBar(this.getCompactTitleBarOptions())
    .titleMode(HdsNavigationTitleMode.MINI)
    .systemBarStyle(
      { statusBarContentColor: getHdsStatusBarContentColor() },
      { statusBarContentColor: getHdsStatusBarContentColor() }
    )
    .hideBackButton(false)
    .hideToolBar(true)
    .mode(NavigationMode.Stack)
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP])
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

      this.FilterTabs()

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
  private FilterTabs() {
    Row({ space: 4 }) {
      this.FilterTab(ImagePromptTemplateFilterMode.ALL, $r('app.string.image_prompt_template_filter_all'))
      this.FilterTab(ImagePromptTemplateFilterMode.MINE, $r('app.string.image_prompt_template_filter_mine'))
      this.FilterTab(ImagePromptTemplateFilterMode.BUILTIN, $r('app.string.image_prompt_template_filter_builtin'))
    }
    .width('100%')
    .height(34)
    .padding(3)
    .backgroundColor(this.themeSurface)
    .borderRadius(11)
  }

  @Builder
  private FilterTab(mode: ImagePromptTemplateFilterMode, label: Resource) {
    Stack() {
      Text(label)
        .fontSize(13)
        .fontWeight(this.filterMode === mode ? FontWeight.Medium : FontWeight.Regular)
        .fontColor(this.filterMode === mode ? Color.White : $r('app.color.text_secondary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .layoutWeight(1)
    .height('100%')
    .borderRadius(8)
    .backgroundColor(this.filterMode === mode ? this.themePrimary : Color.Transparent)
    .onClick(() => {
      this.filterMode = mode
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

        this.UseForImageActionButton(template)
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

  @Builder
  private UseForImageActionButton(template: ImagePromptTemplate) {
    Button({ type: ButtonType.Circle, stateEffect: false }) {
      SymbolGlyph($r('sys.symbol.picture_star_fill'))
        .fontSize(18)
        .fontColor([this.themePrimary])
    }
    .width(34)
    .height(34)
    .backgroundColor(getAppUiState().themePrimaryLight)
    .accessibilityText($r('app.string.image_prompt_template_use_for_image'))
    .onClick(() => {
      this.useTemplate(template)
    })
  }
}

@Builder
export function ImagePromptTemplateManagerPageBuilder(_name: string, _param: Object) {
  ImagePromptTemplateManagerPage({
    hostedInNavDestination: true
  })
}
